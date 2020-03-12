class SaveCollectedInk

  def initialize(collected_ink, collected_ink_params)
    self.collected_ink = collected_ink
    self.collected_ink_params = collected_ink_params
  end

  def perform
    updated = collected_ink.update(collected_ink_params)
    if updated
      update_clusters!
      collected_ink.reload
      update_color!
      update_popular_names!
      collected_ink.reload
      AssignMicroCluster.perform_async(collected_ink.id)
    end
    updated
  end

  private

  attr_accessor :collected_ink
  attr_accessor :collected_ink_params

  def update_clusters!
    UpdateClusters.new(collected_ink).perform
  end

  def update_color!
    UpdateColor.new(collected_ink).perform
  end

  def update_popular_names!
    UpdatePopularNames.new(collected_ink).perform
  end
end
