class AllowMultipleBookingsPerOrder < ActiveRecord::Migration[8.1]
  def up
    remove_index :bookings, name: "index_bookings_on_order_id"
    add_index :bookings, :order_id,
      where: "order_id IS NOT NULL",
      name: "index_bookings_on_order_id"
  end

  def down
    remove_index :bookings, name: "index_bookings_on_order_id"
    add_index :bookings, :order_id,
      unique: true,
      where: "order_id IS NOT NULL",
      name: "index_bookings_on_order_id"
  end
end
