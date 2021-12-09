class FetchReviews
  include Sidekiq::Worker

  def perform
    FetchReviews::MountainOfInk.perform_async
    MacroCluster.find_each do |macro_cluster|
      CheckBrandCluster.perform_async(macro_cluster.id)
    end
  end
end
