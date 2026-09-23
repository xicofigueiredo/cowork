# frozen_string_literal: true

class ToconlineConnectionCheckJob < ApplicationJob
  queue_as :default

  def perform
    result = Toconline::ConnectionMonitor.call
    OrderMailer.toconline_health(result).deliver_now
    result
  end
end
