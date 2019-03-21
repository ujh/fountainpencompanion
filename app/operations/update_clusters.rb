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

  THRESHOLD = 2

  attr_accessor :collected_ink

  def find_similar
    cis = by_similarity(brand: simplified_brand_name, ink: simplified_ink_name)
    cis = cis.or(by_similarity(line: simplified_brand_name, ink: simplified_ink_name))
    cis = cis.or(by_similarity(brand: simplified_line_name, ink: simplified_ink_name))
    cis = cis.or(by_combined_similarity)
    cis.distinct
  end

  def by_combined_similarity
    value = [simplified_brand_name, simplified_line_name, simplified_ink_name].join
    CollectedInk.where(
      "levenshtein_less_equal(CONCAT(simplified_brand_name, simplified_line_name, simplified_ink_name), ?, ?) <= ?",
      value, THRESHOLD, THRESHOLD
    )
  end

  def by_similarity(opts)
    rel = CollectedInk
    opts.each do |field, value|
      rel = rel.where(
        "levenshtein_less_equal(simplified_#{field}_name, ?, ?) <= ?",
        value, THRESHOLD, THRESHOLD
      )
    end
    rel
  end

  def update_brand_clusters(cis)
    popular_simplified_brand_name = cis.group(:simplified_brand_name).order(
      Arel.sql('count(id) DESC')
    ).select('simplified_brand_name, count(id)').limit(1).first&.simplified_brand_name
    ink_brand = InkBrand.where(
      "levenshtein_less_equal(simplified_name, ?, ?) <= ?",
      popular_simplified_brand_name, THRESHOLD, THRESHOLD
    ).first
    ink_brand ||= InkBrand.find_or_create_by(simplified_name: popular_simplified_brand_name)
    ink_brand_id = ink_brand.id
    # Don't use update_all to keep the counter caches intact
    cis.each {|ci| ci.update(ink_brand_id: ink_brand_id) }
    ink_brand_id
  end

  def update_ink_cluster(cis, brand_id)
    new_ink_name_id = NewInkName.where(
      ink_brand_id: brand_id, id: cis.pluck(:new_ink_name_id)
    ).pluck(:id).compact.first
    unless new_ink_name_id
      new_ink_name_id = NewInkName.find_or_create_by(
        simplified_name: simplified_ink_name,
        ink_brand_id: brand_id
      ).id
    end
    # Don't use update_all to keep the counter caches intact
    cis.each {|ci| ci.update(new_ink_name_id: new_ink_name_id) }
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
