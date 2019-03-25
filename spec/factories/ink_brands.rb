FactoryBot.define do
  factory :ink_brand do
    sequence(:simplified_name) {|n| "simplified_name#{n}"}
  end
end
