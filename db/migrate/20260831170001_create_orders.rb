class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.string :plan_type, null: false
      t.integer :amount_cents, null: false
      t.string :status, null: false, default: "pending"
      t.references :seat, foreign_key: true
      t.date :booking_date
      t.datetime :paid_at
      t.string :stripe_session_id

      t.timestamps
    end
  end
end
