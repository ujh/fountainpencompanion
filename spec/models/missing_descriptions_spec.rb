require "rails_helper"

describe MissingDescriptions do
  def create_public_cluster(**attributes)
    macro_cluster = create(:macro_cluster, **attributes)
    micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
    create(:collected_ink, micro_cluster: micro_cluster)
    macro_cluster
  end

  describe ".sorted_brand_ids" do
    it "returns the brand clusters without a description sorted by name" do
      second = create(:brand_cluster, name: "B")
      first = create(:brand_cluster, name: "A")
      create(:brand_cluster, name: "C", description: "description")

      expect(described_class.sorted_brand_ids).to eq([first.id, second.id])
    end

    it "caches the ids" do
      brand_cluster = create(:brand_cluster)
      described_class.sorted_brand_ids
      create(:brand_cluster)

      expect(described_class.sorted_brand_ids).to eq([brand_cluster.id])
    end
  end

  describe ".sorted_ink_ids" do
    it "returns the public clusters without a description sorted by name" do
      second = create_public_cluster(brand_name: "B")
      first = create_public_cluster(brand_name: "A")
      create_public_cluster(brand_name: "C", description: "description")

      expect(described_class.sorted_ink_ids).to eq([first.id, second.id])
    end

    it "excludes clusters that only have private collected inks" do
      macro_cluster = create(:macro_cluster)
      micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
      create(:collected_ink, micro_cluster: micro_cluster, private: true)

      expect(described_class.sorted_ink_ids).to eq([])
    end

    it "caches the ids" do
      macro_cluster = create_public_cluster
      described_class.sorted_ink_ids
      create_public_cluster

      expect(described_class.sorted_ink_ids).to eq([macro_cluster.id])
    end
  end

  describe "brand expiry" do
    let!(:brand_cluster) { create(:brand_cluster) }

    before { described_class.sorted_brand_ids }

    it "expires the cache when a brand gets a description" do
      brand_cluster.update!(description: "description")

      expect(described_class.sorted_brand_ids).to eq([])
    end

    it "expires the cache when a brand loses its description" do
      described_brand = create(:brand_cluster, description: "description")
      described_class.sorted_brand_ids

      described_brand.update!(description: "")

      expect(described_class.sorted_brand_ids).to contain_exactly(
        brand_cluster.id,
        described_brand.id
      )
    end

    it "expires the cache when a brand is destroyed" do
      brand_cluster.destroy!

      expect(described_class.sorted_brand_ids).to eq([])
    end

    it "keeps the cache when another attribute of a brand changes" do
      Rails.cache.write(MissingDescriptions::SORTED_BRAND_IDS_KEY, [42])

      brand_cluster.update!(name: "New name")

      expect(described_class.sorted_brand_ids).to eq([42])
    end
  end

  describe "ink expiry" do
    let!(:macro_cluster) { create_public_cluster }

    before { described_class.sorted_ink_ids }

    it "expires the cache when an ink gets a description" do
      macro_cluster.update!(description: "description")

      expect(described_class.sorted_ink_ids).to eq([])
    end

    it "expires the cache when an ink loses its description" do
      described_cluster = create_public_cluster(description: "description")
      described_class.sorted_ink_ids

      described_cluster.update!(description: "")

      expect(described_class.sorted_ink_ids).to contain_exactly(
        macro_cluster.id,
        described_cluster.id
      )
    end

    it "expires the cache when an ink is destroyed" do
      macro_cluster.destroy!

      expect(described_class.sorted_ink_ids).to eq([])
    end

    it "keeps the cache when another attribute of an ink changes" do
      Rails.cache.write(MissingDescriptions::SORTED_INK_IDS_KEY, [42])

      macro_cluster.update!(ink_name: "New name")

      expect(described_class.sorted_ink_ids).to eq([42])
    end
  end
end
