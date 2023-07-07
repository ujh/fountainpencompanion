class MakeMeAnAdmin < ActiveRecord::Migration[7.0]
  def change
    User.where(email: "urban@bettong.net").update_all(admin: true)
  end
end
