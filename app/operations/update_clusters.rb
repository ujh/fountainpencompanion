class UpdateClusters

  attr_accessor :excluded_ids

  def initialize(collected_ink, excluded_ids, recursive)
    self.collected_ink = collected_ink
    self.excluded_ids = excluded_ids
    self.recursive = recursive
  end

  def perform
    similar = find_similar
    brand_id = update_brand_clusters(similar)
    new_ink_name_id = update_ink_cluster(similar, brand_id)
    self.excluded_ids += similar.pluck(:id)
    clean_cluster(new_ink_name_id)
  end

  private

  THRESHOLD = 2

  attr_accessor :collected_ink
  attr_accessor :recursive

  def find_similar
    cis = by_similarity(brand: simplified_brand_name, ink: simplified_ink_name)
    cis = cis.or(by_similarity(line: simplified_brand_name, ink: simplified_ink_name))
    cis = cis.or(by_similarity(brand: simplified_line_name, ink: simplified_ink_name)) if simplified_line_name.present?
    cis = cis.or(by_combined_similarity)
    cis = cis.where.not(id: excluded_ids)
    cis.distinct
  end

  def by_combined_similarity
    value = [simplified_brand_name, simplified_line_name, simplified_ink_name].join
    # TODO: Maybe double the distance here?
    CollectedInk.where(
      "levenshtein_less_equal(CONCAT(simplified_brand_name, simplified_line_name, simplified_ink_name), ?, ?) <= ?",
      value, THRESHOLD, THRESHOLD
    )
  end

  def by_similarity(opts)
    rel = CollectedInk
    opts.each do |field, value|
      t = THRESHOLD
      # For short ink names we have to be stricter to reduce the number of matches
      if field == :ink && value.length <= 4
        t = THRESHOLD / 2
      end
      rel = rel.where(
        "levenshtein_less_equal(simplified_#{field}_name, ?, ?) <= ?",
        value, t, t
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
    new_ink_name_id
  end

  def clean_cluster(new_ink_name_id)
    return if recursive # Only ever try assigning other members once
    extraneous_members = NewInkName.find(new_ink_name_id).collected_inks.where.not(id: excluded_ids)
    extraneous_members.each do |ci|
      ci.update(ink_brand: nil, new_ink_name: nil)
    end
    extraneous_members.each do |ci|
      SaveCollectedInk.new(ci, {}, excluded_ids: excluded_ids, recursive: true).perform
      self.excluded_ids << ci.id
    end
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
