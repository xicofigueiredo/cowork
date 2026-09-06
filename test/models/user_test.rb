require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "sends welcome email after create" do
    assert_emails 1 do
      User.create!(
        first_name: "Ada",
        last_name: "Lovelace",
        email: "ada-new@example.com",
        password: "password123",
        password_confirmation: "password123"
      )
    end
  end
end
