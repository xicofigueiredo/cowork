# frozen_string_literal: true

require "cgi"

namespace :toconline do
  desc "Exchange a TOConline OAuth authorization code for tokens (pass CODE=...)"
  task auth: :environment do
    code = ENV["CODE"].presence
    abort "Usage: CODE=<authorization_code> bin/rails toconline:auth" if code.blank?

    %w[TOCONLINE_CLIENT_ID TOCONLINE_CLIENT_SECRET TOCONLINE_OAUTH_URL TOCONLINE_API_URL].each do |key|
      abort "Missing #{key}" if ENV[key].blank?
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
    client_id = ENV.fetch("TOCONLINE_CLIENT_ID")
    oauth_url = ENV.fetch("TOCONLINE_OAUTH_URL").chomp("/")
    redirect_uri = CGI.escape(ENV.fetch("TOCONLINE_REDIRECT_URI", "https://oauth.pstmn.io/v1/callback"))

    puts "#{oauth_url}/auth?client_id=#{client_id}&redirect_uri=#{redirect_uri}&response_type=code&scope=commercial"
    puts
    puts "1. Open that URL with curl -v (do not follow redirects) or configure redirect"
    puts "2. Copy the code= from the Location header"
    puts "3. Run: CODE=<code> bin/rails toconline:auth"
  end
end
