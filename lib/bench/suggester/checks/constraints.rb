module Bench
  module Suggester
    module Checks
      class Constraints
        MET = "met"
        RELAXED = "relaxed"
        VIOLATED = "violated"
        UNSATISFIABLE = "unsatisfiable"
        NO_SUGGESTION = "no_suggestion"

        HARD_FIELDS = %w[
          pen.exclude_ids
          pen.exclude_mentions
          pen.comment_exclude
          pen.nib_grades_include
          pen.nib_grades_exclude
          pen.nib_width
          pen.nib_characters_include
          pen.nib_characters_exclude
          pen.usage
          ink.exclude_ids
          ink.exclude_mentions
          ink.tags_exclude
          ink.kinds_include
          ink.kinds_exclude
          ink.colour_include
          ink.colour_exclude
          ink.shimmer
          ink.scented
          ink.usage
          pair_usage
        ].freeze
        RELAXABLE_FIELDS = %w[
          pen.nib_grades_include
          pen.nib_width
          pen.nib_characters_include
          pen.usage
          ink.kinds_include
          ink.colour_include
          ink.usage
          pair_usage
        ].freeze
        UNCONSTRAINED = ["any", [], nil].freeze

        attr_accessor :snapshot, :extra_data, :constraints

        def initialize(snapshot:, extra_data:, constraints:)
          self.snapshot = snapshot
          self.extra_data = extra_data.to_h.stringify_keys
          self.constraints = constraints
        end

        def call
          { "hard" => statuses(hard_fields), "soft" => statuses(soft_fields) }
        end

        private

        def statuses(fields)
          fields.to_h { |field, value| [field, status(field, value)] }
        end

        def hard_fields
          labelled_fields.reject { |field, value| soft?(field, value) }
        end

        def soft_fields
          labelled_fields.select { |field, value| soft?(field, value) }
        end

        def soft?(field, value)
          field == "ink.scented" && value == "include"
        end

        def labelled_fields
          @labelled_fields ||=
            HARD_FIELDS.filter_map do |field|
              value = constraints.dig(*field.split("."))
              [field, value] unless UNCONSTRAINED.include?(value)
            end
        end

        def status(field, value)
          return NO_SUGGESTION unless pen && ink
          return MET if satisfied?(field, value, pen, ink)
          return VIOLATED unless relaxable?(field, value)
          return RELAXED if relaxed?(field)
          return UNSATISFIABLE unless satisfiable?(field, value)

          VIOLATED
        end

        def relaxable?(field, value)
          RELAXABLE_FIELDS.include?(field) || (field == "ink.shimmer" && value == "include")
        end

        def relaxed?(field)
          Array(extra_data["relaxations"]).any? do |relaxation|
            relaxation == field ||
              (relaxation.is_a?(Hash) && relaxation.stringify_keys["field"] == field)
          end
        end

        def satisfiable?(field, value)
          if field == "pair_usage"
            candidate_pens.any? do |candidate_pen|
              snapshot.fillable_inks.any? do |candidate_ink|
                pair_satisfied?(value, candidate_pen, candidate_ink)
              end
            end
          elsif field.start_with?("pen.")
            candidate_pens.any? { |candidate| pen_satisfied?(field, value, candidate) }
          else
            snapshot.fillable_inks.any? { |candidate| ink_satisfied?(field, value, candidate) }
          end
        end

        def candidate_pens
          @candidate_pens ||=
            snapshot.inkable_pens.reject { |candidate| snapshot.inked?(candidate) }
        end

        def satisfied?(field, value, pen, ink)
          if field == "pair_usage"
            pair_satisfied?(value, pen, ink)
          elsif field.start_with?("pen.")
            pen_satisfied?(field, value, pen)
          else
            ink_satisfied?(field, value, ink)
          end
        end

        def pair_satisfied?(value, pen, ink)
          paired = snapshot.pair_history.key?([pen.id, ink.id])
          value == "repeat" ? paired : !paired
        end

        def pen_satisfied?(field, value, pen)
          profile = snapshot.nib_profile(pen)
          case field.delete_prefix("pen.")
          when "exclude_ids"
            value.exclude?(pen.id)
          when "exclude_mentions"
            value.none? { |mention| mentions?([pen.brand, pen.model], mention) }
          when "comment_exclude"
            value.none? { |text| pen.comment.to_s.downcase.include?(text.downcase) }
          when "nib_grades_include"
            value.any? { |grade| profile.matches_grade?(grade) }
          when "nib_grades_exclude"
            value.none? { |grade| profile.matches_grade?(grade) }
          when "nib_width"
            profile.public_send(:"#{value}?")
          when "nib_characters_include"
            profile.characters.map(&:to_s).intersect?(value)
          when "nib_characters_exclude"
            !profile.characters.map(&:to_s).intersect?(value)
          when "usage"
            usage_satisfied?(value, pen)
          end
        end

        def ink_satisfied?(field, value, ink)
          case field.delete_prefix("ink.")
          when "exclude_ids"
            value.exclude?(ink.id)
          when "exclude_mentions"
            value.none? do |mention|
              mentions?([ink.brand_name, ink.line_name, ink.ink_name], mention)
            end
          when "tags_exclude"
            !snapshot.tag_names(ink).map(&:downcase).intersect?(value.map(&:downcase))
          when "kinds_include"
            value.include?(ink.kind)
          when "kinds_exclude"
            value.exclude?(ink.kind)
          when "colour_include"
            ColorProfile.for(ink).matches_any?(value)
          when "colour_exclude"
            !ColorProfile.for(ink).matches_any?(value)
          when "shimmer", "scented"
            property = field.delete_prefix("ink.").to_sym
            PenAndInkSuggestion::InkProperties.for(ink).include?(property) == (value == "include")
          when "usage"
            usage_satisfied?(value, ink)
          end
        end

        def usage_satisfied?(value, item)
          used = snapshot.stats_for(item).usage_count.positive?
          value == "used_before" ? used : !used
        end

        def mentions?(parts, mention)
          pattern = /(?<![[:alnum:]])#{Regexp.escape(mention.squish)}(?![[:alnum:]])/i
          parts.compact.join(" ").match?(pattern)
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
