require "test_helper"

class LeadMailerTest < ActionMailer::TestCase
  test "received" do
    lead = Lead.create!(
      first_name: "Ada",
      last_name: "Lovelace",
      email: "ada@example.com",
      message: "I'd like a tour",
      privacy_accepted: true
    )

    email = LeadMailer.received(lead)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "ada@example.com" ], email.to
    assert_equal [ "hello@mezzaninecowork.com" ], email.from
    assert_equal "We received your message — Mezzanine", email.subject
    assert_match "Dear Ada", email.body.encoded
    assert_match "Thank you for contacting Mezzanine", email.body.encoded
    assert_match "I'd like a tour", email.body.encoded
  end
end
