FactoryBot.define do
  factory :ink_review do
    title { "MyText" }
    sequence(:url) { |n| "http://example#{n}.com" }
    description { "MyText" }
    image { "MyText" }
    macro_cluster
  end
end
