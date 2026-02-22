FactoryBot.define do
  factory :macro_cluster do
    brand_name { "brand_name" }
    line_name { "line_name" }
    sequence(:ink_name) { |n| "ink_name_#{n}" }
    color { "#FFFFFF" }
    tags { [] }
  end
end
