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
  ]

  WORKERS = TYPES.map { |t| "refresh_leader_board/#{t}".camelize.constantize }

  def self.refresh!(type)
    send(type, force: true)
  end

  def self.users_by_description_edits(force: false)
    LeaderBoardRow::DescriptionEdits.to_leader_board
  end

  def self.top_users_by_description_edits
    LeaderBoardRow::DescriptionEdits.limit(10).to_leader_board
  end

  def self.pens_by_popularity(force: false)
    Rails
      .cache
      .fetch("LeaderBoard#pens_by_popularity", force:) do
        Pens::Model
          .includes(:collected_pens)
          .reject { |model| model.collected_pens.size.zero? }
          .map do |model|
            { name: model.name, count: model.collected_pens.size }
          end
      end
  end

  def self.top_pens_by_popularity
    pens_by_popularity.take(10)
  end

  def self.ink_review_submissions(force: false)
    Rails
      .cache
      .fetch("LeaderBoard#ink_review_submissions", force:) do
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
      .fetch("LeaderBoard#usage_records", force:) do
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
      .fetch("LeaderBoard#currently_inked", force:) do
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
      .fetch("LeaderBoard#inks_by_popularity", force:) do
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
    Rails.cache.fetch("LeaderBoard#inks", force:) { extract(build) }
  end

  def self.top_inks
    inks.take(10)
  end

  def self.bottles(force: false)
    Rails
      .cache
      .fetch("LeaderBoard#bottles", force:) do
        extract(build.where(collected_inks: { kind: "bottle" }))
      end
  end

  def self.top_bottles
    bottles.take(10)
  end

  def self.samples(force: false)
    Rails
      .cache
      .fetch("LeaderBoard#samples", force:) do
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
