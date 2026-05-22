FactoryBot.define do
  factory :ink_review do
    title { "MyText" }
    sequence(:url) { |n| "http://example#{n}.com" }
    description { "MyText" }
    sequence(:image) { |n| "https://example.com/image#{n}.jpg" }
    macro_cluster
  end
end
