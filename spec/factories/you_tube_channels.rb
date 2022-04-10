FactoryBot.define do
  factory :you_tube_channel do
    sequence(:channel_id) { |n| "channel_#{n}" }
    back_catalog_imported { false }
  end
end
