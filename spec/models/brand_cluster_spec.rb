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

  describe ".autocomplete_search" do
    def add_inks(brand_cluster, count, private: false)
      macro_cluster = create(:macro_cluster, brand_cluster: brand_cluster)
      micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
      create_list(:collected_ink, count, micro_cluster: micro_cluster, private: private)
    end

    it "ranks brands by match quality and then by number of public inks" do
      anderson = create(:brand_cluster, name: "Anderson Pens")
      pelikan = create(:brand_cluster, name: "Pelikan")
      pebeo = create(:brand_cluster, name: "Pebeo")
      add_inks(anderson, 5)
      add_inks(pelikan, 3)
      add_inks(pebeo, 1)
      add_inks(pebeo, 5, private: true)
      MacroClusterPopularity.refresh

      expect(described_class.autocomplete_search("pe").map(&:name)).to eq(
        ["Pelikan", "Pebeo", "Anderson Pens"]
      )
    end

    it "includes brands without public inks" do
      create(:brand_cluster, name: "Pelikan")
      MacroClusterPopularity.refresh

      expect(described_class.autocomplete_search("pel").map(&:name)).to eq(["Pelikan"])
    end

    it "finds brands with typos" do
      create(:brand_cluster, name: "Pelikan")
      create(:brand_cluster, name: "Diamine")
      MacroClusterPopularity.refresh

      expect(described_class.autocomplete_search("pelican").map(&:name)).to eq(["Pelikan"])
    end
  end
end
