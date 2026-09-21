require "test_helper"

class OrderFulfillmentTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @seat = seats(:main_001)
    @booking_date = SeatAvailability.earliest_bookable_date
  end

  test "fulfills daily order with booking" do
    order = Order.create!(
      user: @user,
      plan_type: "daily",
      amount_cents: 1300,
      status: "pending",
      seat: @seat,
      booking_date: @booking_date,
      vat_number: "123456789"
    )

    assert OrderFulfillment.call(order)
    order.reload

    assert order.paid?
    assert_not_nil order.booking
    assert_equal "daily", order.booking.booking_type
  end

  test "fulfills second monthly order starting after the first ends" do
    first_order = Order.create!(
      user: @user,
      plan_type: "monthly",
      amount_cents: 14_000,
      status: "pending",
      seat: @seat,
      vat_number: "123456789"
    )
    assert OrderFulfillment.call(first_order)

    first_booking = first_order.reload.booking
    second_order = Order.create!(
      user: @user,
      plan_type: "monthly",
      amount_cents: 14_000,
      status: "pending",
      seat: @seat,
      vat_number: "123456789"
    )

    assert OrderFulfillment.call(second_order)

    second_booking = second_order.reload.booking
    assert_equal first_booking.ends_on + 1.day, second_booking.starts_on
    assert_equal second_booking.starts_on + 1.month, second_booking.ends_on
  end

  test "fulfills pack order with credits" do
    order = Order.create!(
      user: @user,
      plan_type: "pack_5",
      amount_cents: 5500,
      status: "pending",
      vat_number: "123456789"
    )

    assert OrderFulfillment.call(order)
    order.reload

    assert order.paid?
    assert_equal 5, order.credit_pack.remaining_credits
  end

  test "fulfills promocode order with discounted credits" do
    promocode = Promocode.create!(
      code: "MEZZFRIENDS30",
      amount_cents: 3000,
      credits: 5,
      active: true
    )
    order = Order.create!(
      user: @user,
      plan_type: "daily",
      amount_cents: promocode.amount_cents,
      status: "pending",
      promocode: promocode,
      vat_number: "123456789"
    )

    assert OrderFulfillment.call(order)
    order.reload

    assert order.paid?
    assert_nil order.booking
    assert_equal 5, order.credit_pack.remaining_credits
    assert_equal 3000, order.amount_cents
  end

  test "fulfills monthly_3 order with 15 meeting hours and 3-month desk" do
    order = Order.create!(
      user: @user,
      plan_type: "monthly_3",
      amount_cents: 12_000,
      status: "pending",
      seat: @seat,
      vat_number: "123456789"
    )

    assert OrderFulfillment.call(order)
    order.reload

    assert order.paid?
    assert_equal "monthly", order.booking.booking_type
    assert_equal order.booking.starts_on + 3.months, order.booking.ends_on
    assert_equal "meeting_hour", order.credit_pack.credit_type
    assert_equal 15, order.credit_pack.total_credits
    assert_equal 15, order.credit_pack.remaining_credits
    assert_equal 15, @user.reload.available_meeting_hours
  end

  test "marks losing concurrent daily order as failed without booking" do
    first_order = Order.create!(
      user: @user,
      plan_type: "daily",
      amount_cents: 1300,
      status: "pending",
      seat: @seat,
      booking_date: @booking_date,
      vat_number: "123456789"
    )

    # Simulate a race where both pending orders were accepted before either paid.
    second_order = Order.new(
      user: @other_user,
      plan_type: "daily",
      amount_cents: 1300,
      status: "pending",
      seat: @seat,
      booking_date: @booking_date,
      vat_number: "123456789"
    )
    assert second_order.save(validate: false)

    assert OrderFulfillment.call(first_order)
    assert_not OrderFulfillment.call(second_order)

    first_order.reload
    second_order.reload

    assert first_order.paid?
    assert_not_nil first_order.booking
    assert second_order.failed?
    assert_nil second_order.booking
  end

  test "is idempotent when order is already paid" do
    order = Order.create!(
      user: @user,
      plan_type: "daily",
      amount_cents: 1300,
      status: "pending",
      seat: @seat,
      booking_date: @booking_date,
      vat_number: "123456789"
    )

    assert OrderFulfillment.call(order)
    assert OrderFulfillment.call(order.reload)
    assert_equal 1, Booking.where(order: order).count
  end
end
