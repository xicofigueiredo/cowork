class OrderMailer < ApplicationMailer
  def payment_confirmation(order)
    @order = order
    @user = order.user
    @booking = order.booking
    @credit_pack = order.credit_pack
    @invoice_number = order.invoice_number
    @paid_at = order.paid_at || Time.current

    attachments["invoice-#{@invoice_number}.html"] = {
      mime_type: "text/html",
      content: render_to_string(
        template: "order_mailer/invoice",
        formats: [ :html ],
        layout: false
      )
    }

    mail(
      to: @user.email,
      subject: "Payment confirmed — #{@order.plan_label} (#{@invoice_number})"
    )
  end
end
