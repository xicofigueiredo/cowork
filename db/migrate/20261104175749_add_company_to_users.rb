class AddCompanyToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :company, :boolean, default: false, null: false
  end
end
