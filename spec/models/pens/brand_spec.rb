require "rails_helper"

describe Pens::Brand do
  it "properly references the assigned models" do
    brand = create(:pens_brand)
    model = create(:pens_model, pens_brand_id: brand.id)

    expect(brand.models).to eq([model])
  end

  describe "#names" do
    it "returns all the unique names of all assigned models" do
      brand = create(:pens_brand)
      create(:pens_model, pen_brand: brand, brand: "Brand 1")
      create(:pens_model, pen_brand: brand, brand: "Brand 1")
      create(:pens_model, pen_brand: brand, brand: "Brand 2")

      expect(brand.names).to match_array(["Brand 1", "Brand 2"])
    end
  end

  describe "#synonyms" do
    it "returns all unique names of all assigned models, apart from the brand's own name" do
      brand = create(:pens_brand, name: "Brand")
      create(:pens_model, pen_brand: brand, brand: "Brand")
      create(:pens_model, pen_brand: brand, brand: "Brand 1")
      create(:pens_model, pen_brand: brand, brand: "Brand 2")

      expect(brand.synonyms).to match_array(["Brand 1", "Brand 2"])
    end
  end
end
