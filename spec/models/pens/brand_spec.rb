require "rails_helper"

describe Pens::Brand do
  it "properly references the assigned models" do
    brand = create(:pens_brand)
    model = create(:pens_model, pens_brand_id: brand.id)

    expect(brand.models).to eq([model])
  end
end
