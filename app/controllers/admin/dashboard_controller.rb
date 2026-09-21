module Admin
  class DashboardController < BaseController
    def index
      @floor_plan_date = floor_plan_date
      @desk_occupancy = SeatAvailability.desk_occupancy_for(@floor_plan_date)
      @desk_count = Seat.desks.count
      @leads = Lead.order(created_at: :desc)
      @users = User.includes(:credit_packs, bookings: :order).order(created_at: :desc)
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
