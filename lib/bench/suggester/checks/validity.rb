module Bench
  module Suggester
    module Checks
      class Validity
        attr_accessor :snapshot, :extra_data, :rejected_pairs

        def initialize(snapshot:, extra_data:, rejected_pairs: [])
          self.snapshot = snapshot
          self.extra_data = extra_data.to_h.stringify_keys
          self.rejected_pairs = rejected_pairs
        end

        def call
          checks = {
            "pen_owned_active" => pen.present?,
            "ink_owned_active" => ink.present?,
            "pen_fountain" => pen.present? && snapshot.inkable_pens.include?(pen),
            "ink_not_swab" => ink.present? && ink.kind != "swab",
            "cartridge_compatible" =>
              pen.present? && ink.present? && CartridgeCompatibility.compatible?(pen, ink),
            "not_rejected_repeat" => !rejected_repeat?,
            "pen_uninked_or_flagged" =>
              pen.present? && (!snapshot.inked?(pen) || extra_data["pen_currently_inked"].present?)
          }
          checks.merge("valid" => checks.values.all?)
        end

        private

        def pen
          @pen ||= snapshot.pens.find { |candidate| candidate.id == extra_data["pen"] }
        end

        def ink
          @ink ||= snapshot.inks.find { |candidate| candidate.id == extra_data["ink"] }
        end

        def rejected_repeat?
          rejected_pairs.any? do |pair|
            pair = pair.to_h.stringify_keys
            pair["pen_id"] == extra_data["pen"] && pair["ink_id"] == extra_data["ink"]
          end
        end
      end
    end
  end
end
