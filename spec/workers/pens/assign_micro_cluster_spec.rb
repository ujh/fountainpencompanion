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
        simplified_color: "color"
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

    it "finds the cluster even for brand synonym" do
      collected_pen.update!(
        brand: "Synonym Brand",
        model: "Model",
        color: "Color",
        material: "Material",
        trim_color: "Trim Color",
        filling_system: "Filling System"
      )

      pen_brand = create(:pens_brand, name: "Brand")
      pen_model = create(:pens_model, brand: "Synonym Brand", pen_brand:)
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

  context "when color duplicated in model" do
    it "assigns the same cluster to both" do
      pen1 =
        create(
          :collected_pen,
          brand: "TWSBI",
          model: "Eco",
          color: "Clear",
          material: "",
          trim_color: "",
          filling_system: ""
        )
      pen2 =
        create(
          :collected_pen,
          brand: "TWSBI",
          model: "Eco Clear",
          color: "Clear",
          material: "",
          trim_color: "",
          filling_system: ""
        )
      expect do
        subject.perform(pen1.id)
        subject.perform(pen2.id)
      end.to change(Pens::MicroCluster, :count).by(1)
      cluster = Pens::MicroCluster.last
      expect(cluster.collected_pens).to match_array([pen1, pen2])
    end
  end

  context "when brand repeated in model" do
    it "assigns the same cluster to both" do
      pen1 =
        create(
          :collected_pen,
          brand: "Lamy",
          model: "Safari",
          color: "Red",
          material: "",
          trim_color: "",
          filling_system: ""
        )
      pen2 =
        create(
          :collected_pen,
          brand: "Lamy",
          model: "Lamy Safari",
          color: "Red",
          material: "",
          trim_color: "",
          filling_system: ""
        )
      expect do
        subject.perform(pen1.id)
        subject.perform(pen2.id)
      end.to change(Pens::MicroCluster, :count).by(1)
      cluster = Pens::MicroCluster.last
      expect(cluster.collected_pens).to match_array([pen1, pen2])
    end
  end

  context "when different versions are used for clear/demo/transparent" do
    it "assigns the same cluster to them all" do
      pen1 =
        create(
          :collected_pen,
          brand: "TWSBI",
          model: "Eco",
          color: "Clear",
          material: "",
          trim_color: "",
          filling_system: ""
        )
      pen2 =
        create(
          :collected_pen,
          brand: "TWSBI",
          model: "Eco Demo",
          color: "Clear",
          material: "",
          trim_color: "",
          filling_system: ""
        )
      pen3 =
        create(
          :collected_pen,
          brand: "TWSBI",
          model: "Eco Demo",
          color: "Transparent",
          material: "",
          trim_color: "",
          filling_system: ""
        )
      expect do
        subject.perform(pen1.id)
        subject.perform(pen2.id)
        subject.perform(pen3.id)
      end.to change(Pens::MicroCluster, :count).by(1)
      cluster = Pens::MicroCluster.last
      expect(cluster.collected_pens).to match_array([pen1, pen2, pen3])
    end
  end

  context "when Capless or Vanishing Point is used" do
    it "assigns the same cluster to them all" do
      pen1 =
        create(
          :collected_pen,
          brand: "Pilot",
          model: "Capless",
          color: "Black",
          material: "",
          trim_color: "",
          filling_system: ""
        )
      pen2 =
        create(
          :collected_pen,
          brand: "Pilot",
          model: "Vanishing Point",
          color: "Black",
          material: "",
          trim_color: "",
          filling_system: ""
        )
      expect do
        subject.perform(pen1.id)
        subject.perform(pen2.id)
      end.to change(Pens::MicroCluster, :count).by(1)
      cluster = Pens::MicroCluster.last
      expect(cluster.collected_pens).to match_array([pen1, pen2])
    end
  end

  context "when Pilot or Namiki is used" do
    it "assigns the same cluster to them all" do
      pen1 =
        create(
          :collected_pen,
          brand: "Namiki",
          model: "Vanishing Point",
          color: "Black",
          material: "",
          trim_color: "",
          filling_system: ""
        )
      pen2 =
        create(
          :collected_pen,
          brand: "Pilot",
          model: "Vanishing Point",
          color: "Black",
          material: "",
          trim_color: "",
          filling_system: ""
        )
      expect do
        subject.perform(pen1.id)
        subject.perform(pen2.id)
      end.to change(Pens::MicroCluster, :count).by(1)
      cluster = Pens::MicroCluster.last
      expect(cluster.collected_pens).to match_array([pen1, pen2])
    end
  end

  context "brand and model are the same" do
    it "does not remove brand from simplified model" do
      pen = create(:collected_pen, brand: "?", model: "?")
      expect { subject.perform(pen.id) }.to change(
        Pens::MicroCluster,
        :count
      ).by(1)
      cluster = Pens::MicroCluster.last
      expect(cluster.simplified_brand).to eq("?")
      expect(cluster.simplified_model).to eq("?")
    end
  end

  context "model and color are the same" do
    it "does not remove the color from the model" do
      pen = create(:collected_pen, model: "?", color: "?")
      expect { subject.perform(pen.id) }.to change(
        Pens::MicroCluster,
        :count
      ).by(1)
      cluster = Pens::MicroCluster.last
      expect(cluster.simplified_model).to eq("?")
      expect(cluster.simplified_color).to eq("")
    end
  end
end
