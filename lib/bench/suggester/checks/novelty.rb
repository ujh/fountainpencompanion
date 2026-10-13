module Bench
  module Suggester
    module Checks
      class Novelty
        UNUSED_DAYS = 180

        attr_accessor :snapshot, :extra_data

        def initialize(snapshot:, extra_data:)
          self.snapshot = snapshot
          self.extra_data = extra_data.to_h.stringify_keys
        end

        def call
          {
            "pen_novel" => pen && novel?(pen),
            "ink_novel" => ink && novel?(ink),
            "colour_new_vs_inked" => colour_new_vs_inked
          }
        end

        private

        def novel?(item)
          last_activity_on = snapshot.stats_for(item).last_activity_on
          last_activity_on.nil? || last_activity_on <= snapshot.today - UNUSED_DAYS
        end

        def colour_new_vs_inked
          family = ink && ColorProfile.for(ink).family
          return unless family

          snapshot
            .active_inkings
            .map { |inking| ColorProfile.for(inking.collected_ink).family }
            .exclude?(family)
        end

        def pen
          @pen ||= snapshot.pens.find { |candidate| candidate.id == extra_data["pen"] }
        end

        def ink
          @ink ||= snapshot.inks.find { |candidate| candidate.id == extra_data["ink"] }
        end
      end
    end
  end
end
