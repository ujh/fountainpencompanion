class SaveCollectedInk
  def initialize(collected_ink, collected_ink_params)
    self.collected_ink = collected_ink
    self.collected_ink_params = normalize_params(collected_ink_params)
  end

  def perform
    updated = collected_ink.update(collected_ink_params)
    if updated
      AssignMicroCluster.perform_async(collected_ink.id)
      update_embedding
    end

    updated
  end

  private

  attr_accessor :collected_ink, :collected_ink_params

  def normalize_params(params)
    params.to_h.symbolize_keys.except(:archived)
  end

  def update_embedding
    ink_embedding.update(content: collected_ink.short_name)
  end

  def ink_embedding
    collected_ink.ink_embedding || collected_ink.build_ink_embedding
  end
end
