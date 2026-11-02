# frozen_string_literal: true

require "cgi"

module GoogleCalendarEnv
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

namespace :google_calendar do
  desc "Print the Google Calendar OAuth authorize URL (offline access for the desk calendar account)"
  task authorize_url: :environment do
    GoogleCalendarEnv.load!

    %w[GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET].each do |key|
      abort "Missing #{key}" if ENV[key].blank?
    end

    puts "Redirect URI (must be listed in Google Cloud Console → OAuth client):"
    puts GoogleCalendar::Client.redirect_uri
    puts
    puts GoogleCalendar::Client.new.authorize_url
    puts
    puts "Preferred: open /admin/google_calendar while logged in as admin and click Connect."
    puts "Or: open the URL above as the calendar owner, then:"
    puts "  CODE=<code> bin/rails google_calendar:auth"

  end

  desc "Exchange a Google OAuth authorization code for a Calendar refresh token (pass CODE=...)"
  task auth: :environment do
    GoogleCalendarEnv.load!

    code = ENV["CODE"].presence
    abort "Usage: CODE=<authorization_code> bin/rails google_calendar:auth" if code.blank?

    %w[GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET].each do |key|
      abort "Missing #{key}" if ENV[key].blank?
    end

    response = GoogleCalendar::Client.new.exchange_authorization_code(code)

    puts "access_token obtained (expires_in=#{response['expires_in']})"
    puts
    puts "Add these to .env / .env.production:"
    puts "GOOGLE_CALENDAR_ID=<the calendar id from Google Calendar settings>"
    puts "GOOGLE_CALENDAR_REFRESH_TOKEN=#{response['refresh_token']}" if response["refresh_token"].present?
    puts "CROISSANT_BOOKING_USER_EMAIL=#{ENV.fetch('CROISSANT_BOOKING_USER_EMAIL', GoogleCalendar::SystemUser::DEFAULT_EMAIL)}"
    puts
    puts "Token store: #{GoogleCalendar::TokenStore.path}"
    puts "Also enable Calendar API in Google Cloud Console for this OAuth client."
  end

  desc "Show Google Calendar sync configuration status"
  task status: :environment do
    GoogleCalendarEnv.load!

    puts "configured?: #{GoogleCalendar::Client.configured?}"
    puts "calendar_id: #{ENV['GOOGLE_CALENDAR_ID'].presence || '(missing)'}"
    puts "token store: #{GoogleCalendar::TokenStore.path} (exists=#{GoogleCalendar::TokenStore.path.exist?})"
    puts "refresh token source: " +
      if GoogleCalendar::TokenStore.refresh_token.present?
        "storage"
      elsif ENV["GOOGLE_CALENDAR_REFRESH_TOKEN"].present?
        "ENV"
      else
        "none"
      end

    begin
      user = GoogleCalendar::SystemUser.call
      puts "system user: #{user.email} (id=#{user.id})"
    rescue StandardError => e
      puts "system user: FAILED — #{e.class}: #{e.message}"
    end
  end

  desc "Run one inbound Google Calendar → desk booking sync now"
  task sync: :environment do
    GoogleCalendarEnv.load!
    abort "Google Calendar is not configured" unless GoogleCalendar::Client.configured?

    result = GoogleCalendar::SyncJob.perform_now
    puts result.inspect
  end
end
