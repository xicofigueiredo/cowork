# frozen_string_literal: true

require "cgi"
require "net/http"
require "uri"
require "json"

module GoogleCalendar
  class Client
    TOKEN_URI = "https://oauth2.googleapis.com/token"
    AUTH_URI = "https://accounts.google.com/o/oauth2/v2/auth"
    API_BASE = "https://www.googleapis.com/calendar/v3"
    TOKEN_CACHE_KEY = "google_calendar/access_token"
    SCOPE = "https://www.googleapis.com/auth/calendar"
    OPEN_TIMEOUT = 15
    READ_TIMEOUT = 30

    def self.configured?
      ENV["GOOGLE_CLIENT_ID"].present? &&
        ENV["GOOGLE_CLIENT_SECRET"].present? &&
        ENV["GOOGLE_CALENDAR_ID"].present? &&
        current_refresh_token.present?
    end

    def self.current_refresh_token
      stored = TokenStore.refresh_token.presence
      return stored if stored.present?

      env = ENV["GOOGLE_CALENDAR_REFRESH_TOKEN"].presence
      TokenStore.write_refresh_token!(env) if env.present?
      env
    end

    def self.calendar_id
      ENV.fetch("GOOGLE_CALENDAR_ID")
    end

    def self.redirect_uri
      return ENV["GOOGLE_CALENDAR_REDIRECT_URI"] if ENV["GOOGLE_CALENDAR_REDIRECT_URI"].present?

      host = ENV.fetch("APP_HOST", "localhost:3000").to_s.delete_prefix("https://").delete_prefix("http://")
      protocol = host.start_with?("localhost", "127.0.0.1") ? "http" : "https"
      "#{protocol}://#{host}/admin/google_calendar/callback"
    end


    def initialize
      @client_id = ENV.fetch("GOOGLE_CLIENT_ID")
      @client_secret = ENV.fetch("GOOGLE_CLIENT_SECRET")
      @calendar_id = ENV["GOOGLE_CALENDAR_ID"].presence
    end

    def authorize_url
      params = {
        client_id: @client_id,
        redirect_uri: self.class.redirect_uri,
        response_type: "code",
        scope: SCOPE,
        access_type: "offline",
        prompt: "consent"
      }
      "#{AUTH_URI}?#{URI.encode_www_form(params)}"
    end


    def exchange_authorization_code(code)
      response = token_request(
        grant_type: "authorization_code",
        code: code,
        redirect_uri: self.class.redirect_uri
      )
      persist_tokens!(response)
      response
    end

    def list_events(time_min:, time_max:)
      events = []
      page_token = nil

      loop do
        params = {
          timeMin: time_min.utc.iso8601,
          timeMax: time_max.utc.iso8601,
          singleEvents: true,
          orderBy: "startTime",
          showDeleted: true,
          maxResults: 250
        }
        params[:pageToken] = page_token if page_token.present?

        payload = api_request(:get, "/calendars/#{encoded_calendar_id}/events", params: params)
        events.concat(Array(payload["items"]))
        page_token = payload["nextPageToken"]
        break if page_token.blank?
      end

      events
    end

    def insert_event(body)
      api_request(:post, "/calendars/#{encoded_calendar_id}/events", body: body)
    end

    def update_event(event_id, body)
      api_request(:put, "/calendars/#{encoded_calendar_id}/events/#{CGI.escape(event_id)}", body: body)
    end

    def delete_event(event_id)
      api_request(:delete, "/calendars/#{encoded_calendar_id}/events/#{CGI.escape(event_id)}")
    end

    private

    def encoded_calendar_id
      id = @calendar_id.presence || self.class.calendar_id
      CGI.escape(id)
    end


    def access_token
      cached = Rails.cache.read(TOKEN_CACHE_KEY)
      return cached if cached.present?

      TokenStore.with_refresh_lock do
        cached = Rails.cache.read(TOKEN_CACHE_KEY)
        return cached if cached.present?

        refresh = self.class.current_refresh_token
        raise ConfigurationError, "Google Calendar refresh token missing" if refresh.blank?

        response = token_request(
          grant_type: "refresh_token",
          refresh_token: refresh
        )
        persist_tokens!(response)
        response.fetch("access_token")
      end
    end

    def persist_tokens!(response)
      token = response["access_token"]
      raise ApiError, "Google token response missing access_token" if token.blank?

      expires_in = response["expires_in"].to_i
      ttl = expires_in.positive? ? [ expires_in - 60, 60 ].max.seconds : 50.minutes
      Rails.cache.write(TOKEN_CACHE_KEY, token, expires_in: ttl)

      if response["refresh_token"].present?
        TokenStore.write_refresh_token!(response["refresh_token"])
      end
    end

    def token_request(**params)
      body = URI.encode_www_form(
        params.merge(
          client_id: @client_id,
          client_secret: @client_secret
        )
      )
      uri = URI(TOKEN_URI)
      response = http_request(:post, uri, body: body, headers: {
        "Content-Type" => "application/x-www-form-urlencoded"
      })
      parse_json_response!(response)
    end

    def api_request(method, path, params: nil, body: nil)
      uri = URI("#{API_BASE}#{path}")
      uri.query = URI.encode_www_form(params) if params.present?

      headers = {
        "Authorization" => "Bearer #{access_token}",
        "Accept" => "application/json"
      }
      payload = nil
      if body
        headers["Content-Type"] = "application/json"
        payload = JSON.generate(body)
      end

      response = http_request(method, uri, body: payload, headers: headers)
      return nil if response.code.to_i == 204

      parse_json_response!(response)
    end

    def parse_json_response!(response)
      code = response.code.to_i
      body = response.body.to_s
      data = body.present? ? JSON.parse(body) : {}

      unless code.between?(200, 299)
        message = data.dig("error", "message") || data["error_description"] || body.presence || "HTTP #{code}"
        raise ApiError, "Google Calendar API error (#{code}): #{message}"
      end

      data
    rescue JSON::ParserError
      raise ApiError, "Google Calendar API returned invalid JSON (#{response.code})"
    end

    def http_request(method, uri, body: nil, headers: {})
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = case method
      when :get then Net::HTTP::Get.new(uri)
      when :post then Net::HTTP::Post.new(uri)
      when :put then Net::HTTP::Put.new(uri)
      when :delete then Net::HTTP::Delete.new(uri)
      else
        raise ArgumentError, "unsupported method #{method}"
      end

      headers.each { |key, value| request[key] = value }
      request.body = body if body

      http.request(request)
    end
  end
end
