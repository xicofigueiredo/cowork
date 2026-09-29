require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "sends confirmation email after create" do
    assert_emails 1 do
      User.create!(
        first_name: "Ada",
        last_name: "Lovelace",
        email: "ada-new@example.com",
        password: "password123",
        password_confirmation: "password123",
        referral_source: "google_search"
      )
    end
  end

  test "sends welcome email after confirmation" do
    user = User.create!(
      first_name: "Ada",
      last_name: "Lovelace",
      email: "ada-confirm@example.com",
      password: "password123",
      password_confirmation: "password123",
      referral_source: "a_friend"
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
      password_confirmation: "password123",
      referral_source: "social_media"
    )

    assert_match(/\A\d{6}\z/, user.confirmation_token)
  end

  test "requires referral source on create" do
    user = User.new(
      first_name: "Ada",
      last_name: "Lovelace",
      email: "ada-referral@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_not user.valid?
    assert_includes user.errors[:referral_source], "can't be blank"
  end

  test "from_omniauth finds existing user by provider and uid" do
    user = users(:one)
    user.update!(provider: "google_oauth2", uid: "google-123")

    auth = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "google-123",
      info: { email: user.email, first_name: "One", last_name: "User" }
    )

    assert_equal user, User.from_omniauth(auth)
  end

  test "from_omniauth links google to existing email account" do
    user = users(:one)

    auth = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "google-456",
      info: { email: user.email.upcase, first_name: "One", last_name: "User" }
    )

    found = User.from_omniauth(auth)
    assert_equal user, found
    assert_equal "google_oauth2", found.provider
    assert_equal "google-456", found.uid
  end

  test "from_omniauth returns nil for new google users" do
    auth = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "google-new",
      info: { email: "brand-new@example.com", first_name: "New", last_name: "User" }
    )

    assert_nil User.from_omniauth(auth)
  end

  test "password not required for omniauth users" do
    user = User.new(
      first_name: "Ada",
      last_name: "Lovelace",
      email: "ada-oauth@example.com",
      provider: "google_oauth2",
      uid: "google-789",
      referral_source: "a_friend"
    )
    user.skip_confirmation!

    assert user.valid?
  end
end
