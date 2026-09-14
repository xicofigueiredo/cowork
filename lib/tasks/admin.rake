# frozen_string_literal: true

namespace :admin do
  desc "Grant free monthly plans to ADMIN_EMAILS (no Stripe, TOConline, or emails). Safe to re-run."
  task grant_monthly: :environment do
    emails = ENV.fetch("ADMIN_EMAILS", "").split(",").map { |e| e.strip.downcase }.reject(&:blank?)
    abort "ADMIN_EMAILS is empty" if emails.empty?

    hours = Order.plan_config("monthly")[:meeting_hours]
    found = User.where("LOWER(email) IN (?)", emails).index_by { |u| u.email.downcase }

    emails.each do |email|
      user = found[email]
      unless user
        puts "SKIP #{email}: no user account"
        next
      end

      if user.bookings.monthly.where("ends_on >= ?", Date.current).exists?
        period = user.next_monthly_period
        puts "SKIP #{email}: already has active monthly (next would start #{period[:starts_on]})"
        next
      end

      period = user.next_monthly_period
      seat = Seat.desks.ordered.find { |s|
        SeatAvailability.available_for_monthly?(s, period[:starts_on], period[:ends_on])
      }

      unless seat
        puts "SKIP #{email}: no desk available for #{period[:starts_on]}–#{period[:ends_on]}"
        next
      end

      ActiveRecord::Base.transaction do
        order = user.orders.new(
          plan_type: "monthly",
          amount_cents: 0,
          status: "paid",
          paid_at: Time.current,
          seat: seat
        )
        order.save!(validate: false)

        booking = Booking.create!(
          user: user,
          seat: seat,
          booking_type: "monthly",
          starts_on: period[:starts_on],
          ends_on: period[:ends_on],
          order: order
        )

        CreditPack.create!(
          user: user,
          order: order,
          credit_type: "meeting_hour",
          total_credits: hours,
          remaining_credits: hours,
          expires_at: booking.ends_on.end_of_day
        )

        puts "OK #{email} → #{seat.label} #{period[:starts_on]}–#{period[:ends_on]} (order ##{order.id})"
      end
    end
  end
end
