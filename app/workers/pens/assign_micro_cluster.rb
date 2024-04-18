module Pens
  class AssignMicroCluster
    include Sidekiq::Worker

    def perform(collected_pen_id)
      collected_pen = CollectedPen.find(collected_pen_id)
      cluster =
        Pens::MicroCluster.find_or_create_by!(cluster_attributes(collected_pen))
      collected_pen.update!(pens_micro_cluster: cluster)
    rescue ActiveRecord::RecordNotFound
      # do nothing
    end

    private

    def cluster_attributes(collected_pen)
      %i[brand model color material trim_color filling_system].each_with_object(
        {}
      ) do |attribute, hash|
        search_key = "simplified_#{attribute}"
        search_value = Simplifier.simplify(collected_pen.send(attribute) || "")
        hash[search_key] = search_value
      end
    end
  end
end
