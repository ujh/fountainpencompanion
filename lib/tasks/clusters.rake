namespace :clusters do
  desc 'Recompute all brand and ink clusters'
  task recompute: :environment do
    progress = ProgressBar.create(total: CollectedInk.count, format: "%a %e %P% Processed: %c from %C")
    CollectedInk.find_each do |ci|
      SaveCollectedInk.new(ci, {}).perform
      progress.increment
    end
  end
end
