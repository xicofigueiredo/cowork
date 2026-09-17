# frozen_string_literal: true

require "json"

module Toconline
  # Persists the OAuth refresh token on the app storage volume so rotated tokens
  # survive deploys and are not lost when Rails.cache expires.
  #
  # TOC invalidates the previous refresh token on every refresh. Only one
  # process may refresh at a time, and the new token must be written here
  # before anything else uses it.
  class TokenStore
    FILENAME = "toconline_tokens.json"
    LOCK_FILENAME = "toconline_tokens.lock"

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

      # Exclusive lock across Puma workers / one-off rake tasks sharing the volume.
      def with_refresh_lock
        path.parent.mkpath
        File.open(lock_path, File::RDWR | File::CREAT, 0o644) do |lock|
          lock.flock(File::LOCK_EX)
          yield
        end
      end

      def path
        Rails.root.join("storage", FILENAME)
      end

      def lock_path
        Rails.root.join("storage", LOCK_FILENAME)
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
