FactoryBot.define do
  factory :pens_micro_cluster, class: "Pens::MicroCluster" do
    simplified_brand { "brand" }
    simplified_model { "model" }
    simplified_color { "color" }
    simplified_material { "material" }
    simplified_trim_color { "trim" }
    simplified_filling_system { "fillingsystem" }
  end
end
