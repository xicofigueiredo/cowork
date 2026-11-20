class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string :title
      t.text :description
      t.string :url
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :events, [ :position, :created_at ]
  end
end
