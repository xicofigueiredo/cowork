class AddReferralSourceToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :referral_source, :string
  end
end
