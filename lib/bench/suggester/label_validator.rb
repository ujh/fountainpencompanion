module Bench
  module Suggester
    class LabelValidator
      attr_accessor :cases

      def initialize(cases:)
        self.cases = cases
      end

      def errors(path)
        return ["#{path}: no such file"] unless File.exist?(path)

        hash = YAML.safe_load_file(path)
        return ["#{path}: must be a mapping keyed by case id"] unless hash.is_a?(Hash)

        labels = hash.to_h { |case_id, label| [case_id.to_s, Label.from_h(case_id, label)] }
        labels.flat_map { |case_id, label| label_errors(case_id, label) }
      rescue Psych::SyntaxError, ConstraintSchema::Invalid => e
        ["#{path}: #{e.message}"]
      end

      private

      def label_errors(case_id, label)
        bench_case = cases_by_id[case_id]
        return ["label #{case_id}: no such case"] unless bench_case

        errors = []
        errors << "label #{case_id}: reviewed is set by the owner only" if label.reviewed?
        if !bench_case.instruction? && (label.categories.any? || label.constraints.any?)
          errors << "label #{case_id}: the case has no instruction"
        end
        user = users[bench_case.user_id]
        return errors << "label #{case_id}: the case's user is gone" unless user

        snapshot = PenAndInkSuggestion::CollectionSnapshot.new(user, as_of: bench_case.as_of)
        Checks::LabelIds
          .new(snapshot:, label:)
          .call
          .each do |field, ids|
            errors << "label #{case_id}: #{field} not in the collection at as_of: #{ids.join(", ")}"
          end
        errors
      end

      def cases_by_id
        @cases_by_id ||= cases.index_by(&:id)
      end

      def users
        @users ||= User.where(id: cases.map(&:user_id).uniq).index_by(&:id)
      end
    end
  end
end
