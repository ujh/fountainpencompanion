class LeaderBoard
  def self.inks
    base_relation.order("count(*) DESC").limit(10)
  end

  def self.bottles
    base_relation.where(collected_inks: {kind: "bottle"}).order("count(*) DESC").limit(10)
  end

  def self.samples
    base_relation.where(collected_inks: {kind: "sample"}).order("count(*) DESC").limit(10)
  end

  def self.brands
    select_clause = "users.*,  (select sum(1) OVER () from collected_inks where collected_inks.user_id = users.id group by collected_inks.simplified_brand_name limit 1) as brand_count"
    base_relation.select(select_clause).order("brand_count DESC").limit(10)
  end

  def self.base_relation
    User.joins(:collected_inks).where(collected_inks: {
      archived_on: nil, private: false
    }).group("users.id")
  end
end
