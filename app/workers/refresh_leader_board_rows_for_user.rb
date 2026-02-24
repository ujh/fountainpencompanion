class RefreshLeaderBoardRowsForUser
  include Sidekiq::Worker

  sidekiq_options queue: "leaderboards"

  def perform(user_id)
    self.user = User.find_by(id: user_id)
    return unless user

    update_brands_row
    update_users_by_description_edits_row
  end

  private

  attr_accessor :user

  def update_brands_row
    row = LeaderBoardRow::Brands.find_or_initialize_by(user: user)
    clustered_count =
      user
        .collected_inks
        .joins(micro_cluster: :macro_cluster)
        .group("macro_clusters.brand_cluster_id")
        .count
        .count
    unclustered_count =
      user
        .collected_inks
        .where(private: false)
        .left_joins(micro_cluster: :macro_cluster)
        .where(macro_clusters: { id: nil })
        .distinct
        .count(:brand_name)
    row.value = clustered_count + unclustered_count
    row.save!
  end

  def update_users_by_description_edits_row
    row = LeaderBoardRow::DescriptionEdits.find_or_initialize_by(user: user)
    row.value =
      PaperTrail::Version.where(item_type: %w[MacroCluster BrandCluster], whodunnit: user.id).count
    row.save!
  end
end
