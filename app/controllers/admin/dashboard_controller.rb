module Admin
  class DashboardController < BaseController
    def index
      @floor_plan_date = floor_plan_date
      @desk_occupancy = SeatAvailability.desk_occupancy_for(@floor_plan_date)
      @desk_count = Seat.desks.count
      @users = User.includes(:credit_packs, :access_code, :access_codes, :orders, bookings: :order).order(created_at: :desc)
      @ttlock_configured = TtLock::Client.configured?
    end

    private

    def floor_plan_date
      return Date.current if params[:date].blank?

      Date.parse(params[:date])
    rescue Date::Error, ArgumentError
      Date.current
    end
  end
end
