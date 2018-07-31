class SaveCollectedInk

  def initialize(collected_ink, collected_ink_params)
    self.collected_ink = collected_ink
    self.collected_ink_params = collected_ink_params
  end

  def perform
    res = collected_ink.update(collected_ink_params)
    update_ink_brand!
    update_color_of_unset_twins!
    collected_ink.reload if res # to return the updated color
    res
  end

  private

  attr_accessor :collected_ink
  attr_accessor :collected_ink_params

  def update_ink_brand!
    UpdateInkBrand.new(collected_ink).perform
  end

  def update_color_of_unset_twins!
    unset_twins.update_all(color: average_color) if twins_with_color.exists?
  end

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
