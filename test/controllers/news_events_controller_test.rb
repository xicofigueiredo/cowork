require "test_helper"

class NewsEventsControllerTest < ActionDispatch::IntegrationTest
  test "shows empty state when there are no events" do
    get news_events_path

    assert_response :success
    assert_select "h1", text: "News & Events"
    assert_match(/No news or events to share right now/, response.body)
  end

  test "renders optional fields without requiring photo link or description" do
    Event.create!(title: "Community breakfast", event_date: Date.new(2026, 11, 20), position: 0)
    Event.create!(description: "Just a note", position: 1)
    Event.create!(url: "https://example.com/meetup", position: 2)

    get news_events_path

    assert_response :success
    assert_select ".newsevents-carousel-slide", count: 3
    assert_select ".newsevents-carousel-caption-date[datetime=?]", "2026-11-20"
    assert_select ".newsevents-carousel-caption-title", text: "Community breakfast"
    assert_select ".newsevents-carousel-caption-copy", text: "Just a note"
    assert_select "a.newsevents-carousel-link[href=?]", "https://example.com/meetup"
    assert_select ".newsevents-carousel-placeholder", count: 3
  end
end
