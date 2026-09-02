class CreditBooking
  class Error < StandardError; end

  def self.call(user:, seat:, date:)
    new(user: user, seat: seat, date: date).call
  end

  def initialize(user:, seat:, date:)
    @user = user
    @seat = seat
    @date = date
  end

  def call
    raise Error, "Date cannot be in the past" if @date < Date.current
    raise Error, "Seat is not available on this date" unless SeatAvailability.available_on?(@seat, @date)

    credit_pack = @user.credit_packs.day_credits.usable.first
    raise Error, "No credits available" unless credit_pack

    booking = nil

    ActiveRecord::Base.transaction do
      credit_pack.use_credit!
      booking = Booking.create!(
        user: @user,
        seat: @seat,
        booking_type: "daily",
        date: @date,
        credit_pack: credit_pack
      )
    end

    booking
  end
end
