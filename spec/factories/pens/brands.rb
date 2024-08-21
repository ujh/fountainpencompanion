FactoryBot.define do
  factory :pens_brand, class: "Pens::Brand" do
    sequence(:name) { |n| "brand #{n}" }
  end
end
