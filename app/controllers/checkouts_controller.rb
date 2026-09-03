class CheckoutsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_order, only: [ :show, :pay ]

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
    if params[:success] == "true"
      if OrderFulfillment.call(@order)
        redirect_to bookings_path, notice: "Payment successful! Your booking is confirmed."
      else
        redirect_to checkout_path(@order), alert: "Unable to complete payment."
      end
    else
      @order.update!(status: "failed")
      redirect_to pricing_path, alert: "Payment failed. Please try again."
    end
  end

  private

  def set_order
    @order = current_user.orders.find(params[:id])
  end

  def order_params
    params.require(:order).permit(:plan_type, :seat_id, :booking_date, :starts_at)
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
