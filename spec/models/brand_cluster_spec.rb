require "rails_helper"

describe BrandCluster do
  include SlowMarkdownHelpers

  describe "description" do
    let(:record) { create(:brand_cluster) }

    it "accepts 5,000 characters" do
      expect(record.update(description: "x" * 5_000)).to be(true)
    end

    it "rejects more than 5,000 characters" do
      expect(record.update(description: "x" * 5_001)).to be(false)
      expect(record.errors[:description]).to eq(["is too long (maximum is 5000 characters)"])
    end

    it "rejects a changed description with brackets nested more than five deep" do
      expect(record.update(description: "[[[[[[x]]]]]]")).to be(false)
      expect(record.errors[:description]).to eq(["has too many nested brackets"])
    end

    it "rejects a changed description that takes too long to render" do
      make_markdown_slow

      expect(record.update(description: SlowMarkdownHelpers::SLOW_MARKDOWN)).to be(false)
      expect(record.errors[:description]).to eq(["is too complex to display"])
    end

    it "keeps a record with an existing over-long description saveable" do
      record.update_column(:description, "x" * 5_001)

      expect(record.reload.update(name: "Renamed Brand")).to be(true)
      expect(record.update(description: "y" * 5_001)).to be(false)
      expect(record.errors[:description]).to eq(["is too long (maximum is 5000 characters)"])
    end

    it "keeps a record with an existing deeply nested description saveable" do
      record.update_column(:description, "[[[[[[x]]]]]]")

      expect(record.reload.update(updated_at: 1.minute.from_now)).to be(true)
    end
  end

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

  describe ".public" do
    def add_inks(brand_cluster, count, private: false)
      macro_cluster = create(:macro_cluster, brand_cluster: brand_cluster)
      micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
      create_list(:collected_ink, count, micro_cluster: micro_cluster, private: private)
    end

    it "returns brands with public collected inks" do
      public_brand = create(:brand_cluster)
      add_inks(public_brand, 1)
      add_inks(public_brand, 1, private: true)
      private_brand = create(:brand_cluster)
      add_inks(private_brand, 2, private: true)
      create(:brand_cluster)
      MacroClusterPopularity.refresh

      expect(described_class.public).to contain_exactly(public_brand)
    end

    it "only includes new public inks after the popularities are refreshed" do
      brand_cluster = create(:brand_cluster)
      MacroClusterPopularity.refresh
      add_inks(brand_cluster, 1)

      expect(described_class.public).to be_empty

      MacroClusterPopularity.refresh

      expect(described_class.public).to contain_exactly(brand_cluster)
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
