class StripePaymentRefund
  def self.call(order)
    new(order).call
  end

  def initialize(order)
    @order = order
  end

  def call
    return false if @order.stripe_session_id.blank?
    return false if Stripe.api_key.blank?

    session = Stripe::Checkout::Session.retrieve(@order.stripe_session_id)
    payment_intent_id = payment_intent_id_for(session)
    return false if payment_intent_id.blank?

    Stripe::Refund.create(
      payment_intent: payment_intent_id,
      reason: "requested_by_customer",
      metadata: {
        order_id: @order.id,
        reason: "inventory_conflict"
      }
    )

    Rails.logger.info("Refunded Stripe payment for order #{@order.id} (session #{@order.stripe_session_id})")
    true
  end

  private

  def payment_intent_id_for(session)
    intent = session.payment_intent
    intent.respond_to?(:id) ? intent.id : intent
  end
end
