class SaveCollectedInk

  def initialize(collected_ink, collected_ink_params)
    self.collected_ink = collected_ink
    self.collected_ink_params = collected_ink_params
  end

  def perform
    res = collected_ink.update(collected_ink_params)
    collected_ink.twins.without_color.update_all(color: collected_ink.color)
    res
  end

  private

  attr_accessor :collected_ink
  attr_accessor :collected_ink_params
end
