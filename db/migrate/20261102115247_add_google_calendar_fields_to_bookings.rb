class AddGoogleCalendarFieldsToBookings < ActiveRecord::Migration[8.1]
  def change
    add_column :bookings, :google_event_id, :string
    add_column :bookings, :source, :string, null: false, default: "app"
    add_index :bookings, :google_event_id, unique: true, where: "google_event_id IS NOT NULL"
  end
end
