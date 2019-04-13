namespace :clusters do
  desc 'Recompute all brand and ink clusters'
  task recompute: :environment do
    Rails.logger.level = :warn
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

  desc "Recompute the cluster assignment of inks with names that are only comprised of numbers"
  task recompute_number_inks: :environment do
    Rails.logger.level = :warn
    puts "Recompute simplified_names"
    progress = ProgressBar.create(total: CollectedInk.count, format: "%a %e %P% Processed: %c from %C")
    CollectedInk.find_each do |ci|
      ci.save # triggers a recomputation of the simplified names
      progress.increment
    end
    puts "Find collected inks to recompute and remove from clusters"
    progress = ProgressBar.create(total: CollectedInk.count, format: "%a %e %P% Processed: %c from %C")
    found = []
    CollectedInk.find_each do |ci|
      if ci.simplified_ink_name =~ /^\d+$/
        found << ci
        ci.update(new_ink_name_id: nil)
      end
      progress.increment
    end
    puts "Remove empty clusters"
    Rake::Task["clean_up:clusters"].execute
    puts "Recompute the clusters"
    progress = ProgressBar.create(total: found.length, format: "%a %e %P% Processed: %c from %C")
    found.each do |ci|
      SaveCollectedInk.new(ci, {}).perform
      progress.increment
    end
  end
end
