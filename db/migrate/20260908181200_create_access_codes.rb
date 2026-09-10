class CreateAccessCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :access_codes do |t|
      t.references :booking, null: true, foreign_key: true, index: false
      t.references :user, null: true, foreign_key: true
      t.string :code, null: false
      t.string :ttlock_keyboard_pwd_id
      t.string :name, null: false
      t.datetime :valid_from, null: false
      t.datetime :valid_to, null: false
      t.string :source, null: false, default: "booking"
      t.string :status, null: false, default: "active"

      t.timestamps
    end

    add_index :access_codes, :booking_id,
              unique: true,
              where: "booking_id IS NOT NULL AND status = 'active'",
              name: "index_access_codes_on_active_booking_id"
    add_index :access_codes, :status
    add_index :access_codes, :source
  end
end
