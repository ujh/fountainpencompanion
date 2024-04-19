require "rails_helper"

describe Pens::MicroCluster do
  describe "#unassigned" do
    it "returns unassigned micro clusters" do
      cluster = create(:pens_micro_cluster)
      expect(described_class.unassigned).to include(cluster)
    end

    it "does not return assigned micro clusters" do
      cluster =
        create(:pens_micro_cluster, model_variant: create(:pens_model_variant))
      expect(described_class.unassigned).not_to include(cluster)
    end
  end

  describe "#ignored" do
    it "returns ignored micro clusters" do
      cluster = create(:pens_micro_cluster, ignored: true)
      expect(described_class.ignored).to include(cluster)
    end

    it "does not return unignored clusters" do
      cluster = create(:pens_micro_cluster, ignored: false)
      expect(described_class.ignored).not_to include(cluster)
    end
  end

  describe "#without_ignored" do
    it "returns unignored micro clusters" do
      cluster = create(:pens_micro_cluster, ignored: false)
      expect(described_class.without_ignored).to include(cluster)
    end

    it "does not return ignored micro clusters" do
      cluster = create(:pens_micro_cluster, ignored: true)
      expect(described_class.without_ignored).not_to include(cluster)
    end
  end
end
