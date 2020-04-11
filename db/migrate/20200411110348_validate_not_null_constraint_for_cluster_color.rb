class ValidateNotNullConstraintForClusterColor < ActiveRecord::Migration[6.0]
  def change
    safety_assured do
      execute 'ALTER TABLE "collected_inks" VALIDATE CONSTRAINT "collected_inks_cluster_color_null"'
    end
  end
end
