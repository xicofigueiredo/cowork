class Seat < ApplicationRecord
  KINDS = %w[desk meeting_room].freeze
  FLOORS = %w[main mezzanine meeting].freeze

  has_many :bookings, dependent: :restrict_with_error
  has_many :orders, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: true
  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :floor, presence: true, inclusion: { in: FLOORS }

  scope :desks, -> { where(kind: "desk") }
  scope :ordered, -> { order(:code) }

  def self.meeting_room
    find_by!(kind: "meeting_room")
  end

  def label
    meeting_room? ? "Meeting room" : "Desk #{code}"
  end

  def meeting_room?
    kind == "meeting_room"
  end

  def desk?
    kind == "desk"
  end
end
