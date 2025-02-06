module Pens
  class AssignMicroCluster
    include Sidekiq::Worker

    def perform(collected_pen_id)
      collected_pen = CollectedPen.find(collected_pen_id)
      cluster = find_or_create_cluster(collected_pen)
      collected_pen.update!(pens_micro_cluster: cluster)
      Pens::UpdateMicroCluster.perform_async(cluster.id)
    rescue ActiveRecord::RecordNotFound
      # do nothing
    end

    private

    def find_or_create_cluster(collected_pen)
      # Get the cluster with the lowest ID. Others will get removed eventually
      cluster =
        Pens::MicroCluster
          .where(expand_brand_names(collected_pen, cluster_attributes(collected_pen)))
          .order(:id)
          .first
      return cluster if cluster

      Pens::MicroCluster.create!(cluster_attributes(collected_pen))
    end

    def cluster_attributes(collected_pen)
      attrs = default_attributes(collected_pen)
      handle_clear!(attrs)
      handle_synonyms!(attrs)
      if attrs["simplified_model"] == attrs["simplified_color"]
        attrs["simplified_color"] = ""
      else
        attrs["simplified_model"].delete_suffix!(attrs["simplified_color"])
      end
      unless attrs["simplified_model"] == attrs["simplified_brand"]
        attrs["simplified_model"].delete_prefix!(attrs["simplified_brand"])
      end
      attrs
    end

    def expand_brand_names(collected_pen, attrs)
      brand = Pens::Model.where.not(pen_brand: nil).find_by(brand: collected_pen.brand)&.pen_brand
      return attrs unless brand

      attrs.merge("simplified_brand" => brand.simplified_names)
    end

    def handle_clear!(attrs)
      %i[model color].each do |attribute|
        key = "simplified_#{attribute}"
        attrs[key].gsub!("transparent", "clear")
        attrs[key].gsub!("demonstrator", "clear")
        attrs[key].gsub!("demo", "clear")
      end
    end

    def handle_synonyms!(attrs)
      attrs["simplified_brand"].gsub!("namiki", "pilot")
      attrs["simplified_model"].gsub!("capless", "vanishingpoint")
    end

    def default_attributes(collected_pen)
      %i[brand model color].each_with_object({}) do |attribute, hash|
        search_key = "simplified_#{attribute}"
        search_value = Simplifier.simplify(collected_pen.send(attribute) || "")
        hash[search_key] = search_value
      end
    end
  end
end
