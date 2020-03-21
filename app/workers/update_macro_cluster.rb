class UpdateMacroCluster
  include Sidekiq::Worker

  def perform(id)
    cluster = MacroCluster.find(id)
    update_color(cluster)
    update_names(cluster)
    cluster.save
  end

  private

  def update_names(cluster)
    grouped = cluster.collected_inks.group_by {|ci| ci.short_name }
    popular = grouped.values.max_by {|cis| cis.length }.first
    cluster.brand_name = popular.brand_name
    cluster.line_name = popular.line_name
    cluster.ink_name = popular.ink_name
  end

  def update_color(cluster)
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
