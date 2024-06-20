require "rails_helper"

describe Pens::UpdateModelVariant do
  it "sets the attributes to the most common value from the collected pens" do
    model_variant = create(:pens_model_variant)
    mc1 = create(:pens_micro_cluster, model_variant:)
    mc2 = create(:pens_micro_cluster, model_variant:)
    create(
      :collected_pen,
      pens_micro_cluster: mc1,
      brand: "Brand 1",
      model: "Model 1",
      color: "Color 1",
      material: "Material 1",
      trim_color: "Trim Color 1",
      filling_system: "Filling System 1"
    )
    create(
      :collected_pen,
      pens_micro_cluster: mc1,
      brand: "Brand 2",
      model: "Model 1",
      color: "Color 2",
      material: "Material 2",
      trim_color: "Trim Color 2",
      filling_system: "Filling System 2"
    )
    create(
      :collected_pen,
      pens_micro_cluster: mc2,
      brand: "Brand 1",
      model: "Model 2",
      color: "Color 1",
      material: "Material 1",
      trim_color: "Trim Color 1",
      filling_system: "Filling System 1"
    )

    subject.perform(model_variant.id)

    model_variant.reload
    expect(model_variant.brand).to eq("Brand 1")
    expect(model_variant.model).to eq("Model 1")
    expect(model_variant.color).to eq("Color 1")
    expect(model_variant.material).to eq("Material 1")
    expect(model_variant.trim_color).to eq("Trim Color 1")
    expect(model_variant.filling_system).to eq("Filling System 1")
  end

  it "works with empty values, too" do
    model_variant = create(:pens_model_variant)
    mc = create(:pens_micro_cluster, model_variant:)
    create(
      :collected_pen,
      pens_micro_cluster: mc,
      brand: "Brand",
      model: "Model",
      color: "",
      material: nil,
      trim_color: nil,
      filling_system: nil
    )

    subject.perform(model_variant.id)

    model_variant.reload
    expect(model_variant.brand).to eq("Brand")
    expect(model_variant.model).to eq("Model")
    expect(model_variant.color).to eq("")
    expect(model_variant.material).to eq("")
    expect(model_variant.trim_color).to eq("")
    expect(model_variant.filling_system).to eq("")
  end

  it "schedules the correct follow up job" do
    model_variant = create(:pens_model_variant)
    mc = create(:pens_micro_cluster, model_variant:)
    create(
      :collected_pen,
      pens_micro_cluster: mc,
      brand: "Brand",
      model: "Model",
      color: "",
      material: nil,
      trim_color: nil,
      filling_system: nil
    )

    expect { subject.perform(model_variant.id) }.to change(
      Pens::AssignModelMicroCluster.jobs,
      :length
    ).by(1)

    job = Pens::AssignModelMicroCluster.jobs.last
    expect(job["args"]).to eq([model_variant.id])
  end
end
