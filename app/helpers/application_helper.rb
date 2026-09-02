module ApplicationHelper
  def meeting_calendar_day_path(date, plan_type: nil, booking: nil)
    if booking
      edit_booking_path(booking, date: date)
    elsif plan_type.present?
      new_checkout_path(plan: plan_type, date: date)
    else
      new_meeting_booking_path(date: date)
    end
  end
end
