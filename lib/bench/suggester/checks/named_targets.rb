module Bench
  module Suggester
    module Checks
      class NamedTargets
        attr_accessor :snapshot, :label, :extra_data

        def initialize(snapshot:, label:, extra_data:)
          self.snapshot = snapshot
          self.label = label
          self.extra_data = extra_data.to_h.stringify_keys
        end

        def call
          {
            "pen_hit" => hit(label.named_pens & snapshot.pens.map(&:id), extra_data["pen"]),
            "ink_hit" => hit(label.named_inks & snapshot.inks.map(&:id), extra_data["ink"])
          }
        end

        private

        def hit(targets, picked_id)
          targets.include?(picked_id) if targets.any?
        end
      end
    end
  end
end
