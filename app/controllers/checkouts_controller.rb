class CheckoutsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_order, only: [ :show, :pay, :success, :cancel ]

  def new
    @plan_type = params[:plan]
    unless Order::PLAN_TYPES.key?(@plan_type)
      redirect_to pricing_path, alert: "Please select a valid plan."
      return
    end

    @order = Order.new(plan_type: @plan_type, amount_cents: Order.plan_config(@plan_type)[:amount_cents])
    load_plan_defaults
    @seats = Seat.desks.ordered
    @monthly_period = current_user.next_monthly_period if @plan_type == "monthly"
    load_unavailable_desks
  end

  def create
    @plan_type = order_params[:plan_type]
    unless Order::PLAN_TYPES.key?(@plan_type)
      redirect_to pricing_path, alert: "Please select a valid plan."
      return
    end

    @order = current_user.orders.build(order_params)
    @order.amount_cents = Order.plan_config(@plan_type)[:amount_cents]
    @order.status = "pending"

    if @order.save
      redirect_to checkout_path(@order)
    else
      @seats = Seat.desks.ordered
      load_plan_defaults
      @monthly_period = current_user.next_monthly_period if @plan_type == "monthly"
      load_unavailable_desks
      flash.now[:alert] = @order.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def show
    redirect_to bookings_path, notice: "This order has already been paid." if @order.paid?
    @monthly_period = @order.user.next_monthly_period if @order.plan_type == "monthly"
  end

  def pay
    unless @order.pending?
      redirect_to bookings_path, notice: "This order has already been paid."
      return
    end

    session = StripeCheckout.create_session!(
      order: @order,
      success_url: stripe_return_url(:success),
      cancel_url: stripe_return_url(:cancel)
    )

    redirect_to session.url, allow_other_host: true
  rescue StripeCheckout::ConfigurationError, Stripe::StripeError => e
    Rails.logger.error("Stripe checkout failed for order #{@order.id}: #{e.class}: #{e.message}")
    redirect_to checkout_path(@order), alert: stripe_checkout_error_message(e)
  end

  def success
    if @order.paid?
      redirect_to bookings_path, notice: "Payment successful! Your booking is confirmed."
      return
    end

    if @order.stripe_session_id.present?
      session = Stripe::Checkout::Session.retrieve(@order.stripe_session_id)
      StripePaymentConfirmation.call(session)
      @order.reload
    end

    if @order.paid?
      redirect_to bookings_path, notice: "Payment successful! Your booking is confirmed."
    else
      redirect_to checkout_path(@order), notice: "Payment received. Confirmation may take a moment."
    end
  rescue Stripe::StripeError => e
    Rails.logger.error("Stripe success confirmation failed for order #{@order.id}: #{e.message}")
    redirect_to checkout_path(@order), alert: "Payment is processing. Refresh your bookings shortly."
  end

  def cancel
    redirect_to checkout_path(@order), alert: "Payment cancelled. You can try again when ready."
  end

  private

  def set_order
    @order = current_user.orders.find(params[:id])
  end

  def stripe_return_url(action)
    opts = { host: request.host, protocol: stripe_return_protocol }
    case action
    when :success then success_checkout_url(@order, **opts)
    when :cancel then cancel_checkout_url(@order, **opts)
    end
  end

  def stripe_return_protocol
    return "https" if Rails.env.production?

    request.ssl? || request.headers["X-Forwarded-Proto"] == "https" ? "https" : request.protocol.delete_suffix("://")
  end

  def stripe_checkout_error_message(error)
    message = error.message.to_s
    if message.match?(/https|http|url|ssl/i)
      "Stripe requires HTTPS return URLs in live mode. Check the site is served over https."
    elsif message.match?(/api.?key|invalid|No such/i)
      "Stripe API key rejected. Confirm live keys are from the same Stripe account and the server was restarted."
    else
      "Unable to start payment: #{message.truncate(140)}"
    end
  end

  def order_params
    params.require(:order).permit(:plan_type, :seat_id, :booking_date, :starts_at, :vat_number)
  end

  def load_plan_defaults
    case @plan_type
    when "daily"
      load_daily_checkout_calendar
      @order.booking_date = @booking_date
    when "meeting_daily"
      load_meeting_daily_calendar
      @order.booking_date = @booking_date
    when "meeting_hourly"
      load_meeting_hourly_calendar
      @order.starts_at = Time.zone.parse(params[:slot]) if params[:slot].present?
    end
  end

  def load_unavailable_desks
    if @plan_type == "daily"
      date = @booking_date || @order.booking_date || parsed_booking_date
      @unavailable_desks = SeatAvailability.unavailable_desk_codes(date)
    elsif @plan_type == "monthly"
      period = current_user.next_monthly_period
      @unavailable_desks = SeatAvailability.unavailable_desk_codes_for_monthly(period[:starts_on], period[:ends_on])
    else
      @unavailable_desks = []
    end
  end

  def parsed_booking_date
    return SeatAvailability.earliest_bookable_date if params[:date].blank?

    SeatAvailability.ensure_weekday(Date.parse(params[:date]))
  rescue ArgumentError
    SeatAvailability.earliest_bookable_date
  end

  def load_daily_checkout_calendar
    @calendar_start = SeatAvailability.earliest_bookable_date
    @calendar_days = SeatAvailability.calendar_days(@calendar_start)
    @booking_date = parsed_booking_date
  end

  def parsed_meeting_daily_date
    date_param = params[:date].presence || params.dig(:order, :booking_date)
    return MeetingRoomAvailability.earliest_daily_date if date_param.blank?

    MeetingRoomAvailability.ensure_weekday(Date.parse(date_param))
  rescue ArgumentError
    MeetingRoomAvailability.earliest_daily_date
  end

  def parsed_meeting_hourly_date
    return MeetingRoomAvailability.earliest_hourly_date if params[:date].blank?

    MeetingRoomAvailability.ensure_weekday(Date.parse(params[:date]))
  rescue ArgumentError
    MeetingRoomAvailability.earliest_hourly_date
  end

  def load_meeting_daily_calendar
    @calendar_start = MeetingRoomAvailability.earliest_daily_date
    calendar = MeetingRoomAvailability.load_calendar(@calendar_start, type: :daily)
    @calendar_days = calendar[:days]
    @booking_date = parsed_meeting_daily_date
  end

  def load_meeting_hourly_calendar
    @calendar_start = MeetingRoomAvailability.earliest_hourly_date
    calendar = MeetingRoomAvailability.load_calendar(@calendar_start, type: :hourly)
    @calendar_days = calendar[:days]
    @schedule = calendar[:schedule]
    @booking_date = parsed_meeting_hourly_date
    @hour_grid = @schedule.hour_grid(@booking_date, include_max_duration: false)
  end
end
