FactoryBot.define do
  factory :user do
    sequence(:email, 1981) { |n| "moni_#{n}@example.com" }
    password { SecureRandom.urlsafe_base64(8) }
    confirmed_at { 1.day.ago }
  end
end
