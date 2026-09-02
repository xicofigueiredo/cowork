class BookingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_booking, only: [ :edit, :update ]
  before_action :ensure_editable, only: [ :edit, :update ]

  def index
    @bookings = current_user.bookings.includes(:seat).upcoming.order(:date, :starts_on, :starts_at)
    @past_bookings = current_user.bookings.includes(:seat)
      .where(
        "(booking_type = 'daily' AND date < ?) OR " \
        "(booking_type = 'monthly' AND ends_on < ?) OR " \
        "(booking_type = 'meeting_daily' AND date < ?) OR " \
        "(booking_type = 'meeting_hourly' AND ends_at < ?)",
        Date.current, Date.current, Date.current, Time.current
      )
      .order(date: :desc, starts_on: :desc, starts_at: :desc)
      .limit(10)
    @day_credit_packs = current_user.credit_packs.day_credits.order(expires_at: :desc)
    @meeting_credit_packs = current_user.credit_packs.meeting_hour_credits.order(expires_at: :desc)
    @available_credits = current_user.available_credits
    @available_meeting_hours = current_user.available_meeting_hours
  end

  def new
    unless current_user.available_credits.positive?
      redirect_to pricing_path, alert: "You need day credits to book. Purchase a pack first."
      return
    end

    @booking_date = parsed_booking_date
    if @booking_date < Date.current
      redirect_to new_booking_path, alert: "You can't book a date in the past."
      return
    end
    @seats = Seat.desks.ordered
    @unavailable_desks = SeatAvailability.unavailable_desk_codes(@booking_date)
    @available_credits = current_user.available_credits
  rescue ArgumentError
    redirect_to new_booking_path, alert: "Invalid date."
  end

  def create
    seat = Seat.find(params[:seat_id])
    date = Date.parse(params[:date])

    booking = CreditBooking.call(user: current_user, seat: seat, date: date)
    redirect_to bookings_path, notice: "Desk #{seat.code} booked for #{date.strftime('%-d %B %Y')}."
  rescue CreditBooking::Error, ActiveRecord::RecordInvalid => e
    redirect_to new_booking_path(date: params[:date]), alert: e.message
  rescue ArgumentError
    redirect_to new_booking_path, alert: "Invalid date."
  end

  def edit
    load_edit_form_data || return
  rescue ArgumentError
    redirect_to edit_booking_path(@booking), alert: "Invalid date."
  end

  def update
    if @booking.update(booking_params)
      redirect_to bookings_path, notice: update_notice
    else
      load_edit_form_data(validate_date: false)
      render :edit, status: :unprocessable_entity
    end
  rescue ArgumentError
    redirect_to edit_booking_path(@booking), alert: "Invalid date or time."
  end

  private

  def load_edit_form_data(validate_date: true)
    if @booking.meeting_hourly?
      load_meeting_hourly_edit_data(validate_date: validate_date)
    elsif @booking.meeting_daily?
      load_meeting_daily_edit_data(validate_date: validate_date)
    elsif @booking.daily?
      load_daily_edit_data(validate_date: validate_date)
    else
      load_monthly_edit_data
    end
  end

  def load_daily_edit_data(validate_date: true)
    @seats = Seat.desks.ordered
    @booking_date = params[:date].present? ? parsed_edit_date : @booking.date
    if validate_date && @booking_date < Date.current
      redirect_to edit_booking_path(@booking), alert: "You can't book a date in the past."
      return false
    end

    @unavailable_desks = SeatAvailability.unavailable_desk_codes(@booking_date, except_booking: @booking)
    true
  end

  def load_monthly_edit_data
    @seats = Seat.desks.ordered
    @unavailable_desks = SeatAvailability.unavailable_desk_codes_for_monthly(
      @booking.starts_on,
      @booking.ends_on,
      except_booking: @booking,
      from_date: Date.current
    )
    true
  end

  def load_meeting_hourly_edit_data(validate_date: true)
    @booking_date = if params[:date].present?
      MeetingRoomAvailability.ensure_weekday(Date.parse(params[:date]))
    else
      MeetingRoomAvailability.ensure_weekday(@booking.starts_at.to_date)
    end
    if validate_date && @booking_date < Date.current
      redirect_to edit_booking_path(@booking), alert: "You can't book a date in the past."
      return false
    end

    calendar = MeetingRoomAvailability.load_calendar(
      MeetingRoomAvailability.earliest_hourly_date,
      type: :hourly,
      except_booking: @booking
    )
    @calendar_days = calendar[:days]
    @schedule = calendar[:schedule]
    @hour_grid = @schedule.hour_grid(@booking_date, include_max_duration: false)
    true
  end

  def load_meeting_daily_edit_data(validate_date: true)
    @calendar_start = MeetingRoomAvailability.earliest_daily_date
    calendar = MeetingRoomAvailability.load_calendar(@calendar_start, type: :daily, except_booking: @booking)
    @calendar_days = calendar[:days]
    @booking_date = if params[:date].present?
      MeetingRoomAvailability.ensure_weekday(Date.parse(params[:date]))
    else
      MeetingRoomAvailability.ensure_weekday(@booking.date)
    end
    if validate_date && @booking_date < Date.current
      redirect_to edit_booking_path(@booking), alert: "You can't book a date in the past."
      return false
    end

    true
  end

  def update_notice
    if @booking.daily?
      "Booking updated: #{@booking.seat.label} on #{@booking.date.strftime('%-d %B %Y')}."
    elsif @booking.meeting_hourly?
      "Meeting room updated: #{@booking.starts_at.strftime('%-d %B %Y, %H:%M')}."
    elsif @booking.meeting_daily?
      "Meeting room updated: #{@booking.date.strftime('%-d %B %Y')} (full day)."
    else
      "Booking updated: #{@booking.seat.label} for #{@booking.period_label}."
    end
  end

  def parsed_edit_date
    return @booking.date if params[:date].blank?

    Date.parse(params[:date])
  end

  def set_booking
    @booking = current_user.bookings.find(params[:id])
  end

  def ensure_editable
    return if @booking.editable?

    redirect_to bookings_path, alert: "This booking can't be changed."
  end

  def booking_params
    if @booking.daily?
      {
        date: Date.parse(params.require(:date)),
        seat_id: params.require(:seat_id)
      }
    elsif @booking.monthly?
      { seat_id: params.require(:seat_id) }
    elsif @booking.meeting_hourly?
      starts_at = Time.zone.parse(params.require(:starts_at))
      { starts_at: starts_at, ends_at: starts_at + 1.hour }
    elsif @booking.meeting_daily?
      { date: Date.parse(params.require(:date)) }
    end
  end

  def parsed_booking_date
    return Date.current if params[:date].blank?

    Date.parse(params[:date])
  end
end
