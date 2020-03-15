FactoryBot.define do
  factory :micro_cluster do
    simplified_brand_name { "MyText" }
    simplified_line_name { "MyText" }
    sequence(:simplified_ink_name) { |n| "MyText#{n}" }
  end
end
