module Bench
  module Suggester
    module Checks
      class NamedTargets
        attr_accessor :label, :extra_data

        def initialize(label:, extra_data:)
          self.label = label
          self.extra_data = extra_data.to_h.stringify_keys
        end

        def call
          {
            "pen_hit" => hit(label.named_pens, extra_data["pen"]),
            "ink_hit" => hit(label.named_inks, extra_data["ink"])
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
