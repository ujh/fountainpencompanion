namespace :clean_up do
  desc "Clean up empty ink and brand clusters"
  task clusters: :environment do
    NewInkName.empty.destroy_all
    InkBrand.empty.destroy_all
  end
end
