# frozen_string_literal: true

module GoogleCalendar
  class OutboundSyncJob < ApplicationJob
    queue_as :default

    # action: "upsert" with booking_id, or "delete" with google_event_id
    def perform(id, action = "upsert")
      return unless Client.configured?

      case action.to_s
      when "upsert"
        booking = Booking.find_by(id: id)
        OutboundSync.upsert(booking) if booking
      when "delete"
        OutboundSync.delete_event(id)
      else
        Rails.logger.warn("GoogleCalendar::OutboundSyncJob unknown action=#{action.inspect}")
      end
    end
  end
end
