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
    else
      attachments["invoice-#{@invoice_number}.html"] = {
        mime_type: "text/html",
        content: render_to_string(
          template: "order_mailer/invoice",
          formats: [ :html ],
          layout: false
        )
      }
    end

    mail(
      to: @user.email,
      bcc: admin_emails,
      subject: "Payment confirmed — #{@order.plan_label} (#{@invoice_number})"
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

  private

  def admin_emails
    ENV.fetch("ADMIN_EMAILS", "").split(",").map { |e| e.strip }.reject(&:blank?)
  end
end
