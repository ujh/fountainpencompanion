class LeaderBoard

  def self.refresh!
    inks(force: true)
    bottles(force: true)
    samples(force: true)
    brands(force: true)
    inks_by_popularity(force: true)
  end

  def self.inks_by_popularity(force: false)
    Rails.cache.fetch("LeaderBoard#inks_by_popularity", force: force) do
      MacroCluster.joins(micro_clusters: :collected_inks).includes(:brand_cluster).where(
        collected_inks: { private: false }
      ).group("macro_clusters.id").select(
        "macro_clusters.*, count(macro_clusters.id) as ci_count"
      ).order("ci_count desc")
    end
  end

  def self.top_inks_by_popularity
    inks_by_popularity.take(10)
  end

  def self.top_inks
    inks.take(10)
  end

  def self.inks(force: false)
    Rails.cache.fetch("LeaderBoard#inks", force: force) do
      extract(build)
    end
  end

  def self.top_bottles
    bottles.take(10)
  end

  def self.bottles(force: false)
    Rails.cache.fetch("LeaderBoard#bottles", force: force) do
      extract(build.where(collected_inks: {kind: "bottle"}))
    end
  end

  def self.top_samples
    samples.take(10)
  end

  def self.samples(force: false)
    Rails.cache.fetch("LeaderBoard#samples", force: force) do
      extract(build.where(collected_inks: {kind: "sample"}))
    end
  end

  def self.top_brands
    brands.take(10)
  end

  def self.brands(force: false)
    Rails.cache.fetch("LeaderBoard#brands", force: force) do
      extract(build(
        "(select sum(1) OVER () from collected_inks where collected_inks.user_id = users.id group by collected_inks.brand_name limit 1) as counter"
      ))
    end
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
      { id: i.id, public_name: i.public_name, counter: i.counter, patron: i.patron }
    end
  end
end
