# frozen_string_literal: true

module Toconline
  class ConnectionMonitor
    Result = Struct.new(:status, :error, :issued_order_ids, :log, keyword_init: true)
    BACKFILL_WINDOW = 14.days
    HEALTH_EMAIL = "francisco-abf@hotmail.com"

    def self.call
      new.call
    end

    def call
      @lines = []
      log("TOConline connection check started")
      log("configured?=#{Client.configured?}")
      log("token_store=#{TokenStore.path} exists=#{TokenStore.path.exist?}")
      log("refresh_token_source=#{refresh_token_source}")

      unless Client.configured?
        return finish(:failed, "TOConline is not configured (missing credentials / refresh token)")
      end

      client = Client.new
      begin
        client.probe!
        log("probe: OK (refresh token valid)")
        return finish(:ok)
      rescue StandardError => e
        log("probe: FAILED — #{e.class}: #{e.message}")
        return finish(:failed, e.message) unless reauth_candidate?(e)
      end

      log("attempting auto-reauthorize…")
      begin
        client.reauthorize!
        log("reauthorize: OK (new refresh token saved to #{TokenStore.path})")
      rescue StandardError => e
        log("reauthorize: FAILED — #{e.class}: #{e.message}")
        return finish(:failed, e.message)
      end

      issued = backfill_missing_invoices!
      finish(:reauthed, nil, issued)
    end

    private

    def reauth_candidate?(error)
      message = error.message.to_s
      message.include?("unauthorized_client") ||
        message.include?("TOCONLINE_REFRESH_TOKEN is not set") ||
        error.is_a?(ConfigurationError)
    end

    def backfill_missing_invoices!
      scope = Order.paid
        .where(toconline_document_id: [ nil, "" ])
        .where("amount_cents > 0")
        .where("paid_at >= ? OR (paid_at IS NULL AND created_at >= ?)", BACKFILL_WINDOW.ago, BACKFILL_WINDOW.ago)
        .order(:id)

      log("backfill candidates: #{scope.count}")
      issued = []

      scope.find_each do |order|
        log("issuing order ##{order.id} (#{order.plan_label}, #{order.total_with_iva_euros})…")
        result = InvoiceIssuer.call(order, notify_failure: false)
        if result
          log("  OK #{result.document_number} (id=#{result.document_id})")
          issued << order.id
        else
          log("  FAILED")
        end
      end

      log("backfill done: issued #{issued.size} invoice(s)")
      issued
    end

    def refresh_token_source
      if TokenStore.refresh_token.present?
        "storage"
      elsif Rails.cache.read(Client::REFRESH_CACHE_KEY).present?
        "cache"
      elsif ENV["TOCONLINE_REFRESH_TOKEN"].present?
        "ENV"
      else
        "none"
      end
    end

    def log(message)
      line = "[#{Time.current.iso8601}] #{message}"
      @lines << line
      Rails.logger.info("[Toconline::ConnectionMonitor] #{message}")
    end

    def finish(status, error = nil, issued_order_ids = [])
      log("result: #{status}#{error.present? ? " — #{error}" : ""}")
      Result.new(
        status: status,
        error: error,
        issued_order_ids: issued_order_ids,
        log: @lines.join("\n")
      )
    end
  end
end
