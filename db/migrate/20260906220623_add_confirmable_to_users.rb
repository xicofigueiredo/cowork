class AddConfirmableToUsers < ActiveRecord::Migration[8.1]
  def up
    change_table :users, bulk: true do |t|
      t.string   :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string   :unconfirmed_email
    end

    add_index :users, :confirmation_token, unique: true

    # Existing accounts stay usable without re-confirming.
    execute "UPDATE users SET confirmed_at = COALESCE(confirmed_at, created_at)"
  end

  def down
    remove_index :users, :confirmation_token
    remove_columns :users, :confirmation_token, :confirmed_at, :confirmation_sent_at, :unconfirmed_email
  end
end
