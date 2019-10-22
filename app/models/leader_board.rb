class LeaderBoard

  def self.top_inks
    inks.take(10)
  end

  def self.inks
    extract(build)
  end

  def self.top_bottles
    bottles.take(10)
  end

  def self.bottles
    extract(build.where(collected_inks: {kind: "bottle"}))
  end

  def self.top_samples
    samples.take(10)
  end

  def self.samples
    extract(build.where(collected_inks: {kind: "sample"}))
  end

  def self.top_brands
    brands.take(10)
  end

  def self.brands
    extract(build(
      "(select sum(1) OVER () from collected_inks where collected_inks.user_id = users.id group by collected_inks.brand_name limit 1) as counter"
    ))
  end

  def self.build(select = "count(*) as counter")
    select_clause = "users.*, #{select}"
    base_relation.select(select_clause)
  end

  def self.base_relation
    User.joins(:collected_inks).where(collected_inks: {
      archived_on: nil, private: false
    }).group("users.id").order("counter DESC")
  end

  def self.extract(relation)
    relation.map do |i|
      { id: i.id, public_name: i.public_name, counter: i.counter }
    end
  end
end
