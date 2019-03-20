class UpdatePopularNames

  def initialize(collected_ink)
    self.collected_ink = collected_ink
  end

  def perform
    collected_ink.ink_brand.update_popular_name!
    collected_ink.new_ink_name.update_popular_names!
  end

  private

  attr_accessor :collected_ink
end
