class NotNullConstraintForClusterColor < ActiveRecord::Migration[6.0]
  def change
    safety_assured do
      execute 'ALTER TABLE "collected_inks" ADD CONSTRAINT "collected_inks_cluster_color_null" CHECK ("cluster_color" IS NOT NULL) NOT VALID'
    end
  end
end
