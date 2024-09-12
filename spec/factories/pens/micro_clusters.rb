FactoryBot.define do
  factory :pens_micro_cluster, class: "Pens::MicroCluster" do
    simplified_brand { "brand" }
    sequence(:simplified_model) { |n| "model#{n}" }
    simplified_color { "color" }
  end
end
