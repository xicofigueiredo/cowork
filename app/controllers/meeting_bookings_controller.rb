class MeetingBookingsController < ApplicationController
  before_action :authenticate_user!

  def new
    unless current_user.available_meeting_hours.positive?
      redirect_to pricing_path, alert: "You need meeting room hours to book. They are included with the monthly plan."
      return
    end

    @available_meeting_hours = current_user.available_meeting_hours
    @booking_date = parsed_booking_date
    calendar = MeetingRoomAvailability.load_calendar(MeetingRoomAvailability.earliest_hourly_date, type: :hourly)
    @calendar_days = calendar[:days]
    @schedule = calendar[:schedule]
    @hour_grid = @schedule.hour_grid(@booking_date, include_max_duration: false)
    @selected_slots = selected_slot_times
  rescue ArgumentError
    redirect_to new_meeting_booking_path, alert: "Invalid date."
  end

  def create
    slots = parse_slot_times
    raise MeetingCreditBooking::Error, "Select at least one time slot" if slots.empty?
    raise MeetingCreditBooking::Error, "Not enough meeting room hours" if slots.size > current_user.available_meeting_hours

    slots.each do |starts_at|
      unless MeetingRoomAvailability.hourly_available?(starts_at, starts_at + 1.hour)
        raise MeetingCreditBooking::Error, "#{starts_at.strftime('%H:%M')} is no longer available"
      end
    end

    bookings = ActiveRecord::Base.transaction do
      slots.map { |starts_at| MeetingCreditBooking.call(user: current_user, starts_at: starts_at, hours: 1) }
    end

    notice = if bookings.one?
      "Meeting room booked for #{bookings.first.starts_at.strftime('%-d %B %Y, %H:%M')}."
    else
      "Meeting room booked for #{bookings.size} slots on #{bookings.first.starts_at.strftime('%-d %B %Y')}."
    end

    redirect_to bookings_path, notice: notice
  rescue MeetingCreditBooking::Error, ActiveRecord::RecordInvalid => e
    redirect_to new_meeting_booking_path(date: params[:date], slots: Array(params[:starts_at])), alert: e.message
  rescue ArgumentError
    redirect_to new_meeting_booking_path, alert: "Invalid date or time."
  end

  private

  def parsed_booking_date
    return MeetingRoomAvailability.earliest_hourly_date if params[:date].blank?

    MeetingRoomAvailability.ensure_weekday(Date.parse(params[:date]))
  end

  def selected_slot_times
    Array(params[:slots]).filter_map do |value|
      Time.zone.parse(value)
    rescue ArgumentError
      nil
    end
  end

  def parse_slot_times
    Array(params[:starts_at]).filter_map do |value|
      Time.zone.parse(value)
    rescue ArgumentError
      nil
    end.uniq.sort
  end
end
