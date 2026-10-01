class AddReferralSourceOtherToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :referral_source_other, :string
  end
end
