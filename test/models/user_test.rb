require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "sends confirmation email after create" do
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

  test "sends welcome email after confirmation" do
    user = User.create!(
      first_name: "Ada",
      last_name: "Lovelace",
      email: "ada-confirm@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_emails 1 do
      user.confirm
    end
  end

  test "stores a 6-digit confirmation code" do
    user = User.create!(
      first_name: "Ada",
      last_name: "Lovelace",
      email: "ada-code@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_match(/\A\d{6}\z/, user.confirmation_token)
  end
end
