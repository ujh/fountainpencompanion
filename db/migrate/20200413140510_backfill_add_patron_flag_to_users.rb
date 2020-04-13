class BackfillAddPatronFlagToUsers < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    User.unscoped.in_batches do |relation|
      relation.update_all patron: false
      sleep(0.01)
    end
  end
end
