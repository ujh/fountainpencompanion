class UpdateCollectedInk

  def initialize(collected_ink, collected_ink_params)
    self.collected_ink = collected_ink
    self.collected_ink_params = collected_ink_params
  end

  def perform
    collected_ink.update(collected_ink_params)
  end

  private

  attr_accessor :collected_ink
  attr_accessor :collected_ink_params
end
