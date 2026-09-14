# frozen_string_literal: true

require "cgi"

module ToconlineEnv
  module_function

  def load!
    [ ".env.production", ".env" ].each do |filename|
      path = Rails.root.join(filename)
      next unless path.exist?

      path.each_line do |line|
        line = line.strip
        next if line.empty? || line.start_with?("#")
        next unless line.include?("=")

        key, value = line.split("=", 2)
        key = key.strip
        value = value.strip.delete_prefix('"').delete_suffix('"').delete_prefix("'").delete_suffix("'")
        ENV[key] = value if ENV[key].blank?
      end
    end
  end
end

namespace :toconline do
  desc "Exchange a TOConline OAuth authorization code for tokens (pass CODE=...)"
  task auth: :environment do
    ToconlineEnv.load!

    code = ENV["CODE"].presence
    abort "Usage: CODE=<authorization_code> bin/rails toconline:auth" if code.blank?

    %w[TOCONLINE_CLIENT_ID TOCONLINE_CLIENT_SECRET TOCONLINE_OAUTH_URL TOCONLINE_API_URL].each do |key|
      abort "Missing #{key} (set it in .env.production)" if ENV[key].blank?
    end

    client = Toconline::Client.new
    response = client.exchange_authorization_code(code)

    puts "access_token obtained (expires_in=#{response['expires_in']})"
    puts
    puts "Add this to .env / .env.production (backup only — live token is also saved to storage/toconline_tokens.json):"
    puts "TOCONLINE_REFRESH_TOKEN=#{response['refresh_token']}"
    puts
    puts "Token store: #{Toconline::TokenStore.path}"
  end

  desc "Print the TOConline OAuth authorize URL to open in a browser / curl"
  task authorize_url: :environment do
    ToconlineEnv.load!

    %w[TOCONLINE_CLIENT_ID TOCONLINE_OAUTH_URL].each do |key|
      abort "Missing #{key} (set it in .env.production)" if ENV[key].blank?
    end

    client_id = ENV.fetch("TOCONLINE_CLIENT_ID")
    oauth_url = ENV.fetch("TOCONLINE_OAUTH_URL").chomp("/")
    redirect_uri = CGI.escape(ENV.fetch("TOCONLINE_REDIRECT_URI", "https://oauth.pstmn.io/v1/callback"))

    puts "#{oauth_url}/auth?client_id=#{client_id}&redirect_uri=#{redirect_uri}&response_type=code&scope=commercial"
    puts
    puts "1. Run: curl -v 'URL_ABOVE'   (do not follow redirects)"
    puts "2. Copy the code= from the Location header"
    puts "3. Run: CODE=<code> bin/rails toconline:auth"
  end

  desc "Show TOConline auth status (does not create documents)"
  task status: :environment do
    ToconlineEnv.load!

    puts "configured?: #{Toconline::Client.configured?}"
    puts "token store: #{Toconline::TokenStore.path} (exists=#{Toconline::TokenStore.path.exist?})"
    puts "refresh token source: " +
      if Toconline::TokenStore.refresh_token.present?
        "storage"
      elsif Rails.cache.read(Toconline::Client::REFRESH_CACHE_KEY).present?
        "cache"
      elsif ENV["TOCONLINE_REFRESH_TOKEN"].present?
        "ENV"
      else
        "none"
      end

    begin
      client = Toconline::Client.new
      client.send(:access_token)
      puts "access token: OK"
    rescue StandardError => e
      puts "access token: FAILED — #{e.class}: #{e.message}"
      exit 1
    end
  end

  desc "List paid orders and their TOConline invoice status"
  task orders: :environment do
    ToconlineEnv.load!

    Order.paid.order(:id).find_each do |order|
      toc = if order.toconline_document_id.present?
        "#{order.toconline_document_number.presence || '?} (id=#{order.toconline_document_id})"
      else
        "MISSING"
      end
      puts format(
        "#%-4d %-16s %-10s %-28s %s",
        order.id,
        order.plan_type,
        order.total_with_iva_euros,
        order.user.email.to_s[0, 28],
        toc
      )
    end
  end

  desc "Create a TOConline invoice for an order (ORDER_ID=... or latest). FORCE=1 recreates even if one is stored."
  task invoice: :environment do
    Rake::Task["toconline:test_invoice"].invoke
  end

  desc "Create TOConline invoices for all paid orders missing one (FORCE=1 also recreates stored ones)"
  task backfill: :environment do
    ToconlineEnv.load!
    abort "TOConline is not configured" unless Toconline::Client.configured?

    force = ENV["FORCE"].to_s == "1"
    scope = Order.paid.order(:id)
    scope = scope.where(toconline_document_id: [ nil, "" ]) unless force

    count = 0
    scope.find_each do |order|
      if force && order.toconline_document_id.present?
        puts "Clearing stored TOC refs for order ##{order.id} (was #{order.toconline_document_number})"
        order.update_columns(toconline_document_id: nil, toconline_document_number: nil, updated_at: Time.current)
      end

      puts "Issuing order ##{order.id} (#{order.plan_label}, #{order.total_with_iva_euros})..."
      result = Toconline::InvoiceIssuer.call(order)
      if result
        puts "  OK #{result.document_number} (id=#{result.document_id})"
        count += 1
      else
        puts "  FAILED"
      end
    end

    puts "Done. Issued #{count} invoice(s)."
  end

  desc "Create a TOConline invoice for an order (ORDER_ID=... or latest order). FORCE=1 to recreate."
  task test_invoice: :environment do
    ToconlineEnv.load!

    abort "TOConline is not configured (missing refresh token / credentials)" unless Toconline::Client.configured?

    order = if ENV["ORDER_ID"].present?
      Order.find(ENV["ORDER_ID"])
    else
      Order.order(id: :desc).first
    end
    abort "No order found — create a checkout order first, then retry" unless order

    if order.toconline_document_id.present?
      if ENV["FORCE"].to_s == "1"
        puts "FORCE=1 — clearing stored TOC refs (was #{order.toconline_document_number} id=#{order.toconline_document_id})"
        order.update_columns(toconline_document_id: nil, toconline_document_number: nil, updated_at: Time.current)
      else
        puts "Order ##{order.id} already has TOC document #{order.toconline_document_number} (id=#{order.toconline_document_id})"
        puts "If it is missing in TOC Online, recreate with: FORCE=1 ORDER_ID=#{order.id} bin/rails toconline:invoice"
        exit 1
      end
    end

    puts "Issuing TOConline invoice for order ##{order.id} (#{order.plan_label}, #{order.total_with_iva_euros})..."
    puts "Customer: #{order.customer_name} <#{order.user.email}> NIF=#{order.vat_number.presence || '999999990'}"
    puts "NOTE: this creates a real FR in your TOConline company"
    result = Toconline::InvoiceIssuer.call(order)

    if result
      puts "OK document_id=#{result.document_id} number=#{result.document_number} pdf_bytes=#{result.pdf_bytes&.bytesize}"
      path = Rails.root.join("tmp", "toconline-order-#{order.id}.pdf")
      File.binwrite(path, result.pdf_bytes) if result.pdf_bytes.present?
      puts "PDF saved to #{path}" if result.pdf_bytes.present?
      puts "Rotated refresh token was saved to #{Toconline::TokenStore.path}"
    else
      puts "FAILED — check logs / admin email for TOConline invoice failed"
      exit 1
    end
  end
end
