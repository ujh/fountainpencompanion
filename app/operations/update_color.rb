class UpdateColor

  def initialize(collected_ink)
    self.collected_ink = collected_ink
  end

  def perform
    unset_twins.update_all(color: average_color) if twins_with_color.exists?
  end

  private

  attr_accessor :collected_ink

  def unset_twins
    twins.without_color
  end

  def twins
    collected_ink.twins
  end

  def average_color
    Color.new([:red, :green, :blue].map {|f| average_for(colors_of_twins, f)}).html
  end

  def colors_of_twins
    @colors ||= twins_with_color.pluck(:color).map do |c|
      Color::RGB.from_html(c)
    end
  end

  def twins_with_color
    twins.with_color
  end

  def average_for(colors, field)
    sum = (colors.map {|c| c.send(field)**2}.sum)
    size = colors.size.to_f
    Math.sqrt(sum/size).round
  end

end
