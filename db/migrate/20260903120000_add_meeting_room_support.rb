class AddMeetingRoomSupport < ActiveRecord::Migration[8.1]
  def change
    add_column :seats, :kind, :string, null: false, default: "desk"
    add_column :credit_packs, :credit_type, :string, null: false, default: "day"
    add_column :bookings, :starts_at, :datetime
    add_column :bookings, :ends_at, :datetime
    add_column :orders, :starts_at, :datetime

    add_index :bookings, [ :seat_id, :date ], unique: true,
      where: "booking_type = 'meeting_daily'",
      name: "index_bookings_on_seat_and_meeting_daily_date"

    add_index :bookings, [ :seat_id, :starts_at ],
      unique: true,
      where: "booking_type = 'meeting_hourly'",
      name: "index_bookings_on_seat_and_meeting_hourly_starts_at"
  end
end
