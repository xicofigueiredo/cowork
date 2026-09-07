module Webhooks
  class StripeController < ActionController::Base
    skip_forgery_protection

    def create
      payload = request.body.read
      signature = request.env["HTTP_STRIPE_SIGNATURE"]
      secret = ENV["STRIPE_WEBHOOK_SECRET"]

      if secret.blank?
        Rails.logger.error("STRIPE_WEBHOOK_SECRET is not configured")
        head :internal_server_error
        return
      end

      event = Stripe::Webhook.construct_event(payload, signature, secret)

      case event.type
      when "checkout.session.completed", "checkout.session.async_payment_succeeded"
        StripePaymentConfirmation.call(event.data.object)
      when "checkout.session.async_payment_failed"
        mark_failed!(event.data.object)
      end

      head :ok
    rescue JSON::ParserError, Stripe::SignatureVerificationError => e
      Rails.logger.warn("Stripe webhook rejected: #{e.message}")
      head :bad_request
    end

    private

    def mark_failed!(session)
      order = Order.find_by(stripe_session_id: session.id) ||
              Order.find_by(id: session.metadata&.[]("order_id"))
      order&.update!(status: "failed") if order&.pending?
    end
  end
end
