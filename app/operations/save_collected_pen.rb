class SaveCollectedPen
  def initialize(collected_pen, collected_pen_params)
    self.collected_pen = collected_pen
    self.collected_pen_params = collected_pen_params
  end

  def perform
    updated = collected_pen.update(collected_pen_params)
    Pens::AssignMicroCluster.perform_async(collected_pen.id) if updated
    updated
  end

  private

  attr_accessor :collected_pen, :collected_pen_params
end
