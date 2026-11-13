FactoryBot.define do
  factory :error_report do
    user
    reportable factory: :macro_cluster
    description { "Two inks are merged" }
  end
end
