class BrandCluster < ApplicationRecord
  has_paper_trail
  has_many :description_versions,
           -> {
             where("object_changes like ?", "%description%").order("id desc")
           },
           class_name: "PaperTrail::Version",
           as: :item

  has_many :macro_clusters, dependent: :nullify
  has_many :collected_inks, through: :macro_clusters

  scope :without_description, -> { where(description: "") }

  def self.without_description_of_user(user)
    without_description_ids = without_description.pluck(:id)
    where(id: without_description_ids).of_user(user)
  end

  def self.of_user(user)
    joins(:collected_inks).where(
      collected_inks: {
        user_id: user.id,
        archived_on: nil
      }
    )
  end

  def self.public
    joins(macro_clusters: { micro_clusters: :collected_inks }).where(
      collected_inks: {
        private: false
      }
    ).group("brand_clusters.id")
  end

  def self.public_count
    public.count.count
  end

  def self.autocomplete_search(term)
    where("name ilike ?", "%#{term}%")
  end

  def public_ink_count
    macro_clusters.public.count.count
  end

  def public_collected_inks_count
    collected_inks.where(private: false).count
  end

  def to_param
    "#{id}-#{name.parameterize}"
  end

  def update_name!
    grouped =
      macro_clusters
        .pluck(:brand_name)
        .map { |n| n.gsub("’", "'").gsub(/\(.*\)/, "").strip }
        .group_by(&:itself)
        .transform_values(&:count)
    update!(name: grouped.max_by(&:last).first)
  end

  def synonyms
    macro_clusters.pluck(:brand_name).uniq.sort - [name]
  end

  def to_csv
    clusters = macro_clusters.public.order(:line_name, :ink_name)
    CSV.generate(col_sep: ";") do |csv|
      csv << [
        "Cluster ID",
        "Cluster Brand Name",
        "Cluster Line Name",
        "Cluster Ink Name",
        "Brand Name",
        "Line Name",
        "Ink Name"
      ]
      clusters.each do |macro_cluster|
        macro_cluster.all_names.each do |ink_name|
          csv << [
            macro_cluster.id,
            macro_cluster.brand_name,
            macro_cluster.line_name,
            macro_cluster.ink_name,
            ink_name.brand_name,
            ink_name.line_name,
            ink_name.ink_name
          ]
        end
      end
    end
  end
end
