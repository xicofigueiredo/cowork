# frozen_string_literal: true

module TtLock
  class AccessCodeIssuer
    OPEN_HOUR = MeetingRoomAvailability::OPEN_HOUR
    CLOSE_HOUR = MeetingRoomAvailability::CLOSE_HOUR

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def self.issue_for_booking!(booking)
      return unless booking
      return if booking.access_code&.active?

      window = validity_window_for(booking)
      call(
        booking: booking,
        user: booking.user,
        name: booking_name(booking),
        valid_from: window[:valid_from],
        valid_to: window[:valid_to],
        source: "booking"
      )
    end

    def self.regenerate_for_booking!(booking)
      return unless booking

      AccessCodeRevoker.call(booking.access_code) if booking.access_code&.active?
      booking.reload
      issue_for_booking!(booking)
    end

    def self.validity_window_for(booking)
      if booking.meeting_hourly?
        { valid_from: booking.starts_at, valid_to: booking.ends_at }
      elsif booking.monthly?
        {
          valid_from: booking.starts_on.in_time_zone.change(hour: OPEN_HOUR),
          valid_to: booking.ends_on.in_time_zone.change(hour: CLOSE_HOUR)
        }
      else
        date = booking.date
        {
          valid_from: date.in_time_zone.change(hour: OPEN_HOUR),
          valid_to: date.in_time_zone.change(hour: CLOSE_HOUR)
        }
      end
    end

    def self.booking_name(booking)
      user_label = [ booking.user.first_name, booking.user.last_name ].compact.join(" ").presence || booking.user.email
      "Booking ##{booking.id} — #{user_label}"
    end

    def initialize(name:, valid_from:, valid_to:, source:, booking: nil, user: nil, code: nil)
      @booking = booking
      @user = user || booking&.user
      @name = name
      @valid_from = valid_from
      @valid_to = valid_to
      @source = source
      @code = code.presence || generate_code
    end

    def call
      unless Client.configured?
        Rails.logger.warn("TTLock not configured; skipping access code issue for #{@name}")
        return nil
      end

      access_code = AccessCode.new(
        booking: @booking,
        user: @user,
        code: @code,
        name: @name,
        valid_from: @valid_from,
        valid_to: @valid_to,
        source: @source,
        status: "active"
      )

      begin
        keyboard_pwd_id = Client.new.add_passcode!(
          keyboard_pwd: @code,
          start_date: @valid_from,
          end_date: @valid_to,
          name: @name
        )
        access_code.ttlock_keyboard_pwd_id = keyboard_pwd_id
        access_code.save!
        @booking&.association(:access_code)&.reload
        access_code
      rescue Error, ActiveRecord::RecordInvalid => e
        Rails.logger.error("TTLock access code issue failed: #{e.class}: #{e.message}")
        access_code.status = "failed"
        access_code.ttlock_keyboard_pwd_id = nil
        begin
          access_code.save!
        rescue ActiveRecord::RecordInvalid
          # Ignore persistence of failed record if validations still fail.
        end
        raise if @source == "manual"

        access_code.persisted? ? access_code : nil
      end
    end

    private

    def generate_code
      loop do
        code = format("%06d", SecureRandom.random_number(1_000_000))
        break code unless AccessCode.active.exists?(code: code)
      end
    end
  end
end
