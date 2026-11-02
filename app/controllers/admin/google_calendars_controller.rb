# frozen_string_literal: true

module Admin
  class GoogleCalendarsController < BaseController
    def show
      @configured = GoogleCalendar::Client.configured?
      @calendar_id = ENV["GOOGLE_CALENDAR_ID"].presence
      @redirect_uri = GoogleCalendar::Client.redirect_uri
      @authorize_url = if ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
        GoogleCalendar::Client.new.authorize_url
      end
      @system_user_email = ENV.fetch("CROISSANT_BOOKING_USER_EMAIL", GoogleCalendar::SystemUser::DEFAULT_EMAIL)
    end

    def callback
      if params[:error].present?
        redirect_to admin_google_calendar_path, alert: "Google authorization failed: #{params[:error]}"
        return
      end

      code = params[:code].to_s.presence
      if code.blank?
        redirect_to admin_google_calendar_path, alert: "Google did not return an authorization code."
        return
      end

      response = GoogleCalendar::Client.new.exchange_authorization_code(code)
      if response["refresh_token"].blank? && GoogleCalendar::TokenStore.refresh_token.blank?
        redirect_to admin_google_calendar_path,
          alert: "No refresh token returned. Revoke app access in Google Account → Security, then connect again."
        return
      end

      redirect_to admin_google_calendar_path,
        notice: "Google Calendar connected. Refresh token saved to #{GoogleCalendar::TokenStore.path}."
    rescue GoogleCalendar::Error => e
      redirect_to admin_google_calendar_path, alert: "Google Calendar auth failed: #{e.message}"
    end

    def sync
      unless GoogleCalendar::Client.configured?
        redirect_to admin_google_calendar_path, alert: "Google Calendar is not fully configured yet."
        return
      end

      result = GoogleCalendar::SyncJob.perform_now
      redirect_to admin_google_calendar_path, notice: "Sync finished: #{result.inspect}"
    rescue GoogleCalendar::Error => e
      redirect_to admin_google_calendar_path, alert: "Sync failed: #{e.message}"
    end
  end
end
