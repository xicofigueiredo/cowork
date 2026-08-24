require "test_helper"

class LeadTest < ActiveSupport::TestCase
  def valid_attrs
    {
      first_name: "Ada",
      last_name: "Lovelace",
      email: "ada@example.com",
      message: "I'd like a tour",
      privacy_accepted: true
    }
  end

  test "valid lead" do
    assert Lead.new(valid_attrs).valid?
  end

  test "requires first name, last name, email, and privacy acceptance" do
    lead = Lead.new
    assert_not lead.valid?
    assert_includes lead.errors[:first_name], "can't be blank"
    assert_includes lead.errors[:last_name], "can't be blank"
    assert_includes lead.errors[:email], "can't be blank"
    assert_includes lead.errors[:privacy_accepted], "must be accepted"
  end

  test "normalizes email and blank message" do
    lead = Lead.create!(valid_attrs.merge(email: "  Ada@Example.COM  ", message: "  "))
    assert_equal "ada@example.com", lead.email
    assert_nil lead.message
  end
end
