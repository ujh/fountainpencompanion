class SaveCollectedInk

  def initialize(collected_ink, collected_ink_params)
    self.collected_ink = collected_ink
    self.collected_ink_params = collected_ink_params
  end

  def perform
    res = collected_ink.update(collected_ink_params)
    update_color_of_unset_twins!
    res
  end

  private

  attr_accessor :collected_ink
  attr_accessor :collected_ink_params

  def update_color_of_unset_twins!
    collected_ink.twins.without_color.update_all(color: average_color)
  end

  def average_color
    collected_ink.color
  end
end
