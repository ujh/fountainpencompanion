class LeaderBoard
  TYPES = %w[
    inks
    bottles
    samples
    inks_by_popularity
    currently_inked
    usage_records
    pens_by_popularity
    ink_review_submissions
    users_by_description_edits
  ]

  WORKERS = TYPES.map { |t| "refresh_leader_board/#{t}".camelize.constantize }

  def self.refresh!(type)
    self.send(type, force: true)
  end

  def self.users_by_description_edits(force: false)
    Rails
      .cache
      .fetch("LeaderBoard#users_by_description_edits", force: force) do
        count = Hash.new { |h, k| h[k] = 0 }
        BrandCluster.find_each do |c|
          c.versions.each { |v| count[v.whodunnit] += 1 if v.whodunnit }
        end
        MacroCluster.find_each do |c|
          c.versions.each { |v| count[v.whodunnit] += 1 if v.whodunnit }
        end
        ordered = count.to_a.sort_by(&:last).reverse
        without_nil = ordered.find_all { |user_id, counter| user_id.present? }
        without_nil.map do |user_id, counter|
          user = User.find_by(id: user_id)
          {
            id: user&.id,
            public_name: user&.public_name,
            counter: counter,
            patron: user&.patron
          }
        end
      end
  end

  def self.top_users_by_description_edits
    users_by_description_edits.take(10)
  end

  def self.pens_by_popularity(force: false)
    Rails
      .cache
      .fetch("LeaderBoard#pens_by_popularity", force: force) do
        CollectedPen
          .group("lower(concat(brand, model))")
          .where(archived_on: nil)
          .select(
            "initcap(min(brand)) as brand, initcap(min(model)) as model, count(id) as count"
          )
          .having("count(distinct user_id) > 1")
          .order("count desc")
      end
  end

  def self.top_pens_by_popularity
    pens_by_popularity.take(10)
  end

  def self.ink_review_submissions(force: false)
    Rails
      .cache
      .fetch("LeaderBoard#ink_review_submissions", force: force) do
        relation =
          User
            .where("users.id <> 1")
            .joins(:ink_review_submissions)
            .select("users.*, count(*) as counter")
            .group("users.id")
            .order("counter DESC")
        extract(relation)
      end
  end

  def self.top_ink_review_submissions
    ink_review_submissions.take(10)
  end

  def self.usage_records(force: false)
    Rails
      .cache
      .fetch("LeaderBoard#usage_records", force: force) do
        relation =
          User
            .joins(currently_inkeds: :usage_records)
            .select("users.*, count(*) as counter")
            .group("users.id")
            .order("counter DESC")
        extract(relation)
      end
  end

  def self.top_usage_records
    usage_records.take(10)
  end

  def self.currently_inked(force: false)
    Rails
      .cache
      .fetch("LeaderBoard#currently_inked", force: force) do
        relation =
          User
            .joins(:currently_inkeds)
            .select("users.*, count(*) as counter")
            .group("users.id")
            .order("counter DESC")
        extract(relation)
      end
  end

  def self.top_currently_inked
    currently_inked.take(10)
  end

  def self.inks_by_popularity(force: false)
    Rails
      .cache
      .fetch("LeaderBoard#inks_by_popularity", force: force) do
        MacroCluster
          .joins(micro_clusters: :collected_inks)
          .includes(:brand_cluster)
          .where(collected_inks: { private: false })
          .group("macro_clusters.id")
          .select("macro_clusters.*, count(macro_clusters.id) as ci_count")
          .order("ci_count desc")
      end
  end

  def self.top_inks_by_popularity
    inks_by_popularity.take(10)
  end

  def self.inks(force: false)
    Rails.cache.fetch("LeaderBoard#inks", force: force) { extract(build) }
  end

  def self.top_inks
    inks.take(10)
  end

  def self.bottles(force: false)
    Rails
      .cache
      .fetch("LeaderBoard#bottles", force: force) do
        extract(build.where(collected_inks: { kind: "bottle" }))
      end
  end

  def self.top_bottles
    bottles.take(10)
  end

  def self.samples(force: false)
    Rails
      .cache
      .fetch("LeaderBoard#samples", force: force) do
        extract(build.where(collected_inks: { kind: "sample" }))
      end
  end

  def self.top_samples
    samples.take(10)
  end

  def self.brands(force: false)
    LeaderBoardRow::Brands.to_leader_board
  end

  def self.top_brands
    LeaderBoardRow::Brands.limit(10).to_leader_board
  end

  def self.build(select = "count(*) as counter")
    select_clause = "users.*, #{select}"
    base_relation.select(select_clause)
  end

  def self.base_relation
    User
      .joins(:collected_inks)
      .where(collected_inks: { archived_on: nil, private: false })
      .group("users.id")
      .order("counter DESC")
  end

  def self.extract(relation)
    relation.map do |i|
      {
        id: i.id,
        public_name: i.public_name,
        counter: i.counter,
        patron: i.patron
      }
    end
  end
end
