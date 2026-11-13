FactoryBot.define do
  factory :error_report do
    user
    reportable factory: :macro_cluster
    description { "Two inks are merged" }
  end

  factory :error_report_entry do
    error_report
    user factory: %i[user admin]
    kind { "note" }
    body { "Looking into it" }
  end
end
