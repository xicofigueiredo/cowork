module Admin
  class LeadsController < BaseController
    REFERRAL_CHART_COLORS = {
      "google_search" => "var(--landing-accent)",
      "social_media" => "var(--landing-soft)",
      "coworking_marketplaces" => "var(--landing-green)",
      "a_friend" => "var(--landing-dark)",
      "other" => "color-mix(in srgb, var(--landing-dark) 45%, white)"
    }.freeze

    def index
      @leads = Lead.order(created_at: :desc)
      @referral_breakdown = referral_breakdown
    end

    private

    def referral_breakdown
      counts = User.where(referral_source: User::REFERRAL_SOURCES.keys).group(:referral_source).count
      total = counts.values.sum
      return [] if total.zero?

      User::REFERRAL_SOURCES.filter_map do |key, label|
        count = counts[key] || 0
        next if count.zero?

        {
          key: key,
          label: label,
          count: count,
          percent: ((count.to_f / total) * 100).round(1),
          color: REFERRAL_CHART_COLORS.fetch(key)
        }
      end
    end
  end
end
