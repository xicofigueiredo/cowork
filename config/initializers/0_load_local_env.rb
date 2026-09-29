# Load key/value pairs from .env for local development when Docker env_file is not used.
# Does not override variables already present in the process environment.
# Skips infra keys that would break local rails s if .env is production-oriented.
if Rails.env.development? || Rails.env.test?
  skip_keys = %w[
    RAILS_ENV
    RAILS_MASTER_KEY
    POSTGRES_USER
    POSTGRES_PASSWORD
    POSTGRES_DB
    COWORK_DATABASE_PASSWORD
    DB_HOST
    SOLID_QUEUE_IN_PUMA
  ].freeze

  env_path = Rails.root.join(".env")
  if env_path.exist?
    env_path.each_line do |line|
      line = line.strip
      next if line.empty? || line.start_with?("#")
      next unless line.include?("=")

      key, value = line.split("=", 2)
      key = key.strip
      next if skip_keys.include?(key)
      next if ENV[key].present?

      ENV[key] = value.strip.delete_prefix('"').delete_suffix('"').delete_prefix("'").delete_suffix("'")
    end
  end
end
