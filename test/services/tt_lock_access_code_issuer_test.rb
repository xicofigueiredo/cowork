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
    previous = ENV["TTLOCK_LOCK_ID"]
    ENV["TTLOCK_LOCK_ID"] = ""

    result = TtLock::AccessCodeIssuer.issue_for_user!(@user)

    assert_nil result
    assert_nil @user.reload.access_code
  ensure
    if previous
      ENV["TTLOCK_LOCK_ID"] = previous
    else
      ENV.delete("TTLOCK_LOCK_ID")
    end
  end

  test "synced_to_lock requires active status and ttlock id" do
    code = AccessCode.new(
      booking: nil,
      user: @user,
      code: "12345",
      name: "Test",
      valid_from: 1.hour.from_now,
      valid_to: 2.hours.from_now,
      source: "member",
      status: "active"
    )

    assert_not code.synced_to_lock?

    code.ttlock_keyboard_pwd_id = "999"
    assert code.synced_to_lock?
  end

  test "door_code_status is missing without a synced code" do
    assert_equal :missing, @user.door_code_status
    assert @user.needs_door_code?
  end

  test "door_code_status is failed when a failed code exists" do
    AccessCode.create!(
      user: @user,
      code: "12345",
      name: "Failed",
      valid_from: Time.current,
      valid_to: AccessCode.permanent_until,
      source: "member",
      status: "failed"
    )

    assert_equal :failed, @user.reload.door_code_status
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

  test "stores FALLBACK_CODE when gateway is offline" do
    previous_fallback = ENV["FALLBACK_CODE"]
    ENV["FALLBACK_CODE"] = "1904"

    client = Object.new
    def client.add_passcode!(**)
      raise TtLock::GatewayOfflineError, "TTLock gateway is offline"
    end

    TtLock::Client.stub(:configured?, true) do
      TtLock::Client.stub(:new, client) do
        access_code = TtLock::AccessCodeIssuer.call(
          user: @user,
          name: "Member — Test",
          permanent: true,
          source: "member"
        )

        assert access_code.persisted?
        assert_equal "1904", access_code.code
        assert access_code.fallback?
        assert access_code.synced_to_lock?
        assert_equal "1904", @user.reload.access_code.code
        assert_equal :synced, @user.door_code_status
      end
    end
  ensure
    if previous_fallback
      ENV["FALLBACK_CODE"] = previous_fallback
    else
      ENV.delete("FALLBACK_CODE")
    end
  end
end
