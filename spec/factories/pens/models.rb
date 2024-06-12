FactoryBot.define do
  factory :pens_model, class: "Pens::Model" do
    brand { "Brand" }
    sequence(:model) { |n| "Model #{n}" }
  end
end
