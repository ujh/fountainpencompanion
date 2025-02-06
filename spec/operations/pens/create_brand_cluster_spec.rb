require "rails_helper"

describe Pens::CreateBrandCluster do
  let(:model) { create(:pens_model) }

  it "creates a pen brand" do
    expect { described_class.new(model).perform }.to change(Pens::Brand, :count).by(1)
  end

  it "assigns the model to the brand" do
    brand = described_class.new(model).perform
    expect(model.reload.pen_brand).to eq(brand)
  end

  it "creates a brand with the name of the model" do
    brand = described_class.new(model).perform
    expect(brand.name).to eq(model.brand)
  end

  it "assigns all models with the same brand name to the new brand" do
    second_model = create(:pens_model, brand: model.brand)
    brand = described_class.new(model).perform
    expect(second_model.reload.pen_brand).to eq(brand)
  end

  it "does not assign other models with a different brand name" do
    second_model = create(:pens_model, brand: "other brand name")
    brand = described_class.new(model).perform
    expect(second_model.reload.pen_brand).not_to eq(brand)
  end
end
