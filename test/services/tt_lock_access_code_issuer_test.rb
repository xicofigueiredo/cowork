require "test_helper"

class TtLockAccessCodeIssuerTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @seat = seats(:main_001)
    @booking = Booking.create!(
      user: @user,
      seat: @seat,
      booking_type: "daily",
      date: Date.current + 1.day
    )
  end

  test "skips issuing when TTLock is not configured" do
    assert_not TtLock::Client.configured?

    result = TtLock::AccessCodeIssuer.issue_for_booking!(@booking)

    assert_nil result
    assert_nil @booking.reload.access_code
  end

  test "validity window for daily booking uses space hours" do
    window = TtLock::AccessCodeIssuer.validity_window_for(@booking)

    assert_equal @booking.date.in_time_zone.change(hour: 8), window[:valid_from]
    assert_equal @booking.date.in_time_zone.change(hour: 20), window[:valid_to]
  end

  test "admin? matches ADMIN_EMAILS" do
    previous = ENV["ADMIN_EMAILS"]
    ENV["ADMIN_EMAILS"] = @user.email
    assert @user.admin?
  ensure
    if previous
      ENV["ADMIN_EMAILS"] = previous
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end
end
