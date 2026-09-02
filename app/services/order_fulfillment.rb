class OrderFulfillment
  def self.call(order)
    new(order).call
  end

  def initialize(order)
    @order = order
  end

  def call
    return false unless @order.pending?

    ActiveRecord::Base.transaction do
      @order.update!(status: "paid", paid_at: Time.current)

      if @order.credit_pack?
        create_credit_pack!
      elsif @order.plan_type == "daily"
        create_daily_booking!
      elsif @order.plan_type == "monthly"
        create_monthly_booking!
        create_monthly_meeting_hours!
      elsif @order.plan_type == "meeting_hourly"
        create_meeting_hourly_booking!
      elsif @order.plan_type == "meeting_daily"
        create_meeting_daily_booking!
      end
    end

    true
  end

  private

  def create_credit_pack!
    config = Order.plan_config(@order.plan_type)
    CreditPack.create!(
      user: @order.user,
      order: @order,
      credit_type: "day",
      total_credits: config[:credits],
      remaining_credits: config[:credits],
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
    ends_on = starts_on + 1.month

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
    config = Order.plan_config("monthly")
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
