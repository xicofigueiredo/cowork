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
    puts "Add this to .env / .env.production:"
    puts "TOCONLINE_REFRESH_TOKEN=#{response['refresh_token']}"
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

  desc "Create a TOConline invoice for an order (ORDER_ID=... or latest order). Safe for localhost smoke tests."
  task test_invoice: :environment do
    ToconlineEnv.load!

    abort "TOConline is not configured (missing refresh token / credentials)" unless Toconline::Client.configured?

    order = if ENV["ORDER_ID"].present?
      Order.find(ENV["ORDER_ID"])
    else
      Order.order(id: :desc).first
    end
    abort "No order found — create a checkout order first, then retry" unless order

    puts "Issuing TOConline invoice for order ##{order.id} (#{order.plan_label}, #{order.total_with_iva_euros})..."
    puts "Customer: #{order.customer_name} <#{order.user.email}> NIF=#{order.vat_number.presence || '999999990'}"
    puts "NOTE: this creates a real FR in your TOConline company"
    result = Toconline::InvoiceIssuer.call(order)

    if result
      puts "OK document_id=#{result.document_id} number=#{result.document_number} pdf_bytes=#{result.pdf_bytes&.bytesize}"
      path = Rails.root.join("tmp", "toconline-order-#{order.id}.pdf")
      File.binwrite(path, result.pdf_bytes) if result.pdf_bytes.present?
      puts "PDF saved to #{path}" if result.pdf_bytes.present?
    else
      puts "FAILED — check log/development.log for TOConline invoice failed"
      exit 1
    end
  end
end
