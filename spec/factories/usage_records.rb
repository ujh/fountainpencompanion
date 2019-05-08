FactoryBot.define do
  factory :usage_record do
    currently_inked
    used_on { Date.today }
  end
end
