class UpdateMacroCluster
  include Sidekiq::Worker

  def perform(id)
    self.cluster = MacroCluster.find(id)
    update_color
    update_names
    cluster.save
  end

  private

  attr_accessor :cluster

  def update_names
    cluster.brand_name = popular(:brand_name)
    cluster.line_name = popular(:line_name)
    cluster.ink_name = popular(:ink_name)
  end

  def popular(field)
    grouped = cluster.collected_inks.group_by {|ci| ci.send(field) }
    popular = grouped.values.max_by {|cis| cis.length }.first
    popular.send(field)
  end

  def update_color
    colors = cluster.collected_inks.with_color.pluck(:color).map do |c|
      Color::RGB.from_html(c)
    end
    return if colors.blank?

    average = Color::RGB.new(*[:red, :green, :blue].map {|f| average_for(colors, f)}).html
    cluster.color = average
  end

  def average_for(colors, field)
    sum = (colors.map {|c| c.send(field)**2}.sum)
    size = colors.size.to_f
    Math.sqrt(sum/size).round
  end
end
