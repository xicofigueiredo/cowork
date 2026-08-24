class Lead < ApplicationRecord
  normalizes :first_name, :last_name, with: ->(value) { value.strip }
  normalizes :email, with: ->(value) { value.strip.downcase }
  normalizes :message, with: ->(value) { value.strip.presence }

  validates :first_name, :last_name, :email, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :privacy_accepted, acceptance: true
end
