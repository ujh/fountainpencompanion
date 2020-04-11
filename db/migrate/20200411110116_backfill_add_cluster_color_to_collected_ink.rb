class BackfillAddClusterColorToCollectedInk < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    CollectedInk.unscoped.in_batches do |relation|
      relation.update_all cluster_color: ""
      sleep(0.01)
    end
  end
end
