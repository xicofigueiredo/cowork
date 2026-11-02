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

  test "pending multi-seat daily order holds every selected seat" do
    second_seat = seats(:main_002)
    order = Order.new(
      user: @user,
      plan_type: "daily",
      status: "pending",
      booking_date: @date,
      vat_number: "123456789"
    )
    order.assign_selected_seats!([ @seat.id, second_seat.id ])
    order.amount_cents = Order.daily_amount_cents(2)
    order.save!

    assert_equal [ @seat.id, second_seat.id ], order.seat_ids
    assert SeatAvailability.available_on?(@seat, @date, except_order: order)
    assert_not SeatAvailability.available_on?(@seat, @date)
    assert_not SeatAvailability.available_on?(second_seat, @date)

    conflicting = Order.new(
      user: @other_user,
      plan_type: "daily",
      amount_cents: 1300,
      status: "pending",
      seat: second_seat,
      booking_date: @date,
      vat_number: "123456789"
    )
    assert_not conflicting.valid?
    assert_includes conflicting.errors[:seat].join, "not available"
  end

  test "blocked daily dates reject day bookings but allow monthly" do
    blocked = Date.new(2026, 11, 18)

    assert SeatAvailability.blocked_daily_date?(blocked)
    assert_not SeatAvailability.bookable_date?(blocked)
    assert_not SeatAvailability.available_on?(@seat, blocked)
    assert_not SeatAvailability.any_desk_available?(blocked)

    day = SeatAvailability.calendar_days(blocked - 7.days).find { |entry| entry[:date] == blocked }
    assert day
    assert_not day[:available]
    assert_equal "Closed", day[:meta]

    starts_on = blocked
    ends_on = starts_on + 1.month
    assert SeatAvailability.available_for_monthly?(@seat, starts_on, ends_on)

    monthly_day = SeatAvailability.monthly_start_calendar_days(blocked - 7.days, months: 1)
      .find { |entry| entry[:date] == blocked }
    assert monthly_day
    assert monthly_day[:available]
  end

  test "weekends are bookable for desks" do
    saturday = Date.current.next_occurring(:saturday)
    sunday = Date.current.next_occurring(:sunday)

    [ saturday, sunday ].each do |weekend_day|
      next if SeatAvailability.blocked_daily_date?(weekend_day)

      assert SeatAvailability.bookable_date?(weekend_day)
      assert SeatAvailability.available_on?(@seat, weekend_day)
      assert SeatAvailability.any_desk_available?(weekend_day)
    end
  end
end
