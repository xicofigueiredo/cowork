require "test_helper"

class OrderTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @seat = seats(:main_001)
    @second_seat = seats(:main_002)
    @date = SeatAvailability.earliest_bookable_date
  end

  test "daily amount scales with seat count" do
    assert_equal 1300, Order.daily_amount_cents(1)
    assert_equal 2600, Order.daily_amount_cents(2)
    assert_equal 1500, Order.daily_original_amount_cents(1)
    assert_equal 3000, Order.daily_original_amount_cents(2)
  end

  test "assign_selected_seats sets seat_id to the first desk" do
    order = Order.new(plan_type: "daily")
    order.assign_selected_seats!([ @second_seat.id, @seat.id ])

    assert_equal [ @second_seat.id, @seat.id ], order.seat_ids
    assert_equal @second_seat.id, order.seat_id
    assert_equal 2, order.desk_count
  end

  test "syncs seat_ids from seat_id on validation" do
    order = Order.create!(
      user: @user,
      plan_type: "daily",
      amount_cents: 1300,
      status: "pending",
      seat: @seat,
      booking_date: @date,
      vat_number: "123456789"
    )

    assert_equal [ @seat.id ], order.seat_ids
  end

  test "original_amount_cents scales for multi-desk daily" do
    order = Order.new(
      user: @user,
      plan_type: "daily",
      booking_date: @date,
      vat_number: "123456789"
    )
    order.assign_selected_seats!([ @seat.id, @second_seat.id ])
    order.amount_cents = Order.daily_amount_cents(2)

    assert_equal 3000, order.original_amount_cents
    assert order.discounted?
  end

  test "monthly period uses the selected booking date" do
    start_date = Date.current + 10.days
    order = Order.new(
      user: @user,
      plan_type: "monthly",
      amount_cents: 14_000,
      booking_date: start_date,
      seat: @seat
    )

    period = order.monthly_period
    assert_equal start_date, period[:starts_on]
    assert_equal start_date + 1.month, period[:ends_on]
  end

  test "monthly start date cannot be before the next available start" do
    order = Order.new(
      user: @user,
      plan_type: "monthly",
      amount_cents: 14_000,
      status: "pending",
      seat: @seat,
      booking_date: Date.current - 1.day,
      vat_number: "123456789"
    )

    assert_not order.valid?
    assert order.errors[:booking_date].any?
  end
end
