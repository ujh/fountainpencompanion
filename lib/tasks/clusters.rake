namespace :clusters do
  task remove_empty_pens_micro_clusters: :environment do
    Pens::MicroCluster.unassigned.without_ignored.limit(10).includes(:collected_pens).find_each do |pmc|
      pmc.destroy if pmc.collected_pens.size.zero?
    end
  end
end
