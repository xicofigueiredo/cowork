class ReplaceVirtualPartnerFieldsWithPartnersJson < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :partners, :jsonb, default: [], null: false

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE orders
          SET partners = CASE
            WHEN COALESCE(partners_names, '') <> '' OR COALESCE(national_id, '') <> ''
            THEN jsonb_build_array(
              jsonb_build_object(
                'name', COALESCE(partners_names, ''),
                'national_id', COALESCE(national_id, '')
              )
            )
            ELSE '[]'::jsonb
          END
        SQL
      end
    end

    remove_column :orders, :partners_names, :text
    remove_column :orders, :national_id, :string
  end
end
