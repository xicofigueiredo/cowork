module CheckoutsHelper
  def checkout_plan_description(plan_type)
    case plan_type
    when "daily"
      "Choose a weekday and desk for your day pass."
    when "monthly", "monthly_3"
      months = Order.plan_config(plan_type)[:months] || 1
      meeting_hours = Order.plan_config(plan_type)[:meeting_hours]
      period_label = months == 1 ? "the next month" : "the next #{months} months"
      hours_label = "#{meeting_hours} #{"hour".pluralize(meeting_hours)} of meeting room access"
      if current_user.next_monthly_starts_on > Date.current
        "Choose your dedicated desk. Your plan starts #{current_user.next_monthly_starts_on.strftime('%-d %B %Y')} after your current one ends. Includes #{hours_label}."
      else
        "Choose your dedicated desk for #{period_label}. Includes #{hours_label}."
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
