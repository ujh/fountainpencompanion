class CreateCollectedInk

  def initialize(collected_ink)
    self.collected_ink = collected_ink
  end

  def perform
    res = collected_ink.save
    collected_ink.twins.without_color.update_all(color: collected_ink.color)
    res
  end

  private

  attr_accessor :collected_ink
end
