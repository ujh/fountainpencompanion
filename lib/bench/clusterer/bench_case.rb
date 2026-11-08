module Bench
  module Clusterer
    BenchCase =
      Data.define(
        :id,
        :kind,
        :log_id,
        :micro_cluster_id,
        :expected,
        :cluster_id,
        :disputed,
        :explanation,
        :transcript,
        :inks
      ) do
        def self.from_h(hash)
          new(**members.index_with { |member| hash[member.to_s] })
        end

        def round1? = kind == "round1"

        def action
          {
            "assign" => "assign_to_cluster",
            "ignore" => "ignore_ink",
            "create" => "create_new_cluster"
          }.fetch(kind)
        end

        def checker_class
          "CheckInkClustering::#{kind.capitalize}".constantize
        end

        def correct?(result)
          return false unless result["got"] == expected
          return true unless round1? && expected == "assign_to_cluster"

          result["cluster_id"].to_i == cluster_id.to_i
        end

        def to_h = super.transform_keys(&:to_s)
      end
  end
end
