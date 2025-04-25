class MicroCluster < ApplicationRecord
  belongs_to :macro_cluster, optional: true
  has_many :collected_inks
  has_many :public_collected_inks, -> { where(private: false) }, class_name: "CollectedInk"
  has_one :ink_embedding, dependent: :destroy, as: :owner

  paginates_per 100

  scope :unassigned, -> { where(macro_cluster_id: nil) }
  scope :without_ignored, -> { where(ignored: false) }
  scope :ignored, -> { where(ignored: true) }

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
end
