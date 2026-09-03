class OurSpaceController < ApplicationController
  def index
    @unavailable_desks = SeatAvailability.unavailable_desk_codes(Date.current)
    @carousel_images = (1..9).map { |index| "fotos/imagem#{index}.jpeg" }
  end
end
