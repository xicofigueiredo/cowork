require "test_helper"

class LocationControllerTest < ActionDispatch::IntegrationTest
  test "create stores a lead" do
    assert_difference -> { Lead.count }, 1 do
      assert_enqueued_emails 1 do
        post location_path, params: {
          lead: {
            first_name: "Ada",
            last_name: "Lovelace",
            email: "ada@example.com",
            message: "I'd like a tour",
            privacy_accepted: "1"
          }
        }
      end
    end

    assert_redirected_to location_path
    assert_equal "Thanks, we'll get back to you soon.", flash[:notice]

    lead = Lead.last
    assert_equal "Ada", lead.first_name
    assert_equal "Lovelace", lead.last_name
    assert_equal "ada@example.com", lead.email
    assert_equal "I'd like a tour", lead.message
    assert lead.privacy_accepted
  end

  test "create rejects a lead without required fields" do
    assert_no_difference -> { Lead.count } do
      post location_path, params: {
        lead: {
          first_name: "",
          last_name: "",
          email: "",
          privacy_accepted: "0"
        }
      }
    end

    assert_response :unprocessable_entity
  end
end
