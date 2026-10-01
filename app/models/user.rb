class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]

  REFERRAL_SOURCES = {
    "google_search" => "Google search",
    "social_media" => "Social media",
    "coworking_marketplaces" => "Coworking marketplaces",
    "a_friend" => "A friend",
    "other" => "Other"
  }.freeze

  has_many :orders, dependent: :destroy
  has_many :bookings, dependent: :destroy
  has_many :credit_packs, dependent: :destroy
  has_many :access_codes, dependent: :nullify
  has_one :access_code, -> { where(status: "active") }, class_name: "AccessCode"

  validates :first_name, :last_name, presence: true
  validates :referral_source, presence: true, inclusion: { in: REFERRAL_SOURCES.keys }, on: :create
  validates :referral_source_other, presence: true, length: { maximum: 200 }, if: :referral_other?

  def referral_other?
    referral_source == "other"
  end

  def referral_source_label
    return nil if referral_source.blank?

    label = REFERRAL_SOURCES[referral_source] || referral_source
    return "#{label}: #{referral_source_other}" if referral_other? && referral_source_other.present?

    label
  end

  def self.google_oauth_configured?
    ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
  end

  def self.from_omniauth(auth)
    return nil unless auth&.provider.present? && auth.uid.present?

    user = find_by(provider: auth.provider, uid: auth.uid)
    return user if user

    email = auth.info.email.to_s.strip.downcase
    return nil if email.blank?

    user = find_by(email: email)
    if user
      user.provider = auth.provider
      user.uid = auth.uid
      user.skip_confirmation! unless user.confirmed?
      user.save!
      return user
    end

    nil
  end

  def password_required?
    return false if has_attribute?(:provider) && provider.present?

    super
  end

  def admin?
    emails = ENV.fetch("ADMIN_EMAILS", "").split(",").map { |e| e.strip.downcase }.reject(&:blank?)
    emails.include?(email.to_s.downcase)
  end

  def door_code_status
    return :synced if access_code&.synced_to_lock?

    failed = if access_codes.loaded?
      access_codes.any?(&:failed?)
    else
      access_codes.where(status: "failed").exists?
    end
    return :failed if failed

    :missing
  end

  def needs_door_code?
    door_code_status != :synced
  end

  def display_name
    [ first_name, last_name ].compact_blank.join(" ").presence || email
  end

  def available_credits
    remaining_day_credits
  end

  def available_meeting_hours
    remaining_meeting_hours
  end

  def remaining_day_credits
    day_credit_packs.select(&:usable?).sum(&:remaining_credits)
  end

  def remaining_meeting_hours
    meeting_hour_credit_packs.select(&:usable?).sum(&:remaining_credits)
  end

  def current_monthly_booking
    today = Date.current
    monthly_bookings
      .select { |booking| booking.starts_on <= today && booking.ends_on >= today }
      .max_by(&:ends_on)
  end

  def current_plan_label
    booking = current_monthly_booking
    return nil unless booking

    booking.order&.plan_label.presence || "Monthly"
  end

  def next_monthly_starts_on
    latest_end = bookings.monthly.where("ends_on >= ?", Date.current).maximum(:ends_on)
    latest_end ? latest_end + 1.day : Date.current
  end

  def next_monthly_period(months: 1)
    starts_on = next_monthly_starts_on
    { starts_on: starts_on, ends_on: starts_on + months.months }
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

  def day_credit_packs
    if credit_packs.loaded?
      credit_packs.select(&:day_credits?)
    else
      credit_packs.day_credits.to_a
    end
  end

  def meeting_hour_credit_packs
    if credit_packs.loaded?
      credit_packs.select(&:meeting_hour_credits?)
    else
      credit_packs.meeting_hour_credits.to_a
    end
  end

  def monthly_bookings
    if bookings.loaded?
      bookings.select(&:monthly?)
    else
      bookings.monthly.includes(:order).to_a
    end
  end

  def unique_confirmation_code
    loop do
      code = format("%06d", SecureRandom.random_number(1_000_000))
      break code unless self.class.exists?(confirmation_token: code)
    end
  end
end
