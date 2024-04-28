namespace :clusters do
  task remove_empty_pens_micro_clusters: :environment do
    Pens::MicroCluster
      .unassigned
      .without_ignored
      .includes(:collected_pens)
      .find_each { |pmc| pmc.destroy if pmc.collected_pens.size.zero? }
  end
end
