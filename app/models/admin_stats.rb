class AdminStats
  def micro_cluster_count
    MicroCluster.count
  end

  def pens_models_to_assign_count
    @pens_models_to_assign_count ||= Pens::Model.unassigned.count
  end

  def micro_clusters_to_assign_count
    # The JOIN is there to remove clusters without inks
    @micro_clusters_to_assign_count ||=
      MicroCluster
        .where(macro_cluster_id: nil, ignored: false)
        .joins(:collected_inks)
        .group("micro_clusters.id")
        .count
        .count
  end

  def pens_model_micro_clusters_to_assign_count
    # The JOIN is there to remove clusters without variants
    @pens_model_micro_clusters_to_assign_count ||=
      Pens::ModelMicroCluster
        .unassigned
        .without_ignored
        .joins(:model_variants)
        .group("pens_model_micro_clusters.id")
        .count
        .count
  end

  def pens_micro_clusters_to_assign_count
    # The JOIN is there to remove clusters without variants
    @pens_micro_clusters_to_assign_count ||=
      Pens::MicroCluster
        .unassigned
        .without_ignored
        .joins(:collected_pens)
        .group("pens_micro_clusters.id")
        .count
        .count
  end

  def pens_micro_clusters_prio_to_assign_count(count = 1)
    @pens_micro_clusters_prio_to_assign_count ||= {}
    @pens_micro_clusters_prio_to_assign_count[count] ||= Pens::MicroCluster
      .unassigned
      .without_ignored
      .joins(:collected_pens)
      .group("pens_micro_clusters.id")
      .having("count(*) > ?", count)
      .count
      .count
  end

  def relevant_pens_micro_clusters_count(count = 1)
    @pens_micro_clusters_prio_to_assign_count ||= {}
    @pens_micro_clusters_prio_to_assign_count[count] ||= Pens::MicroCluster
      .joins(:collected_pens)
      .group("pens_micro_clusters.id")
      .having("count(*) > ?", count)
      .count
      .count
  end

  def macro_cluster_count
    @macro_cluster_count ||= MacroCluster.count
  end

  def collected_inks_with_macro_cluster
    CollectedInk.joins(micro_cluster: :macro_cluster).count
  end

  def collected_inks_with_macro_cluster_percentage
    collected_inks_with_macro_cluster * 100.0 / collected_inks_count
  end

  def user_count
    @user_count ||= User.active.count
  end

  def active_user_count
    ink_user_ids = User.joins(:collected_inks).group("users.id").pluck(:id)
    pen_user_ids = User.joins(:collected_pens).group("users.id").pluck(:id)
    @active_user_count ||= (ink_user_ids | pen_user_ids).count
  end

  def patron_count
    User.where(patron: true).count
  end

  def users_using_collected_pens_count
    @users_using_collected_pens_count ||=
      User.joins(:collected_pens).group("users.id").count.count
  end

  def users_using_collected_pens_percentage
    users_using_collected_pens_count * 100.0 / active_user_count
  end

  def users_using_currently_inked_count
    @users_using_currently_inked_count ||=
      User.joins(:currently_inkeds).group("users.id").count.count
  end

  def users_using_currently_inked_percentage
    users_using_currently_inked_count * 100.0 / active_user_count
  end

  def users_using_collected_inks_count
    @users_using_collected_inks_count ||=
      User.joins(:collected_inks).group("users.id").count.count
  end

  def collected_inks_count
    @collected_inks_count ||= CollectedInk.count
  end

  def collected_inks_with_color_count
    @collected_inks_with_color_count ||=
      CollectedInk
        .where.not(color: "")
        .or(CollectedInk.where.not(cluster_color: ""))
        .count
  end

  def users_using_usage_records_count
    @users_using_usage_records_count ||=
      User.joins(currently_inkeds: :usage_records).group("users.id").count.count
  end

  def users_using_usage_records_percentage
    users_using_usage_records_count * 100.0 / active_user_count
  end

  def unassigned_macro_cluster_count
    MacroCluster.unassigned.count
  end

  def macro_clusters_without_review_count
    @macro_clusters_without_review_count ||= MacroCluster.without_review.count
  end

  def macro_clusters_without_reviews_percentage
    macro_clusters_without_review_count * 100.0 / macro_cluster_count
  end
end
