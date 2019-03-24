class SaveCollectedInk

  def initialize(collected_ink, collected_ink_params, excluded_ids: [], recursive: false)
    self.collected_ink = collected_ink
    self.collected_ink_params = collected_ink_params
    self.excluded_ids = excluded_ids
    self.recursive = recursive
  end

  def perform
    updated = collected_ink.update(collected_ink_params)
    if updated
      update_clusters!
      collected_ink.reload
      update_color!
      update_popular_names!
      collected_ink.reload
    end
    updated
  end

  private

  attr_accessor :collected_ink
  attr_accessor :collected_ink_params
  attr_accessor :excluded_ids
  attr_accessor :recursive

  def update_clusters!
    UpdateClusters.new(collected_ink, excluded_ids, recursive).perform
  end

  def update_color!
    UpdateColor.new(collected_ink).perform
  end

  def update_popular_names!
    UpdatePopularNames.new(collected_ink).perform
  end
end
