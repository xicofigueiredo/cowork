# frozen_string_literal: true

module GoogleCalendar
  class OutboundSync
    def self.upsert(booking, client: Client.new)
      new(client: client).upsert(booking)
    end

    def self.delete_event(event_id, client: Client.new)
      new(client: client).delete_event(event_id)
    end

    def initialize(client:)
      @client = client
    end

    def upsert(booking)
      return nil unless Client.configured?
      return nil unless booking&.desk_booking?
      return nil if booking.source == "google_calendar"

      body = event_body(booking)
      if booking.google_event_id.present?
        event = @client.update_event(booking.google_event_id, body)
      else
        event = @client.insert_event(body)
        booking.update_columns(google_event_id: event["id"], updated_at: Time.current)
      end
      event
    rescue ApiError => e
      Rails.logger.error(
        "GoogleCalendar::OutboundSync upsert failed for booking #{booking.id}: #{e.class}: #{e.message}"
      )
      nil
    end

    def delete_event(event_id)
      return nil unless Client.configured?
      return nil if event_id.blank?

      @client.delete_event(event_id)
    rescue ApiError => e
      # 404/410 means already gone — treat as success.
      return nil if e.message.include?("(404)") || e.message.include?("(410)")

      Rails.logger.error(
        "GoogleCalendar::OutboundSync delete failed for event #{event_id}: #{e.class}: #{e.message}"
      )
      nil
    end

    private

    def event_body(booking)
      summary = "Mezzanine · #{booking.seat.label}"
      description = [
        "Cowork booking ##{booking.id}",
        "Guest: #{booking.user.display_name}",
        "Type: #{booking.booking_type}"
      ].join("\n")

      start_date, end_date = all_day_bounds(booking)

      {
        summary: summary,
        description: description,
        start: { date: start_date.iso8601 },
        end: { date: end_date.iso8601 },
        transparency: "opaque",
        extendedProperties: {
          private: {
            cowork_booking_id: booking.id.to_s
          }
        }
      }
    end

    # Google all-day end date is exclusive.
    def all_day_bounds(booking)
      if booking.daily?
        [ booking.date, booking.date + 1.day ]
      else
        [ booking.starts_on, booking.ends_on + 1.day ]
      end
    end
  end
end
