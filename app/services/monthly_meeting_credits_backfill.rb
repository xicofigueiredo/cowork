class MonthlyMeetingCreditsBackfill
  def self.call
    new.call
  end

  def call
    Order.paid.where(plan_type: "monthly").includes(:booking).find_each do |order|
      next unless order.booking
      next if CreditPack.meeting_hour_credits.exists?(order: order)

      config = Order.plan_config("monthly")
      CreditPack.create!(
        user: order.user,
        order: order,
        credit_type: "meeting_hour",
        total_credits: config[:meeting_hours],
        remaining_credits: config[:meeting_hours],
        expires_at: order.booking.ends_on.end_of_day
      )
    end
  end
end
