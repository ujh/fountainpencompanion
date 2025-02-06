require "rails_helper"

describe Pens::MicroCluster do
  describe "#unassigned" do
    it "returns unassigned micro clusters" do
      cluster = create(:pens_micro_cluster)
      expect(described_class.unassigned).to include(cluster)
    end

    it "does not return assigned micro clusters" do
      cluster = create(:pens_micro_cluster, model_variant: create(:pens_model_variant))
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

  it "eager loading of collected_pens is properly configured" do
    cluster = create(:pens_micro_cluster)
    collected_pen = create(:collected_pen, pens_micro_cluster: cluster)

    expect(cluster.reload.collected_pens).to eq([collected_pen])
    # Requires stuff to be properly set up for eager loading to work
    expect(described_class.includes(:collected_pens).first.collected_pens).to eq([collected_pen])
  end
end
