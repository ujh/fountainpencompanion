class UpdateColor

  def initialize(collected_ink)
    self.collected_ink = collected_ink
  end

  def perform
    if collected_inks_with_color.exists?
      new_ink_name.update(color: average_color)
      collected_inks_without_color.update_all(color: average_color)
    end
  end

  private

  attr_accessor :collected_ink

  def new_ink_name
    @new_ink_name ||= collected_ink.new_ink_name
  end

  def collected_inks_with_color
    new_ink_name.collected_inks_with_color
  end

  def collected_inks_without_color
    new_ink_name.collected_inks_without_color
  end
  def average_color
    Color::RGB.new(*[:red, :green, :blue].map {|f| average_for(colors, f)}).html
  end

  def colors
    @colors ||= collected_inks_with_color.pluck(:color).map do |c|
      Color::RGB.from_html(c)
    end
  end

  def average_for(colors, field)
    sum = (colors.map {|c| c.send(field)**2}.sum)
    size = colors.size.to_f
    Math.sqrt(sum/size).round
  end

end
