class CreatePromocodesAndAddToOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :promocodes do |t|
      t.string :code, null: false
      t.integer :amount_cents, null: false
      t.integer :credits, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :promocodes, :code, unique: true

    add_reference :orders, :promocode, foreign_key: true
  end
end
