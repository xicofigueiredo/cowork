class CreateLeads < ActiveRecord::Migration[8.1]
  def change
    create_table :leads do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.text :message
      t.boolean :privacy_accepted, null: false, default: false

      t.timestamps
    end
  end
end
