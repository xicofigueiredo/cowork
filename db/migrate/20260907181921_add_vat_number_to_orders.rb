class AddVatNumberToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :vat_number, :string
  end
end
