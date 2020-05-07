class SaveCollectedInk

  def initialize(collected_ink, collected_ink_params)
    self.collected_ink = collected_ink
    self.collected_ink_params = collected_ink_params
  end

  def perform
    updated = collected_ink.update(collected_ink_params)
    if updated
      AssignMicroCluster.perform_async(collected_ink.id)
    end
    updated
  end

  private

  attr_accessor :collected_ink
  attr_accessor :collected_ink_params

end
