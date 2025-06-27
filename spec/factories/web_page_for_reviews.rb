FactoryBot.define do
  factory :web_page_for_review do
    sequence(:url) { |n| "https://example.com/review-#{n}" }
    state { "pending" }
    data { {} }
  end
end
