require "test_helper"

class SeatAvailabilityTest < ActiveSupport::TestCase
  setup do
    @seat = seats(:main_001)
    @user = users(:one)
    @other_user = users(:two)
    @date = SeatAvailability.earliest_bookable_date
  end

  test "pending daily order holds the seat for others" do
    order = Order.create!(
      user: @user,
      plan_type: "daily",
      amount_cents: 1300,
      status: "pending",
      seat: @seat,
      booking_date: @date,
      vat_number: "123456789"
    )

    assert SeatAvailability.available_on?(@seat, @date, except_order: order)
    assert_not SeatAvailability.available_on?(@seat, @date)

    conflicting = Order.new(
      user: @other_user,
      plan_type: "daily",
      amount_cents: 1300,
      status: "pending",
      seat: @seat,
      booking_date: @date,
      vat_number: "123456789"
    )
    assert_not conflicting.valid?
    assert_includes conflicting.errors[:seat].join, "not available"
  end

  test "expired pending holds no longer block availability" do
    order = Order.create!(
      user: @user,
      plan_type: "daily",
      amount_cents: 1300,
      status: "pending",
      seat: @seat,
      booking_date: @date,
      vat_number: "123456789"
    )
    order.update_columns(created_at: (SeatAvailability::PENDING_HOLD_TTL + 1.minute).ago)

    assert SeatAvailability.available_on?(@seat, @date)
  end
end
