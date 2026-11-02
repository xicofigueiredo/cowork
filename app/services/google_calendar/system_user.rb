# frozen_string_literal: true

module GoogleCalendar
  class SystemUser
    DEFAULT_EMAIL = "croissant@mezzaninecowork.com"

    def self.call
      email = ENV.fetch("CROISSANT_BOOKING_USER_EMAIL", DEFAULT_EMAIL).to_s.strip.downcase
      raise ConfigurationError, "CROISSANT_BOOKING_USER_EMAIL is blank" if email.blank?

      user = User.find_or_initialize_by(email: email)
      return user if user.persisted?

      user.first_name = "Croissant"
      user.last_name = "Guest"
      user.password = SecureRandom.hex(32)
      user.referral_source = "coworking_marketplaces"
      user.skip_confirmation!
      user.save!
      user
    end
  end
end
