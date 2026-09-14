# frozen_string_literal: true

namespace :admin do
  CREDITS = 100
  EXPIRES_IN = 1.year

  desc "Replace free admin monthly seats with #{CREDITS} day credits (no Stripe/TOC/emails). Safe to re-run."
  task grant_credits: :environment do
    emails = ENV.fetch("ADMIN_EMAILS", "").split(",").map { |e| e.strip.downcase }.reject(&:blank?)
    abort "ADMIN_EMAILS is empty" if emails.empty?

    found = User.where("LOWER(email) IN (?)", emails).index_by { |u| u.email.downcase }

    emails.each do |email|
      user = found[email]
      unless user
        puts "SKIP #{email}: no user account"
        next
      end

      ActiveRecord::Base.transaction do
        user.orders.where(plan_type: "monthly", amount_cents: 0).find_each do |order|
          puts "REMOVE monthly order ##{order.id} #{email} seat=#{order.seat&.label}"
          order.destroy!
        end

        existing = user.orders
          .where(amount_cents: 0)
          .joins(:credit_pack)
          .where(credit_packs: { credit_type: "day" })
          .first

        if existing
          pack = existing.credit_pack
          puts "SKIP #{email}: already has free credits (order ##{existing.id}, #{pack.remaining_credits}/#{pack.total_credits} left)"
          next
        end

        order = user.orders.new(
          plan_type: "pack_10",
          amount_cents: 0,
          status: "paid",
          paid_at: Time.current
        )
        order.save!(validate: false)

        CreditPack.create!(
          user: user,
          order: order,
          credit_type: "day",
          total_credits: CREDITS,
          remaining_credits: CREDITS,
          expires_at: EXPIRES_IN.from_now
        )

        puts "OK #{email} → #{CREDITS} day credits (order ##{order.id})"
      end
    end
  end
end
