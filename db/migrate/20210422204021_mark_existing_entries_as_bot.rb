class MarkExistingEntriesAsBot < ActiveRecord::Migration[6.1]
  def up
    User
      .where.not(sign_up_ip: nil)
      .find_each do |user|
        user.sign_up_ip = user.sign_up_ip
        user.save!
      end
  end
end
