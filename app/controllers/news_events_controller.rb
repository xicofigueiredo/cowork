class NewsEventsController < ApplicationController
  def index
    @events = Event.with_attached_photo
  end
end
