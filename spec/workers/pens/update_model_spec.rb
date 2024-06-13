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
end
