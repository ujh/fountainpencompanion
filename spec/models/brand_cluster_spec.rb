require "rails_helper"

describe BrandCluster do
  describe "#update_name!" do
    it "uses the most popular name as the new name" do
      mc1 = create(:macro_cluster, brand_name: "Pelikan")
      mc2 = create(:macro_cluster, brand_name: "Pelikan")
      mc3 = create(:macro_cluster, brand_name: "Pelikan Edelstein")
      subject.save!
      mc1.update!(brand_cluster: subject)
      mc2.update!(brand_cluster: subject)
      mc3.update!(brand_cluster: subject)
      subject.update_name!
      expect(subject.name).to eq("Pelikan")
    end
  end
end
