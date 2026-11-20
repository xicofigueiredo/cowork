class AddVirtualOfficeFieldsToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :company_name, :string
    add_column :orders, :partners_names, :text
    add_column :orders, :contact_email, :string
    add_column :orders, :national_id, :string
    add_column :orders, :terms_accepted, :boolean, default: false, null: false
  end
end
