require "rails_helper"

describe Pens::Model do
  describe "associations" do
    it "has a properly set up model_micro_clusters association" do
      model = create(:pens_model)
      mmc1 = create(:pens_model_micro_cluster, model:)
      mmc2 = create(:pens_model_micro_cluster, model:)

      expect(model.model_micro_clusters).to match_array([mmc1, mmc2])
    end
  end
end
