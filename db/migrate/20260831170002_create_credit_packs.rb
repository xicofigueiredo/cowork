class CreateCreditPacks < ActiveRecord::Migration[8.1]
  def change
    create_table :credit_packs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true
      t.integer :total_credits, null: false
      t.integer :remaining_credits, null: false
      t.datetime :expires_at, null: false

      t.timestamps
    end
  end
end
