require "rails_helper"

describe Pens::AssignModelMicroCluster do
  it "does not fail if the model variant does not exist" do
    expect { subject.perform(-1) }.not_to raise_error
  end

  it "creates a new model micro cluster" do
    mv = create(:pens_model_variant, brand: "Brand", model: "Model")

    expect do subject.perform(mv.id) end.to change(
      Pens::ModelMicroCluster,
      :count
    ).by(1)

    cluster = Pens::ModelMicroCluster.last
    mv.reload
    expect(mv.model_micro_cluster).to eq(cluster)
  end

  it "assigns to an existing model micro cluster" do
    mv = create(:pens_model_variant, brand: "Brand", model: "Model")
    cluster =
      create(
        :pens_model_micro_cluster,
        simplified_brand: "brand",
        simplified_model: "model"
      )

    expect do subject.perform(mv.id) end.not_to change(
      Pens::ModelMicroCluster,
      :count
    )

    mv.reload
    expect(mv.model_micro_cluster).to eq(cluster)
  end
end
