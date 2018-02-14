class CreateCollectedInk

  def initialize(collected_ink)
    self.collected_ink = collected_ink
  end

  def perform
    collected_ink.save
  end

  private

  attr_accessor :collected_ink
end
