require "rails_helper"
require "active_record/testing/query_assertions"

RSpec.describe MicroCluster do
  include RSpec::Rails::MinitestAssertionAdapter
  include ActiveSupport::Testing::Assertions
  include ActiveRecord::Assertions::QueryAssertions

  describe "#clustering_evidence" do
    let(:brand) { "smallmaker" }
    let(:micro_cluster) { create(:micro_cluster, simplified_brand_name: brand) }

    def add_inks(cluster, *users)
      users.each { |user| create(:collected_ink, user: user, micro_cluster: cluster) }
    end

    def catalogued_micro_cluster(brand_name, macro_cluster = create(:macro_cluster), ignored: false)
      create(
        :micro_cluster,
        simplified_brand_name: brand_name,
        macro_cluster: macro_cluster,
        ignored: ignored
      )
    end

    it "counts the distinct users of the micro cluster" do
      user = create(:user)
      add_inks(micro_cluster, user, user, create(:user))

      expect(micro_cluster.clustering_evidence[:ink_users]).to eq(2)
    end

    it "counts the distinct users of all micro clusters of the same brand" do
      shared_user = create(:user)
      add_inks(micro_cluster, shared_user)
      add_inks(create(:micro_cluster, simplified_brand_name: brand), shared_user, create(:user))
      add_inks(create(:micro_cluster, simplified_brand_name: "otherbrand"), create(:user))

      expect(micro_cluster.clustering_evidence[:brand_users]).to eq(2)
    end

    it "takes the brand from the micro clusters, not from the collected inks" do
      add_inks(micro_cluster, create(:user))
      other_cluster = create(:micro_cluster, simplified_brand_name: "otherbrand")
      create(:collected_ink, brand_name: "Small Maker", micro_cluster: other_cluster)

      evidence = nil
      assert_queries_match(/collected_inks.{0,3}\..{0,3}simplified_brand_name/i, count: 0) do
        evidence = micro_cluster.clustering_evidence
      end

      expect(evidence[:brand_users]).to eq(1)
    end

    it "counts the catalogue clusters of the brand" do
      shared_macro_cluster = create(:macro_cluster)
      catalogued_micro_cluster(brand, shared_macro_cluster)
      catalogued_micro_cluster(brand, shared_macro_cluster)
      catalogued_micro_cluster(brand)
      catalogued_micro_cluster("otherbrand")

      expect(micro_cluster.clustering_evidence[:brand_catalogue_inks]).to eq(2)
    end

    it "does not count ignored or unassigned micro clusters as catalogued" do
      catalogued_micro_cluster(brand, ignored: true)
      create(:micro_cluster, simplified_brand_name: brand, macro_cluster: nil)

      expect(micro_cluster.clustering_evidence[:brand_catalogue_inks]).to eq(0)
    end

    it "never counts a placeholder brand as catalogued" do
      generic_cluster = create(:micro_cluster, simplified_brand_name: "generic")
      3.times { catalogued_micro_cluster("generic") }

      expect(generic_cluster.clustering_evidence[:brand_catalogue_inks]).to eq(0)
    end

    it "lists the placeholder brands in their simplified form" do
      expect(MicroCluster::PLACEHOLDER_BRAND_NAMES).to include(
        "generic",
        "unknown",
        "noname",
        "unbranded"
      )
      MicroCluster::PLACEHOLDER_BRAND_NAMES.each do |name|
        expect(Simplifier.simplify(name)).to eq(name)
      end
    end

    it "returns zeros for a micro cluster without inks of an unknown brand" do
      expect(micro_cluster.clustering_evidence).to eq(
        ink_users: 0,
        brand_users: 0,
        brand_catalogue_inks: 0
      )
    end
  end
end
