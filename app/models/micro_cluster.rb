class MicroCluster < ApplicationRecord
  belongs_to :macro_cluster, optional: true
  has_many :collected_inks
  has_many :public_collected_inks, -> { where(private: false) }, class_name: "CollectedInk"
  has_one :ink_embedding, dependent: :destroy, as: :owner
  has_many :agent_logs, as: :owner, dependent: :destroy

  paginates_per 100

  scope :unassigned, -> { where(macro_cluster_id: nil) }
  scope :without_ignored, -> { where(ignored: false) }
  scope :ignored, -> { where(ignored: true) }
  scope :for_processing,
        -> do
          # The JOIN is there to remove clusters without inks
          unassigned
            .without_ignored
            .joins(:collected_inks)
            .includes(:agent_logs)
            .group("micro_clusters.id")
            .order(updated_at: :asc)
            .reject do |cluster|
              cluster.agent_logs.any? { |al| al.action == "hand_over_to_human" && al.approved? }
            end
        end

  def simplified_name
    [simplified_brand_name, simplified_line_name, simplified_ink_name].reject { |f| f.blank? }
      .join(" ")
  end

  def all_names
    collected_inks.map(&:short_name).uniq
  end

  def all_names_as_elements
    collected_inks.map { |ink| ink.slice(:brand_name, :line_name, :ink_name) }.uniq
  end

  def colors
    collected_inks.map(&:color).reject(&:blank?).uniq
  end
end
