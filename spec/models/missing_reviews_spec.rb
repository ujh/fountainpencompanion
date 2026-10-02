require "rails_helper"

describe MissingReviews do
  def create_public_cluster(**attributes)
    macro_cluster = create(:macro_cluster, **attributes)
    micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
    create(:collected_ink, micro_cluster: micro_cluster)
    macro_cluster
  end

  describe ".sorted_ids" do
    it "returns the public clusters without a review sorted by name" do
      second = create_public_cluster(brand_name: "B")
      first = create_public_cluster(brand_name: "A")
      reviewed = create_public_cluster(brand_name: "C")
      create(:ink_review, macro_cluster: reviewed)

      expect(described_class.sorted_ids).to eq([first.id, second.id])
    end

    it "includes clusters whose only review was rejected" do
      macro_cluster = create_public_cluster
      create(:ink_review, macro_cluster: macro_cluster, rejected_at: Time.current)

      expect(described_class.sorted_ids).to eq([macro_cluster.id])
    end

    it "excludes clusters that only have private collected inks" do
      macro_cluster = create(:macro_cluster)
      micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
      create(:collected_ink, micro_cluster: micro_cluster, private: true)

      expect(described_class.sorted_ids).to eq([])
    end

    it "caches the ids" do
      first = create_public_cluster
      described_class.sorted_ids
      create_public_cluster

      expect(described_class.sorted_ids).to eq([first.id])
    end
  end

  describe ".percentage" do
    it "returns the percentage of clusters without a review" do
      create(:macro_cluster)
      create(:ink_review, macro_cluster: create(:macro_cluster))

      expect(described_class.percentage).to eq(50.0)
    end
  end

  describe "expiry" do
    let!(:macro_cluster) { create_public_cluster }

    before do
      described_class.sorted_ids
      described_class.percentage
    end

    it "expires the cache when a review is created" do
      create(:ink_review, macro_cluster: macro_cluster)

      expect(described_class.sorted_ids).to eq([])
      expect(described_class.percentage).to eq(0.0)
    end

    it "expires the cache when a review is rejected" do
      ink_review = create(:ink_review, macro_cluster: macro_cluster)
      described_class.sorted_ids

      ink_review.reject!

      expect(described_class.sorted_ids).to eq([macro_cluster.id])
    end

    it "expires the cache when a review is destroyed" do
      ink_review = create(:ink_review, macro_cluster: macro_cluster)
      described_class.sorted_ids

      ink_review.destroy!

      expect(described_class.sorted_ids).to eq([macro_cluster.id])
    end

    it "expires the cache when a review moves to another cluster" do
      ink_review = create(:ink_review, macro_cluster: macro_cluster)
      other_cluster = create_public_cluster
      described_class.expire
      expect(described_class.sorted_ids).to eq([other_cluster.id])

      ink_review.update!(macro_cluster: other_cluster)

      expect(described_class.sorted_ids).to eq([macro_cluster.id])
    end

    it "keeps the cache when an unrelated attribute of a review changes" do
      ink_review = create(:ink_review, macro_cluster: macro_cluster)
      described_class.sorted_ids
      Rails.cache.write(MissingReviews::SORTED_IDS_KEY, [42])

      ink_review.update!(title: "New title")

      expect(described_class.sorted_ids).to eq([42])
    end
  end
end
