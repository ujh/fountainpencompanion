FactoryBot.define do
  factory :friendship do
    association :sender, factory: :user
    association :friend, factory: :user
  end
end
