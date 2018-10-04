class SaveCollectedInk

  def initialize(collected_ink, collected_ink_params)
    self.collected_ink = collected_ink
    self.collected_ink_params = collected_ink_params
  end

  def perform
    res = collected_ink.update(collected_ink_params)
    update_ink_brand!
    update_new_ink_name!
    update_color!
    collected_ink.reload if res # to return the updated color
    res
  end

  private

  attr_accessor :collected_ink
  attr_accessor :collected_ink_params

  def update_ink_brand!
    UpdateInkBrand.new(collected_ink).perform
  end

  def update_new_ink_name!
    UpdateNewInkName.new(collected_ink).perform
  end

  def update_color!
    UpdateColor.new(collected_ink).perform
  end
end
