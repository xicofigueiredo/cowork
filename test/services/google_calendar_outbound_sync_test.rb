require "test_helper"

class GoogleCalendarOutboundSyncTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :inserted, :updated, :deleted

    def initialize
      @inserted = []
      @updated = []
      @deleted = []
    end

    def insert_event(body)
      @inserted << body
      { "id" => "new-event-1" }
    end

    def update_event(event_id, body)
      @updated << [ event_id, body ]
      { "id" => event_id }
    end

    def delete_event(event_id)
      @deleted << event_id
      nil
    end
  end

  setup do
    @date = SeatAvailability.earliest_bookable_date
    while SeatAvailability.blocked_daily_date?(@date)
      @date += 1.day
    end

    ENV["GOOGLE_CLIENT_ID"] = "test-client"
    ENV["GOOGLE_CLIENT_SECRET"] = "test-secret"
    ENV["GOOGLE_CALENDAR_ID"] = "test-calendar"
    ENV["GOOGLE_CALENDAR_REFRESH_TOKEN"] = "test-refresh"

    @client = FakeClient.new
    @booking = Booking.create!(
      user: users(:one),
      seat: seats(:main_001),
      booking_type: "daily",
      date: @date,
      source: "app"
    )
  end

  teardown do
    %w[
      GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET GOOGLE_CALENDAR_ID
      GOOGLE_CALENDAR_REFRESH_TOKEN
    ].each { |key| ENV.delete(key) }
  end

  test "inserts an all-day event and stores google_event_id" do
    GoogleCalendar::OutboundSync.upsert(@booking, client: @client)

    assert_equal 1, @client.inserted.size
    body = @client.inserted.first
    assert_equal @date.iso8601, body[:start][:date]
    assert_equal (@date + 1.day).iso8601, body[:end][:date]
    assert_equal @booking.id.to_s, body[:extendedProperties][:private][:cowork_booking_id]
    assert_equal "new-event-1", @booking.reload.google_event_id
  end

  test "skips google_calendar sourced bookings" do
    @booking.update_columns(source: "google_calendar", google_event_id: "from-croissant")

    GoogleCalendar::OutboundSync.upsert(@booking, client: @client)

    assert_empty @client.inserted
    assert_empty @client.updated
  end

  test "updates an existing event" do
    @booking.update_columns(google_event_id: "existing-1")

    GoogleCalendar::OutboundSync.upsert(@booking, client: @client)

    assert_equal 1, @client.updated.size
    assert_equal "existing-1", @client.updated.first.first
  end

  test "deletes an event by id" do
    GoogleCalendar::OutboundSync.delete_event("existing-1", client: @client)

    assert_equal [ "existing-1" ], @client.deleted
  end
end
