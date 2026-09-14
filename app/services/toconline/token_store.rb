# frozen_string_literal: true

require "json"

module Toconline
  # Persists the OAuth refresh token on the app storage volume so rotated tokens
  # survive deploys and are not lost when Rails.cache expires.
  class TokenStore
    FILENAME = "toconline_tokens.json"

    class << self
      def refresh_token
        read["refresh_token"].presence
      end

      def write_refresh_token!(token)
        return if token.blank?

        payload = read.merge(
          "refresh_token" => token,
          "updated_at" => Time.current.iso8601
        )
        path.parent.mkpath
        tmp = path.sub_ext(".tmp")
        File.write(tmp, JSON.pretty_generate(payload))
        File.rename(tmp, path)
        ENV["TOCONLINE_REFRESH_TOKEN"] = token
      rescue Errno::EACCES => e
        raise Error,
              "#{e.message}. Fix with: docker compose exec -u root server chown -R rails:rails /rails/storage"
      end

      def path
        Rails.root.join("storage", FILENAME)
      end

      private

      def read
        return {} unless path.exist?

        JSON.parse(File.read(path))
      rescue JSON::ParserError, Errno::ENOENT
        {}
      end
    end
  end
end
