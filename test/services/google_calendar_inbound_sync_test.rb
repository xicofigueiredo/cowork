require "test_helper"

class GoogleCalendarInboundSyncTest < ActiveSupport::TestCase
  setup do
    @date = SeatAvailability.earliest_bookable_date
    while SeatAvailability.blocked_daily_date?(@date)
      @date += 1.day
    end

    ENV["GOOGLE_CLIENT_ID"] = "test-client"
    ENV["GOOGLE_CLIENT_SECRET"] = "test-secret"
    ENV["GOOGLE_CALENDAR_ID"] = "test-calendar"
    ENV["GOOGLE_CALENDAR_REFRESH_TOKEN"] = "test-refresh"
    ENV["CROISSANT_BOOKING_USER_EMAIL"] = "croissant-test@example.com"

    @client = Object.new
    def @client.list_events(time_min:, time_max:)
      @events || []
    end
    def @client.events=(value)
      @events = value
    end
  end

  teardown do
    %w[
      GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET GOOGLE_CALENDAR_ID
      GOOGLE_CALENDAR_REFRESH_TOKEN CROISSANT_BOOKING_USER_EMAIL
    ].each { |key| ENV.delete(key) }
  end

  test "creates a daily desk booking from an all-day event" do
    @client.events = [
      {
        "id" => "evt-1",
        "status" => "confirmed",
        "start" => { "date" => @date.iso8601 },
        "end" => { "date" => (@date + 1.day).iso8601 }
      }
    ]

    result = GoogleCalendar::InboundSync.call(client: @client)

    assert_equal 1, result[:created]
    booking = Booking.find_by!(google_event_id: "evt-1")
    assert_equal "daily", booking.booking_type
    assert_equal @date, booking.date
    assert_equal "google_calendar", booking.source
    assert booking.seat.desk?
    assert_equal "croissant-test@example.com", booking.user.email
  end

  test "skips events owned by the app" do
    @client.events = [
      {
        "id" => "evt-app",
        "status" => "confirmed",
        "start" => { "date" => @date.iso8601 },
        "end" => { "date" => (@date + 1.day).iso8601 },
        "extendedProperties" => { "private" => { "cowork_booking_id" => "99" } }
      }
    ]

    result = GoogleCalendar::InboundSync.call(client: @client)

    assert_equal 0, result[:created]
    assert_nil Booking.find_by(google_event_id: "evt-app")
  end

  test "removes local google_calendar bookings when the event disappears" do
    seat = seats(:main_001)
    user = GoogleCalendar::SystemUser.call
    booking = Booking.create!(
      user: user,
      seat: seat,
      booking_type: "daily",
      date: @date,
      google_event_id: "evt-gone",
      source: "google_calendar"
    )

    @client.events = []
    result = GoogleCalendar::InboundSync.call(client: @client)

    assert_equal 1, result[:removed]
    assert_not Booking.exists?(booking.id)
  end

  test "creates a monthly booking for multi-day events" do
    ends_on = @date + 3.days
    @client.events = [
      {
        "id" => "evt-multi",
        "status" => "confirmed",
        "start" => { "date" => @date.iso8601 },
        "end" => { "date" => (ends_on + 1.day).iso8601 }
      }
    ]

    result = GoogleCalendar::InboundSync.call(client: @client)

    assert_equal 1, result[:created]
    booking = Booking.find_by!(google_event_id: "evt-multi")
    assert_equal "monthly", booking.booking_type
    assert_equal @date, booking.starts_on
    assert_equal ends_on, booking.ends_on
  end
end
