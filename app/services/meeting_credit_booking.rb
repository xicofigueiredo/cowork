class MeetingCreditBooking
  class Error < StandardError; end

  def self.call(user:, starts_at:, hours: 1)
    new(user: user, starts_at: starts_at, hours: hours).call
  end

  def initialize(user:, starts_at:, hours:)
    @user = user
    @starts_at = starts_at.in_time_zone
    @hours = hours
    @ends_at = @starts_at + hours.hours
  end

  def call
    raise Error, "Book at least 24 hours in advance" if @starts_at < MeetingRoomAvailability.earliest_hourly_at
    raise Error, "Meeting room is not available on weekends" unless MeetingRoomAvailability.weekday?(@starts_at.to_date)
    raise Error, "Booking must be within opening hours (8:00–20:00)" unless within_opening_hours?

    @hours.times do |index|
      slot_start = @starts_at + index.hours
      slot_end = slot_start + 1.hour
      raise Error, "Meeting room is not available at this time" unless MeetingRoomAvailability.hourly_available?(slot_start, slot_end)
    end

    credit_pack = @user.credit_packs.meeting_hour_credits.select(&:usable?).first
    raise Error, "No meeting room hours available" unless credit_pack
    raise Error, "Not enough meeting room hours" if credit_pack.remaining_credits < @hours

    booking = nil

    ActiveRecord::Base.transaction do
      credit_pack.use_credit!(@hours)
      booking = Booking.create!(
        user: @user,
        seat: Seat.meeting_room,
        booking_type: "meeting_hourly",
        starts_at: @starts_at,
        ends_at: @ends_at,
        credit_pack: credit_pack
      )
    end

    booking
  end

  private

  def within_opening_hours?
    @starts_at.hour >= MeetingRoomAvailability::OPEN_HOUR &&
      @ends_at.hour <= MeetingRoomAvailability::CLOSE_HOUR
  end
end
