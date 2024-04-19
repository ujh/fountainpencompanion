FactoryBot.define do
  factory :pens_model_variant, class: "Pens::ModelVariant" do
    brand { "Brand" }
    model { "Model" }
  end
end
