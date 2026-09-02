require "test_helper"

class OrderFulfillmentTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @seat = seats(:main_001)
  end

  test "fulfills daily order with booking" do
    order = Order.create!(
      user: @user,
      plan_type: "daily",
      amount_cents: 1300,
      status: "pending",
      seat: @seat,
      booking_date: Date.current + 1.day
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
      seat: @seat
    )
    assert OrderFulfillment.call(first_order)

    first_booking = first_order.reload.booking
    second_order = Order.create!(
      user: @user,
      plan_type: "monthly",
      amount_cents: 14_000,
      status: "pending",
      seat: @seat
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
      status: "pending"
    )

    assert OrderFulfillment.call(order)
    order.reload

    assert order.paid?
    assert_equal 5, order.credit_pack.remaining_credits
  end
end
