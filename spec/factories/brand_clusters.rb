FactoryBot.define do
  factory :brand_cluster do
    sequence(:name) { |n| "Brand Cluster #{n}" }
  end
end
