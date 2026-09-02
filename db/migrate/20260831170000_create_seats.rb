class CreateSeats < ActiveRecord::Migration[8.1]
  def change
    create_table :seats do |t|
      t.string :code, null: false
      t.string :floor, null: false

      t.timestamps
    end

    add_index :seats, :code, unique: true
  end
end
