class CreateBookings < ActiveRecord::Migration[8.1]
  def change
    create_table :bookings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :seat, null: false, foreign_key: true
      t.string :booking_type, null: false
      t.date :date
      t.date :starts_on
      t.date :ends_on
      t.references :order, foreign_key: true
      t.references :credit_pack, foreign_key: true

      t.timestamps
    end

    add_index :bookings, [ :seat_id, :date ], unique: true, where: "booking_type = 'daily'"
  end
end
