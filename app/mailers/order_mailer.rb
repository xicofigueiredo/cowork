class OrderMailer < ApplicationMailer
  def payment_confirmation(order, official_pdf: nil, official_document_number: nil)
    @order = order
    @user = order.user
    @booking = order.booking
    @access_code = @booking&.access_code
    @credit_pack = order.credit_pack
    @invoice_number = official_document_number.presence || order.toconline_document_number.presence || order.invoice_number
    @paid_at = order.paid_at || Time.current
    @has_official_pdf = official_pdf.present?

    if official_pdf.present?
      filename = "fatura-#{@invoice_number.to_s.parameterize.presence || order.id}.pdf"
      attachments[filename] = {
        mime_type: "application/pdf",
        content: official_pdf
      }
    end

    mail(
      to: @user.email,
      bcc: admin_emails,
      subject: "Payment confirmed — #{@order.plan_label} (#{@invoice_number})"
    )
  end

  def toconline_failure(order, error_message)
    @order = order
    @user = order.user
    @error_message = error_message

    mail(
      to: admin_emails.presence || [ "hello@mezzaninecowork.com" ],
      subject: "[Action required] TOConline invoice failed — order ##{order.id}"
    )
  end

  def space_guide(order)
    @order = order
    @user = order.user

    attachments.inline["house_rules1.png"] = File.read(
      Rails.root.join("app/assets/images/house_rules1.png")
    )
    attachments.inline["house_rules2.png"] = File.read(
      Rails.root.join("app/assets/images/house_rules2.png")
    )

    mail(
      to: @user.email,
      subject: "Welcome to Mezzanine — space guide & house rules"
    )
  end
end