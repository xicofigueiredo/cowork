require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "welcome" do
    user = users(:one)
    email = UserMailer.welcome(user)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "one@example.com" ], email.to
    assert_equal [ "hello@mezzaninecowork.com" ], email.from
    assert_equal "Welcome to Mezzanine", email.subject
    assert_match "Dear One", email.body.encoded
    assert_match "Welcome to Mezzanine", email.body.encoded
  end
end
