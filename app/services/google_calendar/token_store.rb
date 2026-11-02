# frozen_string_literal: true

require "json"

module GoogleCalendar
  # Persists the Calendar OAuth refresh token on the app storage volume so it
  # survives deploys and is not lost when Rails.cache expires.
  class TokenStore
    FILENAME = "google_calendar_tokens.json"
    LOCK_FILENAME = "google_calendar_tokens.lock"

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
        ENV["GOOGLE_CALENDAR_REFRESH_TOKEN"] = token
      rescue Errno::EACCES => e
        raise Error,
              "#{e.message}. Fix with: docker compose exec -u root server chown -R rails:rails /rails/storage"
      end

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
