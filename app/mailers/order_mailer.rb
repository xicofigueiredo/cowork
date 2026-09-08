class OrderMailer < ApplicationMailer
  def payment_confirmation(order, official_pdf: nil, official_document_number: nil)
    @order = order
    @user = order.user
    @booking = order.booking
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
      subject: "Payment confirmed — #{@order.plan_label} (#{@invoice_number})"
    )
  end
end
