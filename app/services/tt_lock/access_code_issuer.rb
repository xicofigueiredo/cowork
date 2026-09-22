# frozen_string_literal: true

module TtLock
  class AccessCodeIssuer
    def self.call(**kwargs)
      new(**kwargs).call
    end

    # One permanent door code per client. Booking hooks call this.
    def self.issue_for_user!(user)
      return unless user
      return user.access_code if user.access_code&.synced_to_lock?

      call(
        user: user,
        name: user_name(user),
        permanent: true,
        source: "member"
      )
    end

    def self.issue_for_booking!(booking)
      return unless booking

      issue_for_user!(booking.user)
    end

    def self.ensure_for_user!(user)
      return unless user
      return user.access_code if user.access_code&.synced_to_lock?

      if user.access_code&.active?
        AccessCodeRevoker.call(user.access_code)
        user.reload
      end

      issue_for_user!(user)
    end

    def self.user_name(user)
      label = [ user.first_name, user.last_name ].compact.join(" ").presence || user.email
      "Member — #{label}"
    end

    def initialize(name:, source:, valid_from: nil, valid_to: nil, permanent: false, booking: nil, user: nil, code: nil)
      @booking = booking
      @user = user || booking&.user
      @name = name
      @permanent = permanent
      @valid_from = valid_from || Time.current
      @valid_to = permanent ? AccessCode.permanent_until : valid_to
      @source = source
      @code = code.presence || generate_code
    end

    def call
      unless Client.configured?
        Rails.logger.warn("TTLock not configured; skipping access code issue for #{@name}")
        return nil
      end

      if @user&.access_code&.synced_to_lock?
        return @user.access_code
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
          start_date: @permanent ? nil : @valid_from,
          end_date: @permanent ? nil : @valid_to,
          permanent: @permanent,
          name: @name
        )
        access_code.ttlock_keyboard_pwd_id = keyboard_pwd_id
        access_code.save!
        @user&.association(:access_code)&.reload
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
        code = format("%05d", SecureRandom.random_number(100_000))
        break code unless AccessCode.active.exists?(code: code)
      end
    end
  end
end
