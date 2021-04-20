class AddIpUsedtoSignupToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :sign_up_ip, :string
  end
end
