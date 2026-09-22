class OrderFulfillment
  def self.call(order)
    new(order).call
  end

  def initialize(order)
    @order = order
  end

  def call
    result = :noop

    @order.with_lock do
      return true if @order.paid?
      return false unless @order.pending?

      lock_inventory!

      unless @order.inventory_available?(ignore_pending: true)
        @order.update!(status: "failed")
        result = :conflict
      else
        create_resources!
        @order.update!(status: "paid", paid_at: Time.current)
        result = :fulfilled
      end
    end

    case result
    when :fulfilled
      after_fulfillment!
      true
    when :conflict
      refund_conflict!
      false
    else
      false
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => e
    handle_create_conflict!(e)
    false
  end

  private

  def lock_inventory!
    return if @order.seat_id.blank?

    Seat.lock.find(@order.seat_id)
  end

  def create_resources!
    if @order.credit_pack?
      create_credit_pack!
    elsif @order.plan_type == "daily"
      create_daily_booking!
    elsif @order.monthly_desk_plan?
      create_monthly_booking!
      create_monthly_meeting_hours!
    elsif @order.plan_type == "meeting_hourly"
      create_meeting_hourly_booking!
    elsif @order.plan_type == "meeting_daily"
      create_meeting_daily_booking!
    end
  end

  def after_fulfillment!
    @order.reload

    issue_access_code_for_user!

    official = Toconline::InvoiceIssuer.call(@order)

    begin
      OrderMailer.payment_confirmation(
        @order,
        official_pdf: official&.pdf_bytes,
        official_document_number: official&.document_number
      ).deliver_now
    rescue StandardError => e
      Rails.logger.error("Payment confirmation email failed for order #{@order.id}: #{e.class}: #{e.message}")
    end

    begin
      OrderMailer.space_guide(@order).deliver_now
    rescue StandardError => e
      Rails.logger.error("Space guide email failed for order #{@order.id}: #{e.class}: #{e.message}")
    end
  end

  def handle_create_conflict!(error)
    Rails.logger.error(
      "Order fulfillment conflict for order #{@order.id}: #{error.class}: #{error.message}"
    )

    @order.reload
    @order.with_lock do
      @order.update!(status: "failed") if @order.pending?
    end

    refund_conflict!
  end

  def refund_conflict!
    StripePaymentRefund.call(@order)
  rescue StandardError => e
    Rails.logger.error(
      "Stripe refund failed after fulfillment conflict for order #{@order.id}: #{e.class}: #{e.message}"
    )
  end

  def issue_access_code_for_user!
    TtLock::AccessCodeIssuer.issue_for_user!(@order.user)
  rescue StandardError => e
    Rails.logger.error("Access code issue failed for order #{@order.id}: #{e.class}: #{e.message}")
  end

  def create_credit_pack!
    credits = @order.credit_count
    CreditPack.create!(
      user: @order.user,
      order: @order,
      credit_type: "day",
      total_credits: credits,
      remaining_credits: credits,
      expires_at: 3.months.from_now
    )
  end

  def create_daily_booking!
    Booking.create!(
      user: @order.user,
      seat: @order.seat,
      booking_type: "daily",
      date: @order.booking_date,
      order: @order
    )
  end

  def create_monthly_booking!
    starts_on = @order.user.next_monthly_starts_on
    ends_on = starts_on + @order.desk_months.months

    Booking.create!(
      user: @order.user,
      seat: @order.seat,
      booking_type: "monthly",
      starts_on: starts_on,
      ends_on: ends_on,
      order: @order
    )
  end

  def create_monthly_meeting_hours!
    config = Order.plan_config(@order.plan_type)
    booking = @order.booking

    CreditPack.create!(
      user: @order.user,
      order: @order,
      credit_type: "meeting_hour",
      total_credits: config[:meeting_hours],
      remaining_credits: config[:meeting_hours],
      expires_at: booking.ends_on.end_of_day
    )
  end

  def create_meeting_hourly_booking!
    Booking.create!(
      user: @order.user,
      seat: @order.seat,
      booking_type: "meeting_hourly",
      starts_at: @order.starts_at,
      ends_at: @order.meeting_ends_at,
      order: @order
    )
  end

  def create_meeting_daily_booking!
    Booking.create!(
      user: @order.user,
      seat: @order.seat,
      booking_type: "meeting_daily",
      date: @order.booking_date,
      order: @order
    )
  end
end
