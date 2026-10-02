class AddHoursToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :hours, :integer
  end
end
