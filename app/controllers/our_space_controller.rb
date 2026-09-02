class OurSpaceController < ApplicationController
  def index
    @unavailable_desks = SeatAvailability.unavailable_desk_codes(Date.current)
  end
end
