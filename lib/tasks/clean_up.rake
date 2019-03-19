namespace :clean_up do
  desc "Clean up empty ink and brand clusters"
  task clusters: :environment do
    NewInkName.where("collected_inks_count <= 0").find_each {|nin| nin.destroy }
    InkBrand.where("new_ink_names_count <= 0").find_each {|ib| ib.destroy }
  end
end
