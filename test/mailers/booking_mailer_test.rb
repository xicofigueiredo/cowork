require "test_helper"

class BookingMailerTest < ActionMailer::TestCase
  setup do
    @previous_admin_emails = ENV["ADMIN_EMAILS"]
    ENV["ADMIN_EMAILS"] = "admin@example.com, other@example.com"
    @user = users(:one)
    @seat = seats(:main_001)
    @booking = Booking.create!(
      user: @user,
      seat: @seat,
      booking_type: "daily",
      date: Date.current.next_occurring(:monday)
    )
  end

  teardown do
    if @previous_admin_emails
      ENV["ADMIN_EMAILS"] = @previous_admin_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end

  test "created notifies admins" do
    email = BookingMailer.created(@booking)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "admin@example.com", "other@example.com" ], email.to
    assert_equal [ "hello@mezzaninecowork.com" ], email.from
    assert_match "New booking — One User", email.subject
    assert_match "one@example.com", email.body.encoded
    assert_match "Desk 001", email.body.encoded
  end

  test "updated notifies admins with changes" do
    old_date = @booking.date
    new_date = old_date + 1.day
    new_date += 1.day while new_date.on_weekend?
    changes = { "date" => [ old_date, new_date ] }

    email = BookingMailer.updated(@booking, changes: changes)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "admin@example.com", "other@example.com" ], email.to
    assert_match "Booking updated — One User", email.subject
    assert_match "Changes", email.body.encoded
    assert_match old_date.strftime("%-d %B %Y"), email.body.encoded
    assert_match new_date.strftime("%-d %B %Y"), email.body.encoded
  end

  test "deliver_updated skips when no relevant changes" do
    assert_no_emails do
      BookingMailer.deliver_updated(@booking, changes: { "updated_at" => [ 1.minute.ago, Time.current ] })
    end
  end
end
