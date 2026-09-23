# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "base64"

module Toconline
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ApiError < Error; end

  class Client
    CONSUMER_NIF = "999999990"
    TOKEN_CACHE_KEY = "toconline/access_token"
    REFRESH_CACHE_KEY = "toconline/refresh_token"
    OPEN_TIMEOUT = 30
    READ_TIMEOUT = 60
    MAX_ATTEMPTS = 3
    TRANSIENT_ERRORS = [
      Net::OpenTimeout,
      Net::ReadTimeout,
      Errno::ECONNRESET,
      Errno::ECONNREFUSED,
      Errno::EHOSTUNREACH,
      Errno::ETIMEDOUT,
      SocketError,
      EOFError
    ].freeze

    def self.configured?
      ENV["TOCONLINE_CLIENT_ID"].present? &&
        ENV["TOCONLINE_CLIENT_SECRET"].present? &&
        ENV["TOCONLINE_API_URL"].present? &&
        ENV["TOCONLINE_OAUTH_URL"].present? &&
        current_refresh_token.present?
    end

    def self.current_refresh_token
      stored = TokenStore.refresh_token.presence
      return stored if stored.present?

      cached = Rails.cache.read(REFRESH_CACHE_KEY).presence
      env = ENV["TOCONLINE_REFRESH_TOKEN"].presence
      token = cached || env

      # Seed durable storage from ENV/cache so the next rotated token has a home.
      TokenStore.write_refresh_token!(token) if token.present?

      token
    end

    def initialize
      @client_id = ENV.fetch("TOCONLINE_CLIENT_ID")
      @client_secret = ENV.fetch("TOCONLINE_CLIENT_SECRET")
      @api_url = ENV.fetch("TOCONLINE_API_URL").chomp("/")
      @oauth_url = ENV.fetch("TOCONLINE_OAUTH_URL").chomp("/")
      @redirect_uri = ENV.fetch("TOCONLINE_REDIRECT_URI", "https://oauth.pstmn.io/v1/callback")
    end

    def exchange_authorization_code(code)
      response = token_request(
        grant_type: "authorization_code",
        code: code,
        redirect_uri: @redirect_uri,
        scope: "commercial"
      )
      persist_tokens!(response)
      response
    end

    # Forces a refresh so a cached access token cannot hide a dead refresh token.
    def healthy?
      probe!
      true
    rescue StandardError
      false
    end

    def probe!
      Rails.cache.delete(TOKEN_CACHE_KEY)
      access_token
    end

    def authorize_url
      params = {
        client_id: @client_id,
        redirect_uri: @redirect_uri,
        response_type: "code",
        scope: "commercial"
      }
      "#{@oauth_url}/auth?#{URI.encode_www_form(params)}"
    end

    # Non-interactive re-auth used by the daily health job. Relies on TOC
    # auto-approving this OAuth client (same flow as curl + toconline:auth).
    def reauthorize!
      TokenStore.with_refresh_lock do
        uri = URI(authorize_url)
        response = http_request(:get, uri, headers: { "Accept" => "*/*" })
        location = response["location"].to_s
        if location.blank?
          raise ApiError,
                "TOConline authorize did not redirect (#{response.code}): re-auth needs a browser"
        end

        code = extract_oauth_code(location)
        raise ApiError, "TOConline authorize redirect missing code: #{location}" if code.blank?

        exchange_authorization_code(code)
      end
    end

    def create_sales_document!(attributes)
      api_request(
        :post,
        "/api/v1/commercial_sales_documents",
        body: attributes,
        jsonapi: false
      )
    end

    def download_document_pdf(document_id)
      print_info = api_request(
        :get,
        "/api/url_for_print/#{document_id}",
        query: { "filter[type]" => "Document", "filter[copies]" => "1" }
      )

      url = build_public_file_url(print_info)
      raise ApiError, "TOConline PDF URL missing for document #{document_id}" if url.blank?

      uri = URI(url)
      response = http_request(:get, uri, headers: {})
      unless response.is_a?(Net::HTTPSuccess)
        raise ApiError, "TOConline PDF download failed (#{response.code})"
      end

      response.body
    end

    def email_document!(document_id, to_email:, subject: nil)
      api_request(
        :patch,
        "/api/email/document/#{document_id}",
        body: {
          data: {
            type: "email/document",
            id: document_id.to_s,
            attributes: {
              type: "Document",
              to_email: to_email,
              from_name: "Mezzanine",
              subject: subject
            }.compact
          }
        }
      )
    end

    private

    def api_request(method, path, body: nil, query: nil, retried: false, jsonapi: true)
      uri = URI("#{@api_url}#{path}")
      uri.query = URI.encode_www_form(query) if query.present?

      headers = {
        "Accept" => "application/json",
        "Authorization" => "Bearer #{access_token}",
        "Content-Type" => jsonapi ? "application/vnd.api+json" : "application/json"
      }

      response = http_request(method, uri, body: body, headers: headers)

      if response.code.to_i == 401 && !retried
        refresh_access_token!
        return api_request(method, path, body: body, query: query, retried: true, jsonapi: jsonapi)
      end

      parsed = parse_json(response.body)
      unless response.is_a?(Net::HTTPSuccess)
        raise ApiError, "TOConline #{method.upcase} #{path} failed (#{response.code}): #{parsed.inspect}"
      end

      parsed
    end

    def access_token
      cached = Rails.cache.read(TOKEN_CACHE_KEY)
      return cached if cached.present?

      refresh_access_token!
      Rails.cache.read(TOKEN_CACHE_KEY)
    end

    def refresh_access_token!
      TokenStore.with_refresh_lock do
        # Another worker may have refreshed while we waited for the lock.
        cached = Rails.cache.read(TOKEN_CACHE_KEY)
        return cached if cached.present?

        refresh = self.class.current_refresh_token
        raise ConfigurationError, "TOCONLINE_REFRESH_TOKEN is not set. Run bin/rails toconline:auth" if refresh.blank?

        response = token_request(
          grant_type: "refresh_token",
          refresh_token: refresh,
          scope: "commercial"
        )
        persist_tokens!(response)
      end
    end


    def token_request(**params)
      uri = URI("#{@oauth_url}/token")
      basic = Base64.strict_encode64("#{@client_id}:#{@client_secret}")

      response = http_request(
        :post,
        uri,
        form: params,
        headers: {
          "Authorization" => "Basic #{basic}",
          "Accept" => "application/json",
          "Content-Type" => "application/x-www-form-urlencoded"
        }
      )

      parsed = parse_json(response.body)
      unless response.is_a?(Net::HTTPSuccess)
        raise ApiError, "TOConline token request failed (#{response.code}): #{parsed.inspect}"
      end

      parsed
    end

    def http_request(method, uri, headers:, body: nil, form: nil)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 15
      http.read_timeout = 30

      request_class = {
        get: Net::HTTP::Get,
        post: Net::HTTP::Post,
        patch: Net::HTTP::Patch
      }.fetch(method)

      request = request_class.new(uri)
      headers.each { |key, value| request[key] = value }

      if form
        request.body = URI.encode_www_form(form)
      elsif body
        request.body = JSON.generate(body)
      end

      http.request(request)
    end

    def persist_tokens!(payload)
      access = payload["access_token"]
      refresh = payload["refresh_token"]
      expires_in = payload["expires_in"].to_i

      raise ApiError, "TOConline token response missing access_token" if access.blank?

      # Access tokens are short-lived — cache is fine.
      Rails.cache.write(TOKEN_CACHE_KEY, access, expires_in: [ expires_in - 60, 60 ].max.seconds)

      # TOC rotates refresh tokens on every successful refresh. If we don't
      # persist the new one, the next request gets unauthorized_client.
      if refresh.blank?
        raise ApiError,
              "TOConline token response missing refresh_token — refusing to continue with a rotated-away token"
      end

      TokenStore.write_refresh_token!(refresh)
      Rails.cache.write(REFRESH_CACHE_KEY, refresh)
    end


    def extract_oauth_code(location)
      query = URI(location).query.to_s
      URI.decode_www_form(query).to_h["code"].presence
    rescue URI::InvalidURIError
      nil
    end

    def parse_json(raw)
      return {} if raw.blank?

      JSON.parse(raw)
    rescue JSON::ParserError
      { "raw" => raw.to_s }
    end

    def build_public_file_url(print_info)
      data = print_info.is_a?(Hash) ? print_info["data"] || print_info : print_info
      attrs = data.is_a?(Hash) ? (data["attributes"] || data) : {}

      url = attrs["url"]
      case url
      when String
        return url if url.present?
      when Hash
        return compose_url(url)
      end

      compose_url(attrs) || compose_url(print_info)
    end

    def compose_url(parts)
      return nil unless parts.is_a?(Hash)
      return nil if parts["scheme"].blank? || parts["host"].blank? || parts["path"].blank?

      port = parts["port"].presence
      default_port = parts["scheme"] == "https" ? 443 : 80
      authority = if port.present? && port.to_i != default_port
        "#{parts['host']}:#{port}"
      else
        parts["host"]
      end

      "#{parts['scheme']}://#{authority}#{parts['path']}"
    end
  end
end
