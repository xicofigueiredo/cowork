class LocationController < ApplicationController
  def index
    @lead = Lead.new
  end

  def create
    @lead = Lead.new(lead_params)

    if @lead.save
      redirect_to location_path, notice: "Thanks, we'll get back to you soon."
    else
      flash.now[:alert] = "Please fill in the required fields."
      render :index, status: :unprocessable_entity
    end
  end

  private

  def lead_params
    params.require(:lead).permit(:first_name, :last_name, :email, :message, :privacy_accepted)
  end
end
