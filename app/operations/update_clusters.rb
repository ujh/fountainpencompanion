class UpdateClusters

  attr_accessor :excluded_ids

  def initialize(collected_ink)
    self.collected_ink = collected_ink
  end

  def perform
    similar = find_similar
    brand_id = update_brand_clusters(similar)
    new_ink_name_id = update_ink_cluster(similar, brand_id)
    clean_clusters
  end

  private

  THRESHOLD = 2

  attr_accessor :collected_ink

  def find_similar
    cis = by_similarity(brand: simplified_brand_name, ink: simplified_ink_name)
    cis = cis.or(by_similarity(line: simplified_brand_name, ink: simplified_ink_name))
    cis = cis.or(by_similarity(brand: simplified_line_name, ink: simplified_ink_name)) if simplified_line_name.present?
    cis = cis.or(by_combined_similarity)
    cis = cis.where.not(id: excluded_ids)
    cis = cis.distinct
    ink_ids = cis.pluck(:new_ink_name_id).uniq.compact
    members = CollectedInk.where(id: collected_ink.id)
    if ink_ids.present?
      members = members.or(CollectedInk.where(new_ink_name_id: ink_ids))
    end
    cleaned = remove_blacklisted(members)
    # members.to_a
    CollectedInk.where(id: cleaned.map(&:id))
  end

  BLACKLIST = {
    brand: [
      ['banmi', 'colte'],
      ['kobe', 'krone'],
      ['sheaffer', 'scribo'],
      ['omas', 'oaso'],
    ],
    ink: [
      ['sepia', 'seiran', 'seiya']
    ],
  }

  def blacklist_match(ci1, ci2)
    BLACKLIST.each do |field, lists|
      method = "simplified_#{field}_name"
      lists.each do |values|
        values.each do |value|
          remaining = values - [value]
          if ci1.send(method) == value && remaining.include?(ci2.send(method))
            return true
          elsif ci2.send(method) == value && remaining.include?(ci1.send(method))
            return true
          end
        end
      end
    end
    return false
  end

  def remove_blacklisted(cis)
    cis.reject do |ci|
      blacklist_match(collected_ink, ci)
    end
  end

  def by_combined_similarity
    value = [simplified_brand_name, simplified_line_name, simplified_ink_name].join
    # TODO: Maybe double the distance here?
    rel = CollectedInk.where(
      "levenshtein_less_equal(CONCAT(simplified_brand_name, simplified_line_name, simplified_ink_name), ?, ?) <= ?",
      value, THRESHOLD, THRESHOLD
    )
    if simplified_line_name
      # Covers the case where brand and line name have been put into the brand field
      rel = rel.or(
        CollectedInk.where(
          "levenshtein_less_equal(CONCAT(simplified_brand_name, simplified_ink_name), ?, ?) <= ?",
          value, THRESHOLD, THRESHOLD
        )
      )
    end
    rel
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
    ink_brand ||= InkBrand.find_or_create_by(simplified_name: popular_simplified_brand_name)
    ink_brand.id
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
    cis.update_all(new_ink_name_id: new_ink_name_id)
    new_ink_name_id
  end

  def clean_clusters
    NewInkName.empty.delete_all
    InkBrand.empty.delete_all
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
