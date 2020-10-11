FactoryBot.define do
  factory :collected_ink do
    user
    brand_name { 'Diamine' }
    line_name { '' }
    sequence(:ink_name) { |n| "Marine #{n}" }
    kind { 'bottle' }
    swabbed { true }
    sequence(:comment) { |n| "Dry time: #{n}" }
    color { '#40E0D0' }
    add_attribute(:private) { false }
  end
end
