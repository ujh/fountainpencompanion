class SaveCollectedPen
  def initialize(collected_pen, collected_pen_params)
    self.collected_pen = collected_pen
    self.collected_pen_params = collected_pen_params
  end

  def perform
    updated = collected_pen.update(collected_pen_params)
    return false unless updated

    Pens::AssignMicroCluster.perform_async(collected_pen.id)
    update_embedding
    true
  end

  private

  attr_accessor :collected_pen, :collected_pen_params

  def update_embedding
    pen_embedding =
      collected_pen.pen_embedding || collected_pen.build_pen_embedding
    pen_embedding.update(content: collected_pen.pen_name)
  end
end
