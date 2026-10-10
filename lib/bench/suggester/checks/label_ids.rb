module Bench
  module Suggester
    module Checks
      class LabelIds
        attr_accessor :snapshot, :label

        def initialize(snapshot:, label:)
          self.snapshot = snapshot
          self.label = label
        end

        def call
          {
            "named_pens" => label.named_pens - pen_ids,
            "named_inks" => label.named_inks - ink_ids,
            "pen.exclude_ids" => Array(label.constraints.dig("pen", "exclude_ids")) - pen_ids,
            "ink.exclude_ids" => Array(label.constraints.dig("ink", "exclude_ids")) - ink_ids
          }.reject { |_field, ids| ids.empty? }
        end

        private

        def pen_ids
          @pen_ids ||= snapshot.pens.map(&:id)
        end

        def ink_ids
          @ink_ids ||= snapshot.inks.map(&:id)
        end
      end
    end
  end
end
