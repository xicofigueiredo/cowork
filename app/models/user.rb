class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :orders, dependent: :destroy
  has_many :bookings, dependent: :destroy
  has_many :credit_packs, dependent: :destroy

  validates :first_name, :last_name, presence: true

  after_create_commit :send_welcome_email

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

  private

  def send_welcome_email
    UserMailer.welcome(self).deliver_now
  end
end
