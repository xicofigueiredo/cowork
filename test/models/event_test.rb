require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "allows fully blank optional fields" do
    event = Event.new(position: 0)

    assert event.valid?
  end

  test "formats optional event date" do
    event = Event.new(event_date: Date.new(2026, 11, 20), position: 0)

    assert_equal "November 20, 2026", event.display_date
    assert_nil Event.new(position: 0).display_date
  end

  test "normalizes blank strings to nil" do
    event = Event.create!(title: "  ", description: "  ", url: "  ", position: 1)

    assert_nil event.title
    assert_nil event.description
    assert_nil event.url
    assert_equal "Untitled event", event.display_title
  end

  test "rejects invalid urls when present" do
    event = Event.new(url: "not-a-url", position: 0)

    assert_not event.valid?
    assert_includes event.errors[:url], "is invalid"
  end

  test "accepts http urls" do
    event = Event.new(url: "https://example.com/event", position: 0)

    assert event.valid?
  end

  test "orders by position then created_at" do
    later = Event.create!(title: "Later same position", position: 1)
    earlier = Event.create!(title: "Earlier same position", position: 1, created_at: 1.day.ago)
    first = Event.create!(title: "First", position: 0)

    assert_equal [ first, earlier, later ], Event.all.to_a
  end

  test "next_position increments from existing events" do
    assert_equal 0, Event.next_position

    Event.create!(title: "One", position: 2)
    assert_equal 3, Event.next_position
  end
end
