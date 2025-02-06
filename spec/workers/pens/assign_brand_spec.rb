require "rails_helper"

describe Pens::AssignBrand do
  it "does not fail if pen model does not exist" do
    expect { subject.perform(-1) }.not_to raise_error
  end

  it "assigns the pen brand if one can be found" do
    model = create(:pens_model, brand: "Brand")

    brand = create(:pens_brand, name: "Brand")

    expect do subject.perform(model.id) end.to change { model.reload.pen_brand }.from(nil).to(brand)
  end

  it "assigns the pen brand if a synonym matches" do
    model = create(:pens_model, brand: "Brand X")

    brand = create(:pens_brand, name: "Brand")
    create(:pens_model, pen_brand: brand, brand: "Brand X")

    expect do subject.perform(model.id) end.to change { model.reload.pen_brand }.from(nil).to(brand)
  end

  it "does not assign if the pen brand is already present" do
    existing_brand = create(:pens_brand)
    model = create(:pens_model, brand: "Brand", pen_brand: existing_brand)
    matching_brand = create(:pens_brand, name: "Brand")

    expect { subject.perform(model.id) }.not_to(change { model.reload.pen_brand })
  end
end
