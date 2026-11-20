class Event < ApplicationRecord
  has_one_attached :photo

  normalizes :title, with: ->(value) { value.strip.presence }
  normalizes :description, with: ->(value) { value.strip.presence }
  normalizes :url, with: ->(value) { value.strip.presence }

  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :url, format: { with: /\Ahttps?:\/\/.+\z/i }, allow_nil: true

  before_validation :assign_default_position, on: :create

  default_scope { order(:position, :created_at) }

  def display_title
    title.presence || "Untitled event"
  end

  def display_date
    return if event_date.blank?

    I18n.l(event_date, format: :long)
  end

  def self.next_position
    (unscoped.maximum(:position) || -1) + 1
  end

  private

  def assign_default_position
    self.position = self.class.next_position if position.nil?
  end
end
