class HardenBookingConcurrency < ActiveRecord::Migration[8.1]
  def change
    enable_extension "btree_gist"

    remove_index :bookings, name: "index_bookings_on_order_id"
    add_index :bookings, :order_id,
      unique: true,
      where: "order_id IS NOT NULL",
      name: "index_bookings_on_order_id"

    remove_index :credit_packs, :order_id
    add_index :credit_packs, :order_id, unique: true

    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE bookings
          ADD CONSTRAINT bookings_monthly_seat_no_overlap
          EXCLUDE USING gist (
            seat_id WITH =,
            daterange(starts_on, ends_on, '[]') WITH &&
          )
          WHERE (booking_type = 'monthly' AND starts_on IS NOT NULL AND ends_on IS NOT NULL)
        SQL
      end

      dir.down do
        execute <<~SQL
          ALTER TABLE bookings
          DROP CONSTRAINT IF EXISTS bookings_monthly_seat_no_overlap
        SQL
      end
    end
  end
end
