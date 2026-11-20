require "test_helper"

class Admin::EventsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = users(:one)
    @member = users(:two)
    @previous_admin_emails = ENV["ADMIN_EMAILS"]
  end

  teardown do
    if @previous_admin_emails
      ENV["ADMIN_EMAILS"] = @previous_admin_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end

  test "requires authentication" do
    get admin_events_path

    assert_redirected_to new_user_session_path
  end

  test "requires admin" do
    sign_in @member

    get admin_events_path

    assert_redirected_to root_path
    assert_equal "You are not authorized to access that page.", flash[:alert]
  end

  test "admin can create an event with optional fields" do
    ENV["ADMIN_EMAILS"] = @admin.email
    sign_in @admin

    assert_difference -> { Event.count }, 1 do
      post admin_events_path, params: {
        event: {
          title: "Open day",
          description: "",
          url: "",
          event_date: "",
          position: "0"
        }
      }
    end

    event = Event.last
    assert_redirected_to admin_events_path
    assert_equal "Open day", event.title
    assert_nil event.description
    assert_nil event.url
    assert_nil event.event_date
    assert_equal 0, event.position
  end

  test "admin can update and delete an event" do
    ENV["ADMIN_EMAILS"] = @admin.email
    sign_in @admin
    event = Event.create!(title: "Old title", position: 1)

    patch admin_event_path(event), params: {
      event: {
        title: "New title",
        description: "Updated copy",
        url: "https://example.com",
        event_date: "2026-12-01",
        position: "2"
      }
    }

    assert_redirected_to admin_events_path
    event.reload
    assert_equal "New title", event.title
    assert_equal "Updated copy", event.description
    assert_equal "https://example.com", event.url
    assert_equal Date.new(2026, 12, 1), event.event_date
    assert_equal 2, event.position

    assert_difference -> { Event.count }, -1 do
      delete admin_event_path(event)
    end

    assert_redirected_to admin_events_path
  end
end
