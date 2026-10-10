module Bench
  module Suggester
    BenchCase =
      Data.define(
        :id,
        :log_id,
        :user_id,
        :as_of,
        :source,
        :split,
        :tier,
        :instruction,
        :rejected_pairs,
        :original,
        :fidelity
      ) do
        def self.from_h(hash)
          hash = hash.to_h.deep_stringify_keys
          new(
            id: hash.fetch("id").to_s,
            log_id: hash["log_id"],
            user_id: hash.fetch("user_id"),
            as_of: Time.zone.parse(hash.fetch("as_of").to_s),
            source: hash.fetch("source"),
            split: hash.fetch("split"),
            tier: hash["tier"],
            instruction: hash["instruction"],
            rejected_pairs: Array(hash["rejected_pairs"]),
            original: hash["original"] || {},
            fidelity: hash["fidelity"] || {}
          )
        end

        def instruction? = instruction.present?

        def to_h
          super.deep_stringify_keys.merge("as_of" => as_of.utc.iso8601(6))
        end
      end
  end
end
