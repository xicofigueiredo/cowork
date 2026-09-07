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

  test "introduce with first name" do
    email = LeadMailer.introduce(email: "ada@example.com", first_name: "Ada")

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "ada@example.com" ], email.to
    assert_equal [ "hello@mezzaninecowork.com" ], email.from
    assert_equal "Mezzanine - Your new workspace in Matosinhos", email.subject
    assert_match "Hi Ada,", email.body.encoded
    assert_match "excited to introduce Mezzanine", email.body.encoded
    assert_match "group rates", email.body.encoded
    assert email.attachments["flyer.jpeg"].present?
    assert email.attachments["flyer.jpeg"].inline?
  end

  test "introduce without first name" do
    email = LeadMailer.introduce(email: "ada@example.com")

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "ada@example.com" ], email.to
    assert_match "Hi there,", email.body.encoded
  end
end
