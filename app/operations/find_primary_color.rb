class FindPrimaryColor
  COLORS = {
    "black" => "#000000",
    "silver" => "#C0C0C0",
    "gray" => "#808080",
    "white" => "#FFFFFF",
    "maroon" => "#800000",
    "red" => "#FF0000",
    "purple" => "#800080",
    "fuchsia" => "#FF00FF",
    "green" => "#008000",
    "lime" => "#00FF00",
    "olive" => "#808000",
    "yellow" => "#FFFF00",
    "navy" => "#000080",
    "blue" => "#0000FF",
    "teal" => "#008080",
    "aqua" => "#00FFFF"
  }

  def initialize(css_color)
    self.color = Color::RGB.from_html(css_color).to_lab
  end

  def perform
    closest_color =
      COLORS.min_by do |name, hex|
        target_color = Color::RGB.from_html(hex).to_lab
        color.delta_e2000(target_color)
      end
    closest_color.first
  end

  private

  attr_accessor :color
end
