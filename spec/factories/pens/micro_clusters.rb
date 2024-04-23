FactoryBot.define do
  factory :pens_micro_cluster, class: "Pens::MicroCluster" do
    simplified_brand { "brand" }
    sequence(:simplified_model) { |n| "model#{n}" }
    simplified_color { "color" }
    simplified_material { "material" }
    simplified_trim_color { "trim" }
    simplified_filling_system { "fillingsystem" }
  end
end
