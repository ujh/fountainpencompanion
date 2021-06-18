FactoryBot.define do
  factory :usage_record do
    currently_inked
    sequence(:used_on) {|n| n.days.ago }
  end
end
