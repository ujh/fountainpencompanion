class UpdateMacroCluster
  include Sidekiq::Worker

  def perform(id)
    self.cluster = MacroCluster.find(id)
    return if cluster.collected_inks.empty?

    update_color
    update_names
    update_tags
    cluster.save!
    update_embedding
    cluster.collected_inks.update_all(cluster_color: cluster.color)
    if cluster.brand_cluster
      CheckBrandClusters.perform_async(id)
    else
      AssignMacroCluster.perform_async(id)
    end
  end

  private

  attr_accessor :cluster

  def update_tags
    cluster.tags = Gutentag::Tag.names_for_scope(cluster.public_collected_inks).to_a
  end

  def update_names
    cluster.brand_name = popular(:brand_name)
    cluster.line_name = popular(:line_name)
    cluster.ink_name = popular(:ink_name)
  end

  def popular(field)
    inks = cluster.collected_inks
    return "" if inks.empty?

    grouped = inks.group_by { |ci| ci.send(field) }
    popular = grouped.values.max_by { |cis| cis.length }.first
    popular.send(field)
  end

  def update_color
    colors = cluster.collected_inks.with_color.pluck(:color).map { |c| Color::RGB.from_html(c) }
    return if colors.blank?

    average = Color::RGB.new(*%i[red green blue].map { |f| average_for(colors, f) }).html
    cluster.color = average
  end

  def average_for(colors, field)
    sum = colors.map { |c| c.send(field)**2 }.sum
    size = colors.size.to_f
    Math.sqrt(sum / size).round
  end

  def update_embedding
    embedding = cluster.ink_embedding || cluster.build_ink_embedding
    embedding.update(content: cluster.name)
  end
end
