class SaveCollectedInk
  def initialize(collected_ink, collected_ink_params, macro_cluster_id: nil)
    self.collected_ink = collected_ink
    self.collected_ink_params = collected_ink_params
    self.macro_cluster_id = macro_cluster_id
  end

  def perform
    updated = collected_ink.update(collected_ink_params)
    if updated
      AssignMicroCluster.perform_async(collected_ink.id, macro_cluster_id)
      update_embedding
    end

    updated
  end

  private

  attr_accessor :collected_ink, :collected_ink_params, :macro_cluster_id

  def update_embedding
    ink_embedding.update(content: collected_ink.short_name)
  end

  def ink_embedding
    collected_ink.ink_embedding || collected_ink.build_ink_embedding
  end
end
