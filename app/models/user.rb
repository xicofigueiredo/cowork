class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable

  has_many :orders, dependent: :destroy
  has_many :bookings, dependent: :destroy
  has_many :credit_packs, dependent: :destroy

  validates :first_name, :last_name, presence: true

  def available_credits
    credit_packs.day_credits.usable.sum(:remaining_credits)
  end

  def available_meeting_hours
    credit_packs.meeting_hour_credits.select(&:usable?).sum(&:remaining_credits)
  end

  def next_monthly_starts_on
    latest_end = bookings.monthly.where("ends_on >= ?", Date.current).maximum(:ends_on)
    latest_end ? latest_end + 1.day : Date.current
  end

  def next_monthly_period
    starts_on = next_monthly_starts_on
    { starts_on: starts_on, ends_on: starts_on + 1.month }
  end

  protected

  # Store a 6-digit code instead of Devise's long token.
  def generate_confirmation_token
    if confirmation_token && !confirmation_period_expired?
      @raw_confirmation_token = confirmation_token
    else
      self.confirmation_token = @raw_confirmation_token = unique_confirmation_code
      self.confirmation_sent_at = Time.now.utc
    end
  end

  def after_confirmation
    UserMailer.welcome(self).deliver_now
  end

  private

  def unique_confirmation_code
    loop do
      code = format("%06d", SecureRandom.random_number(1_000_000))
      break code unless self.class.exists?(confirmation_token: code)
    end
  end
end
