namespace :clusters do
  desc 'Recompute all brand and ink clusters'
  task recompute: :environment do
    puts "Recompute simplified_names and reset clusters"
    progress = ProgressBar.create(total: CollectedInk.count, format: "%a %e %P% Processed: %c from %C")
    CollectedInk.find_each do |ci|
      ci.update(new_ink_name_id: nil) # triggers a recomputation of the simplified names
      progress.increment
    end
    puts "Deleting existing clusters"
    NewInkName.delete_all
    InkBrand.delete_all
    puts "Recomputing the clusters"
    progress = ProgressBar.create(total: CollectedInk.count, format: "%a %e %P% Processed: %c from %C")
    CollectedInk.find_each do |ci|
      SaveCollectedInk.new(ci, {}).perform
      progress.increment
    end
    Rake::Task["clean_up:clusters"].execute
  end
end
