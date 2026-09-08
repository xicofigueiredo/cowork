class AddToconlineFieldsToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :toconline_document_id, :string
    add_column :orders, :toconline_document_number, :string
  end
end
