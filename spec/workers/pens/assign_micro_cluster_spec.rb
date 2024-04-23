require "rails_helper"

describe Pens::AssignMicroCluster do
  let(:collected_pen) { create(:collected_pen) }

  it "does not fail if pen does not exist" do
    expect { subject.perform(-1) }.not_to raise_error
  end

  context "new pen" do
    it "creates a new cluster and assigns it" do
      expect { subject.perform(collected_pen.id) }.to change(
        Pens::MicroCluster,
        :count
      ).by(1)
      cluster = Pens::MicroCluster.last
      collected_pen.reload
      expect(collected_pen.pens_micro_cluster).to eq(cluster)
    end

    it "schedules the cluster update job" do
      expect { subject.perform(collected_pen.id) }.to change(
        Pens::UpdateMicroCluster.jobs,
        :length
      ).by(1)
    end
  end

  context "existing pen" do
    let!(:cluster) do
      create(
        :pens_micro_cluster,
        simplified_brand: "brand",
        simplified_model: "model",
        simplified_color: "color",
        simplified_material: "material",
        simplified_trim_color: "trimcolor",
        simplified_filling_system: "fillingsystem"
      )
    end

    it "attaches the cluster to the existing cluster" do
      collected_pen.update!(
        brand: "Brand",
        model: "Model",
        color: "Color",
        material: "Material",
        trim_color: "Trim Color",
        filling_system: "Filling System"
      )

      expect { subject.perform(collected_pen.id) }.not_to change(
        Pens::MicroCluster,
        :count
      )
      collected_pen.reload
      expect(collected_pen.pens_micro_cluster).to eq(cluster)
    end

    it "schedules the cluster update job" do
      expect { subject.perform(collected_pen.id) }.to change(
        Pens::UpdateMicroCluster.jobs,
        :length
      ).by(1)
    end
  end
end
