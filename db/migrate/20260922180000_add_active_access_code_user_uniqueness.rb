class AddActiveAccessCodeUserUniqueness < ActiveRecord::Migration[8.1]
  def up
    # Keep one active code per user (prefer lock-synced, then newest).
    say_with_time "Deduplicating active access codes per user" do
      execute <<~SQL.squish
        UPDATE access_codes
        SET status = 'revoked', updated_at = NOW()
        WHERE id IN (
          SELECT id FROM (
            SELECT
              id,
              ROW_NUMBER() OVER (
                PARTITION BY user_id
                ORDER BY
                  CASE WHEN ttlock_keyboard_pwd_id IS NOT NULL AND ttlock_keyboard_pwd_id <> '' THEN 0 ELSE 1 END,
                  created_at DESC,
                  id DESC
              ) AS row_num
            FROM access_codes
            WHERE user_id IS NOT NULL
              AND status = 'active'
          ) ranked
          WHERE row_num > 1
        )
      SQL
    end

    add_index :access_codes, :user_id,
              unique: true,
              where: "user_id IS NOT NULL AND status = 'active'",
              name: "index_access_codes_on_active_user_id"
  end

  def down
    remove_index :access_codes, name: "index_access_codes_on_active_user_id"
  end
end
