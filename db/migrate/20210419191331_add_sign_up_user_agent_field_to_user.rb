class AddSignUpUserAgentFieldToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :sign_up_user_agent, :text
  end
end
