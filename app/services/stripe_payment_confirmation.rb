class StripePaymentConfirmation
  def self.call(session)
    new(session).call
  end

  def initialize(session)
    @session = session
  end

  def call
    return false unless paid?

    order = find_order
    return false unless order

    OrderFulfillment.call(order)
  end

  private

  def paid?
    @session.payment_status == "paid"
  end

  def find_order
    order_id = @session.metadata&.[]("order_id").presence || @session.client_reference_id
    order = Order.find_by(id: order_id) if order_id.present?
    order ||= Order.find_by(stripe_session_id: @session.id)
    order
  end
end
