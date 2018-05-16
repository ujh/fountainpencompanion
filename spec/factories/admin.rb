FactoryBot.define do
  factory :admin do
    sequence(:email) { |n| "urban#{n}@example.com" }
    password { SecureRandom.urlsafe_base64(8) }
    confirmed_at { 1.day.ago }
  end
end
