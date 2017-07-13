class LeaderBoard
  def self.inks
    User.joins(:collected_inks).group("users.id").order("count(*) DESC").limit(10)
  end

  def self.bottles
    User.joins(:collected_inks).where(collected_inks: {kind: "bottle"}).group("users.id").order("count(*) DESC").limit(10)
  end

  def self.samples
    User.joins(:collected_inks).where(collected_inks: {kind: "sample"}).group("users.id").order("count(*) DESC").limit(10)
  end

  def self.brands
    select_clause = "users.*,  (select sum(1) OVER () from collected_inks where collected_inks.user_id = users.id group by collected_inks.brand_name limit 1) as brand_count"
    User.joins(:collected_inks).select(select_clause).group("users.id").order("brand_count DESC").limit(10)
  end
end
