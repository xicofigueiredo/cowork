module Admin
  class DashboardController < BaseController
    def index
      @leads = Lead.order(created_at: :desc)
      @bookings = Booking.includes(:user, :seat, :order, :access_code, :credit_pack)
                        .order(created_at: :desc)
    end
  end
end
