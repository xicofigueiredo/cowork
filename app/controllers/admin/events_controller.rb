module Admin
  class EventsController < BaseController
    before_action :set_event, only: [ :edit, :update, :destroy ]

    def index
      @events = Event.with_attached_photo
    end

    def new
      @event = Event.new(position: Event.next_position)
    end

    def create
      @event = Event.new(event_params)
      if params.dig(:event, :position).to_s.strip == ""
        @event.position = Event.next_position
      end

      if @event.save
        redirect_to admin_events_path, notice: "Event created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @event.update(event_params)
        redirect_to admin_events_path, notice: "Event updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @event.destroy!
      redirect_to admin_events_path, notice: "Event deleted."
    end

    private

    def set_event
      @event = Event.find(params[:id])
    end

    def event_params
      params.require(:event).permit(:title, :description, :url, :event_date, :position, :photo)
    end
  end
end
