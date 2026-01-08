FactoryBot.define do
  factory :authentication_token do
    user
    sequence(:name) { |n| "Token #{n}" }
  end
end
