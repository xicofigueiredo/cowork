# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "digest"

module TtLock
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ApiError < Error; end

  class Client
    API_BASE = "https://api.sciener.com"
    TOKEN_CACHE_KEY = "tt_lock/access_token"
    REFRESH_CACHE_KEY = "tt_lock/refresh_token"

    def self.configured?
      ENV["TTLOCK_CLIENT_ID"].present? &&
        ENV["TTLOCK_CLIENT_SECRET"].present? &&
        ENV["TTLOCK_USERNAME"].present? &&
        ENV["TTLOCK_PASSWORD"].present? &&
        ENV["TTLOCK_LOCK_ID"].present?
    end

    def initialize
      raise ConfigurationError, "TTLock is not configured" unless self.class.configured?

      @client_id = ENV.fetch("TTLOCK_CLIENT_ID")
      @client_secret = ENV.fetch("TTLOCK_CLIENT_SECRET")
      @username = ENV.fetch("TTLOCK_USERNAME")
      @password = ENV.fetch("TTLOCK_PASSWORD")
      @lock_id = ENV.fetch("TTLOCK_LOCK_ID").to_i
      @api_base = ENV.fetch("TTLOCK_API_URL", API_BASE).chomp("/")
    end

    def add_passcode!(keyboard_pwd:, start_date:, end_date:, name: nil)
      params = {
        clientId: @client_id,
        accessToken: access_token,
        lockId: @lock_id,
        keyboardPwd: keyboard_pwd.to_s,
        keyboardPwdName: name,
        keyboardPwdType: 3,
        startDate: to_ms(start_date),
        endDate: to_ms(end_date),
        addType: 2,
        date: now_ms
      }.compact

      response = api_post("/v3/keyboardPwd/add", params)
      keyboard_pwd_id = response["keyboardPwdId"]
      raise ApiError, "TTLock add passcode missing keyboardPwdId: #{response.inspect}" if keyboard_pwd_id.blank?

      keyboard_pwd_id.to_s
    end

    def delete_passcode!(keyboard_pwd_id)
      params = {
        clientId: @client_id,
        accessToken: access_token,
        lockId: @lock_id,
        keyboardPwdId: keyboard_pwd_id.to_i,
        deleteType: 2,
        date: now_ms
      }

      api_post("/v3/keyboardPwd/delete", params)
    end

    private

    def access_token
      cached = Rails.cache.read(TOKEN_CACHE_KEY)
      return cached if cached.present?

      fetch_access_token!
      Rails.cache.read(TOKEN_CACHE_KEY)
    end

    def fetch_access_token!
      refresh = Rails.cache.read(REFRESH_CACHE_KEY)
      if refresh.present?
        begin
          return persist_tokens!(token_request(refresh_token: refresh))
        rescue ApiError
          Rails.cache.delete(REFRESH_CACHE_KEY)
        end
      end

      persist_tokens!(
        token_request(
          username: @username,
          password: Digest::MD5.hexdigest(@password)
        )
      )
    end

    def token_request(**extra)
      params = {
        clientId: @client_id,
        clientSecret: @client_secret
      }.merge(extra)

      response = http_post("#{@api_base}/oauth2/token", params)
      parsed = parse_json(response.body)

      unless response.is_a?(Net::HTTPSuccess) && parsed["access_token"].present?
        raise ApiError, "TTLock token request failed (#{response.code}): #{parsed.inspect}"
      end

      parsed
    end

    def persist_tokens!(payload)
      access = payload["access_token"]
      refresh = payload["refresh_token"]
      expires_in = payload["expires_in"].to_i

      raise ApiError, "TTLock token response missing access_token" if access.blank?

      Rails.cache.write(TOKEN_CACHE_KEY, access, expires_in: [ expires_in - 60, 60 ].max.seconds)
      Rails.cache.write(REFRESH_CACHE_KEY, refresh, expires_in: 90.days) if refresh.present?
      payload
    end

    def api_post(path, params, retried: false)
      response = http_post("#{@api_base}#{path}", params)
      parsed = parse_json(response.body)

      if token_expired?(parsed) && !retried
        Rails.cache.delete(TOKEN_CACHE_KEY)
        params = params.merge(accessToken: access_token)
        return api_post(path, params, retried: true)
      end

      errcode = parsed["errcode"]
      if errcode.present? && errcode.to_i != 0 && parsed["keyboardPwdId"].blank?
        raise ApiError, "TTLock #{path} failed (#{errcode}): #{parsed['errmsg'] || parsed.inspect}"
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise ApiError, "TTLock #{path} failed (#{response.code}): #{parsed.inspect}"
      end

      parsed
    end

    def token_expired?(parsed)
      return false unless parsed.is_a?(Hash)

      errcode = parsed["errcode"].to_i
      errcode == 10004 || errcode == 10003
    end

    def http_post(url, form)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 15
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/x-www-form-urlencoded"
      request["Accept"] = "application/json"
      request.body = URI.encode_www_form(form)

      http.request(request)
    end

    def parse_json(raw)
      return {} if raw.blank?

      JSON.parse(raw)
    rescue JSON::ParserError
      { "raw" => raw.to_s }
    end

    def to_ms(time)
      (time.to_time.to_f * 1000).to_i
    end

    def now_ms
      to_ms(Time.current)
    end
  end
end
