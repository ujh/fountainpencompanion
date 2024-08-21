require "rails_helper"

describe Pens::UpdateBrandCluster do
  let(:brand) { create(:pens_brand) }
  let(:old_brand) { create(:pens_brand) }
  let(:model) { create(:pens_model, pen_brand: old_brand) }

  it "updates the brand of the model" do
    expect do described_class.new(model, brand).perform end.to change {
      model.reload.pen_brand
    }.from(old_brand).to(brand)
  end

  it "updates other models with the same brand name" do
    second_model = create(:pens_model, brand: model.brand)

    expect do described_class.new(model, brand).perform end.to change {
      second_model.reload.pen_brand
    }.to(brand)
  end

  it "changes the name of the brand to the majority name" do
    model.update!(brand: "Parker")
    create(:pens_model, brand: "Parker")

    expect do described_class.new(model, brand).perform end.to change {
      brand.reload.name
    }.to("Parker")
  end
end
