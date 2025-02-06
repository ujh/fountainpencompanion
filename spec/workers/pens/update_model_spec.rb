require "rails_helper"

describe Pens::UpdateModel do
  it "sets the attributes to the most common value from the collected pens" do
    model = create(:pens_model)
    mmc1 = create(:pens_model_micro_cluster, model:)
    mv1 = create(:pens_model_variant, model_micro_cluster: mmc1)
    create(
      :pens_micro_cluster,
      model_variant: mv1,
      collected_pens: [
        create(:collected_pen, brand: "Brand 1", model: "Model 1"),
        create(:collected_pen, brand: "Brand 1", model: "Model 1")
      ]
    )
    mmc2 = create(:pens_model_micro_cluster, model:)
    mv2 = create(:pens_model_variant, model_micro_cluster: mmc2)
    create(
      :pens_micro_cluster,
      model_variant: mv2,
      collected_pens: [
        create(:collected_pen, brand: "Brand 2", model: "Model 1"),
        create(:collected_pen, brand: "Brand 1", model: "Model 2")
      ]
    )

    subject.perform(model.id)

    model.reload
    expect(model.brand).to eq("Brand 1")
    expect(model.model).to eq("Model 1")
  end

  it "schedules the brand update job" do
    model = create(:pens_model)
    mmc1 = create(:pens_model_micro_cluster, model:)
    create(:pens_model_variant, model_micro_cluster: mmc1)

    expect do subject.perform(model.id) end.to change(Pens::AssignBrand.jobs, :count).by(1)
  end

  it "creates the embedding if not present" do
    model = create(:pens_model)
    mmc1 = create(:pens_model_micro_cluster, model:)
    mv1 =
      create(
        :pens_model_variant,
        model_micro_cluster: mmc1,
        brand: "brand",
        model: "model",
        color: "red"
      )
    create(
      :pens_model_variant,
      model_micro_cluster: mmc1,
      brand: "brand",
      model: "model",
      color: "green"
    )
    create(
      :pens_micro_cluster,
      model_variant: mv1,
      collected_pens: [create(:collected_pen, brand: "brand", model: "model")]
    )

    expect do subject.perform(model.id) end.to change { PenEmbedding.count }.by(1)
    pen_embedding = model.pen_embedding
    expect(pen_embedding.content).to eq('"brand model" OR "brand model green" OR "brand model red"')
  end

  it "updates the embedding when present" do
    model = create(:pens_model)
    pen_embedding = create(:pen_embedding, owner: model, content: "old content")
    mmc1 = create(:pens_model_micro_cluster, model:)
    mv1 =
      create(
        :pens_model_variant,
        model_micro_cluster: mmc1,
        brand: "brand",
        model: "model",
        color: "red"
      )
    create(
      :pens_model_variant,
      model_micro_cluster: mmc1,
      brand: "brand",
      model: "model",
      color: "green"
    )
    create(
      :pens_micro_cluster,
      model_variant: mv1,
      collected_pens: [create(:collected_pen, brand: "brand", model: "model")]
    )

    expect do
      expect do subject.perform(model.id) end.not_to change { PenEmbedding.count }
    end.to change { pen_embedding.reload.content }.from("old content").to(
      '"brand model" OR "brand model green" OR "brand model red"'
    )
  end
end
