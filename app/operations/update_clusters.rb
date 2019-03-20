class UpdateClusters

  def initialize(collected_ink)
    self.collected_ink = collected_ink
  end

  def perform
    similar = find_similar
    brand_id = update_brand_clusters(similar)
    update_ink_cluster(similar, brand_id)
  end

  private

  attr_accessor :collected_ink

  def find_similar
    # TODO: Needs to do fuzzy matching
      cis = CollectedInk.where(
      simplified_brand_name: simplified_brand_name,
      simplified_ink_name: simplified_ink_name
    ).to_a
    # TODO: Needs to do fuzzy matching
    cis << CollectedInk.where(
      simplified_line_name: simplified_brand_name,
      simplified_ink_name: simplified_ink_name
    ).to_a
    # TODO: Needs to do fuzzy matching
    cis << CollectedInk.where(
      simplified_brand_name: simplified_line_name,
      simplified_ink_name: simplified_ink_name
    ).to_a
    # TODO: Needs to do fuzzy matching
    cis << CollectedInk.where(
      "CONCAT(simplified_brand_name, simplified_line_name, simplified_ink_name) = ?",
      [simplified_brand_name, simplified_line_name, simplified_ink_name].join
    ).to_a
    cis.flatten.uniq
  end

  def update_brand_clusters(cis)
    ink_brand_id = cis.map(&:ink_brand_id).compact.first
    unless ink_brand_id
      # TODO: Needs to do fuzzy matching
      ink_brand_id = InkBrand.find_or_create_by(simplified_name: simplified_brand_name).id
    end
    cis.each {|ci| ci.update(ink_brand_id: ink_brand_id)}
    ink_brand_id
  end

  def update_ink_cluster(cis, brand_id)
    new_ink_name_id = cis.map(&:new_ink_name_id).compact.first
    unless new_ink_name_id
      new_ink_name_id = NewInkName.create!(
        simplified_name: simplified_ink_name,
        ink_brand_id: brand_id
      ).id
    end
    cis.each {|ci| ci.update(new_ink_name_id: new_ink_name_id)}
  end

  def simplified_brand_name
    collected_ink.simplified_brand_name
  end

  def simplified_line_name
    collected_ink.simplified_line_name
  end

  def simplified_ink_name
    collected_ink.simplified_ink_name
  end
end
