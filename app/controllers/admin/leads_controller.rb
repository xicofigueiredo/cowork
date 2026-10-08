module Admin
  class LeadsController < BaseController
    REFERRAL_CHART_COLORS = {
      "google_search" => "var(--landing-accent)",
      "social_media" => "var(--landing-soft)",
      "coworking_marketplaces" => "var(--landing-green)",
      "a_friend" => "var(--landing-dark)",
      "other" => "color-mix(in srgb, var(--landing-dark) 45%, white)",
      "unknown" => "color-mix(in srgb, var(--landing-dark) 18%, white)"
    }.freeze

    def index
      @leads = Lead.order(created_at: :desc)
      @referral_breakdown = referral_breakdown
    end

    private

    def referral_breakdown
      counts = User.group(:referral_source).count
      total = counts.values.sum
      return [] if total.zero?

      slices = User::REFERRAL_SOURCES.filter_map do |key, label|
        count = counts.delete(key) || 0
        next if count.zero?

        {
          key: key,
          label: label,
          count: count,
          percent: ((count.to_f / total) * 100).round(1),
          color: REFERRAL_CHART_COLORS.fetch(key)
        }
      end

      unknown_count = counts.values.sum
      if unknown_count.positive?
        slices << {
          key: "unknown",
          label: "Not specified",
          count: unknown_count,
          percent: ((unknown_count.to_f / total) * 100).round(1),
          color: REFERRAL_CHART_COLORS.fetch("unknown")
        }
      end

      slices
    end
  end
end
