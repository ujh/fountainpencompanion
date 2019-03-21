FactoryBot.define do
  factory :new_ink_name do
    sequence(:simplified_name) {|n| "simplified_name#{n}"}
  end
end
