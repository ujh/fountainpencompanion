FactoryBot.define do
  factory :review_feed do
    sequence(:host) { |n| "blog-#{n}.example.com" }
    sequence(:feed_url) { |n| "https://feeds.example.com/blog-#{n}" }
    state { "active" }

    trait :curated do
      curated { true }
      back_catalog_imported { true }
    end

    trait :no_feed do
      state { "no_feed" }
      feed_url { nil }
    end

    trait :ignored do
      state { "ignored" }
      feed_url { nil }
    end
  end
end
