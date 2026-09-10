# frozen_string_literal: true

module Toconline
  class InvoiceIssuer
    Result = Struct.new(:document_id, :document_number, :pdf_bytes, keyword_init: true)

    def self.call(order)
      new(order).call
    end

    def initialize(order)
      @order = order
    end

    def call
      return nil unless Client.configured?

      client = Client.new
      response = client.create_sales_document!(document_attributes)
      document_id = extract_id(response)
      document_number = extract_number(response)

      raise Error, "TOConline did not return a document id" if document_id.blank?

      @order.update_columns(
        toconline_document_id: document_id.to_s,
        toconline_document_number: document_number,
        updated_at: Time.current
      )

      pdf_bytes = client.download_document_pdf(document_id)

      begin
        client.email_document!(
          document_id,
          to_email: @order.user.email,
          subject: "Fatura Mezzanine — #{document_number || @order.invoice_number}"
        )
      rescue StandardError => e
        Rails.logger.warn("TOConline email send failed for order #{@order.id}: #{e.message}")
      end

      Result.new(
        document_id: document_id.to_s,
        document_number: document_number,
        pdf_bytes: pdf_bytes
      )
    rescue ConfigurationError
      nil
    rescue StandardError => e
      Rails.logger.error("TOConline invoice failed for order #{@order.id}: #{e.class}: #{e.message}")
      nil
    end

    private

    def document_attributes
      attrs = {
        document_type: ENV.fetch("TOCONLINE_DOCUMENT_TYPE", "FR"),
        date: (@order.paid_at || Time.current).in_time_zone.to_date.iso8601,
        customer_business_name: @order.customer_name,
        customer_tax_registration_number: customer_nif,
        customer_country: "PT",
        vat_included_prices: false,
        payment_mechanism: ENV.fetch("TOCONLINE_PAYMENT_MECHANISM", "CC"),
        currency_iso_code: "EUR",
        external_reference: @order.invoice_number,
        notes: booking_notes,
        lines: [ line_attributes ]
      }

      prefix = ENV["TOCONLINE_DOCUMENT_SERIES_PREFIX"].presence
      attrs[:document_series_prefix] = prefix if prefix

      attrs
    end

    def line_attributes
      {
        item_type: "Service",
        description: line_description,
        quantity: 1,
        unit_price: (@order.amount_cents / 100.0).round(2),
        tax_percentage: ENV.fetch("TOCONLINE_TAX_PERCENTAGE", "23").to_i,
        tax_country_region: "PT",
        tax_code: ENV.fetch("TOCONLINE_TAX_CODE", "NOR")
      }
    end

    def line_description
      parts = [ @order.plan_label ]
      @order.fulfillment_details.each { |label, value| parts << "#{label}: #{value}" }
      parts.join(" · ")
    end

    def booking_notes
      details = @order.fulfillment_details.map { |label, value| "#{label}: #{value}" }
      details << "Pedido web ##{@order.id}"
      details << "Stripe: #{@order.stripe_session_id}" if @order.stripe_session_id.present?
      details.join("\n")
    end

    def customer_nif
      nif = @order.vat_number.to_s.delete_prefix("PT")
      return Client::CONSUMER_NIF if nif.blank?

      nif
    end

    def extract_id(response)
      return nil unless response.is_a?(Hash)

      return response["id"] if response["id"].present?

      data = response["data"]
      data.is_a?(Hash) ? data["id"] : nil
    end

    def extract_number(response)
      return nil unless response.is_a?(Hash)

      attrs = response["attributes"] || response
      data = response["data"]
      attrs = data["attributes"] || data if data.is_a?(Hash)

      attrs["document_no"] ||
        attrs["number"] ||
        attrs["full_document_number"] ||
        attrs["document_number"] ||
        response["document_no"] ||
        response["number"]
    end
  end
end
