# Configure after 0_load_local_env.rb so development .env values are available.
if ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
  Devise.setup do |config|
    config.omniauth :google_oauth2,
      ENV["GOOGLE_CLIENT_ID"],
      ENV["GOOGLE_CLIENT_SECRET"],
      {
        scope: "email,profile",
        prompt: "select_account",
        access_type: "online"
      }
  end
end

# Behind Cloudflare / SSL proxy, request.base_url can be http://. Force https
# callback URLs in production so they match Google Cloud Console.
if Rails.env.production?
  OmniAuth.config.full_host = "https://#{ENV.fetch("APP_HOST", "mezzaninecowork.com")}"
end
