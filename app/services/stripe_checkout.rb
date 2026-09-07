class StripeCheckout
  class ConfigurationError < StandardError; end

  def self.create_session!(order:, success_url:, cancel_url:)
    new(order:, success_url:, cancel_url:).create_session!
  end

  def initialize(order:, success_url:, cancel_url:)
    @order = order
    @success_url = success_url
    @cancel_url = cancel_url
  end

  def create_session!
    raise ConfigurationError, "Stripe is not configured" if Stripe.api_key.blank?

    session = Stripe::Checkout::Session.create(
      mode: "payment",
      customer_email: @order.user.email,
      client_reference_id: @order.id.to_s,
      metadata: {
        order_id: @order.id,
        plan_type: @order.plan_type
      },
      line_items: [
        {
          quantity: 1,
          price_data: {
            currency: "eur",
            unit_amount: @order.total_with_iva_cents,
            product_data: {
              name: @order.plan_label,
              description: line_item_description
            }
          }
        }
      ],
      success_url: @success_url,
      cancel_url: @cancel_url
    )

    @order.update!(stripe_session_id: session.id)
    session
  end

  private

  def line_item_description
    parts = [ "Includes 23% IVA" ]
    parts << "Desk #{@order.seat.label}" if @order.seat&.desk?
    parts << "Date #{@order.booking_date}" if @order.booking_date
    parts << "Starts #{@order.starts_at.strftime('%Y-%m-%d %H:%M')}" if @order.starts_at
    parts.join(" · ")
  end
end
