require "test_helper"

class OrderMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:one)
  end

  test "virtual office activation email" do
    order = Order.create!(
      user: @user,
      plan_type: "virtual",
      amount_cents: 24_000,
      status: "paid",
      paid_at: Time.current,
      vat_number: "123456789",
      booking_date: Date.current,
      company_name: "Mezzanine LDA",
      partners: [ { "name" => "Ana Silva", "national_id" => "12345678" } ],
      contact_email: "ana@example.com",
      terms_accepted: true
    )

    email = OrderMailer.virtual_office_activation(order)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ @user.email ], email.to
    assert_includes email.subject, "Virtual Office is now active"
    body = [ email.text_part&.body, email.html_part&.body, email.body ].compact.map(&:to_s).join
    assert_includes body, "Rua Brito e Cunha 27"
    assert_includes body, "Matosinhos"
  end
end
