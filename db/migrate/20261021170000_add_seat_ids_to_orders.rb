class AddSeatIdsToOrders < ActiveRecord::Migration[8.1]
  def up
    add_column :orders, :seat_ids, :bigint, array: true, null: false, default: []

    execute <<~SQL.squish
      UPDATE orders
      SET seat_ids = ARRAY[seat_id]
      WHERE seat_id IS NOT NULL
    SQL
  end

  def down
    remove_column :orders, :seat_ids
  end
end
