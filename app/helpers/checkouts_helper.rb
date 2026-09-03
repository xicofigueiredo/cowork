module CheckoutsHelper
  def checkout_plan_description(plan_type)
    case plan_type
    when "daily"
      "Choose a weekday and desk for your day pass."
    when "monthly"
      if current_user.next_monthly_starts_on > Date.current
        "Choose your dedicated desk. Your plan starts #{current_user.next_monthly_starts_on.strftime('%-d %B %Y')} after your current one ends. Includes 5 hours of meeting room access."
      else
        "Choose your dedicated desk for the next month. Includes 5 hours of meeting room access."
      end
    when "pack_5"
      "Purchase 5 day credits, valid for 3 months."
    when "pack_10"
      "Purchase 10 day credits, valid for 3 months."
    when "meeting_hourly"
      "Book the meeting room for 1 hour on a weekday. Must be booked at least 24 hours in advance."
    when "meeting_daily"
      "Book the meeting room for a full weekday (8:00–20:00). Must be booked at least 24 hours in advance."
    else
      ""
    end
  end
end
