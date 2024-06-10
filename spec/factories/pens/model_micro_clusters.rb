FactoryBot.define do
  factory :pens_model_micro_cluster, class: "Pens::ModelMicroCluster" do
    simplified_brand { "brand" }
    sequence(:simplified_model) { |n| "model#{n}" }
  end
end
