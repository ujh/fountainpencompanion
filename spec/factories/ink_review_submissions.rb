FactoryBot.define do
  factory :ink_review_submission do
    url { "http://example.com" }
    user
    macro_cluster
  end
end
