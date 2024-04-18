class SaveCollectedPen
  def initialize(collected_pen, collected_pen_params)
    self.collected_pen = collected_pen
    self.collected_pen_params = collected_pen_params
  end

  def perform
    collected_pen.update(collected_pen_params)
    # TODO: Do some additional work here
  end

  private

  attr_accessor :collected_pen, :collected_pen_params
end
