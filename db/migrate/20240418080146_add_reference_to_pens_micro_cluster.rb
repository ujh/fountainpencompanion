class AddReferenceToPensMicroCluster < ActiveRecord::Migration[7.1]
  def change
    safety_assured { add_reference :collected_pens, :pens_micro_cluster, foreign_key: true }
  end
end
