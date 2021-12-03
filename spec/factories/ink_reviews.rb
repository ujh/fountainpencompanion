FactoryBot.define do
  factory :ink_review do
    title { "MyText" }
    url { "http://example.com" }
    description { "MyText" }
    image { "MyText" }
    rejected_at { "2021-12-03 09:56:11" }
    approved_at { "2021-12-03 09:56:11" }
    macro_cluster
  end
end
