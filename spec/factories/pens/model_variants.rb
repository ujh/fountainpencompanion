FactoryBot.define do
  factory :pens_model_variant, class: "Pens::ModelVariant" do
    brand { "Brand" }
    sequence(:model) { |n| "Model #{n}" }
  end
end
