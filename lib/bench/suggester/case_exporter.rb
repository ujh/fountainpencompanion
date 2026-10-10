module Bench
  module Suggester
    class CaseExporter
      REGRESSION_LOG_IDS = [
        59_469,
        59_470,
        72_744,
        75_416,
        63_386,
        74_643,
        67_714,
        75_202,
        65_117,
        61_840,
        63_025,
        66_639,
        70_723,
        61_893,
        60_374,
        58_945,
        62_866,
        74_936,
        77_374,
        72_841,
        62_709,
        61_224,
        61_226,
        71_065,
        71_058,
        71_063,
        59_471,
        70_590,
        76_017,
        *(48_500..48_526),
        72_180,
        72_192,
        *(73_376..73_380),
        46_293,
        46_295,
        52_095
      ].freeze
      SPLIT_SALT = "fpc-suggester-bench"
      MIN_FIDELITY = 0.9

      Export = Data.define(:cases, :dropped)

      attr_accessor :since,
                    :instruction_cases,
                    :plain_cases,
                    :per_user_cap,
                    :seed,
                    :regression_log_ids,
                    :min_fidelity

      def initialize(
        since: SINCE,
        instruction_cases: 200,
        plain_cases: 50,
        per_user_cap: 20,
        seed: 1,
        regression_log_ids: REGRESSION_LOG_IDS,
        min_fidelity: MIN_FIDELITY
      )
        self.since = since
        self.instruction_cases = instruction_cases
        self.plain_cases = plain_cases
        self.per_user_cap = per_user_cap
        self.seed = seed
        self.regression_log_ids = regression_log_ids
        self.min_fidelity = min_fidelity
      end

      def export
        regression = regression_runs.filter_map { |run| reconstruct(run, "regression") }
        used_groups = regression_runs.to_set { |run| group_key(run) }
        instruction_groups =
          runs
            .select { |run| run.instruction.present? }
            .group_by { |run| group_key(run) }
            .except(*used_groups)
        plain_groups =
          runs.reject { |run| run.instruction.present? }.to_h { |run| [[run.log_id], [run]] }

        cases =
          regression + sample(instruction_groups, instruction_cases, "instruction") +
            sample(plain_groups, plain_cases, "plain")
        Export.new(cases: cases.sort_by(&:log_id), dropped: dropped.transform_values(&:sort))
      end

      private

      def runs
        @runs ||=
          AgentLog
            .where(name: PenAndInkSuggester.name, owner_type: User.name)
            .where(created_at: since..)
            .where.not(id: regression_log_ids)
            .order(:id)
            .map { |agent_log| LoggedRun.new(agent_log) }
            .select(&:llm_run?)
      end

      def regression_runs
        @regression_runs ||=
          AgentLog
            .where(name: PenAndInkSuggester.name, owner_type: User.name, id: regression_log_ids)
            .order(:id)
            .map { |agent_log| LoggedRun.new(agent_log) }
            .select(&:llm_run?)
      end

      def group_key(run)
        run.instruction.present? ? [run.user_id, run.normalised_instruction] : [run.log_id]
      end

      def sample(groups, target, source)
        queues =
          groups
            .group_by { |_key, group_runs| group_runs.first.user_id }
            .sort_by(&:first)
            .shuffle(random:)
            .map { |_, user_groups| user_groups.sort_by(&:first).shuffle(random:).map(&:last) }
        taken = Hash.new(0)
        cases = []

        while cases.size < target && queues.any?(&:any?)
          queues.each do |queue|
            break if cases.size >= target

            user_case = take_case(queue, taken, source)
            cases << user_case if user_case
          end
        end
        cases
      end

      def take_case(queue, taken, source)
        while (group = queue.shift)
          user_id = group.first.user_id
          if taken[user_id] >= per_user_cap
            queue.clear
            return
          end

          group
            .sort_by(&:log_id)
            .shuffle(random:)
            .each do |run|
              bench_case = reconstruct(run, source)
              next unless bench_case

              taken[user_id] += 1
              return bench_case
            end
        end
        nil
      end

      def reconstruct(run, source)
        user = User.find_by(id: run.user_id)
        return drop(run, "user_deleted") unless user

        snapshot = PenAndInkSuggestion::CollectionSnapshot.new(user, as_of: run.created_at)
        pen_ids = snapshot.pens.to_set(&:id)
        ink_ids = snapshot.inks.to_set(&:id)
        original = run.original
        if (original["pen_id"] && !pen_ids.include?(original["pen_id"])) ||
             (original["ink_id"] && !ink_ids.include?(original["ink_id"]))
          return drop(run, "target_missing")
        end

        fidelity = {
          "pens" => share(run.shown_pen_ids, pen_ids),
          "inks" => share(run.shown_ink_ids, ink_ids)
        }
        if fidelity.values.compact.any? { |value| value < min_fidelity }
          return drop(run, "state_not_rebuilt")
        end

        BenchCase.new(
          id: run.log_id.to_s,
          log_id: run.log_id,
          user_id: run.user_id,
          as_of: run.created_at,
          source:,
          split: split_for(run.user_id),
          tier: run.tier || (user.premium? ? "premium" : "free"),
          instruction: run.instruction,
          rejected_pairs: run.rejected_pairs,
          original:,
          fidelity:
        )
      end

      def share(shown_ids, current_ids)
        return if shown_ids.blank?

        (shown_ids.count { |id| current_ids.include?(id) } / shown_ids.size.to_f).round(4)
      end

      def split_for(user_id)
        Digest::SHA256.hexdigest("#{SPLIT_SALT}:#{user_id}").to_i(16).even? ? "dev" : "test"
      end

      def drop(run, reason)
        dropped[reason] << run.log_id
        nil
      end

      def dropped
        @dropped ||= Hash.new { |hash, reason| hash[reason] = [] }
      end

      def random
        @random ||= Random.new(seed)
      end
    end
  end
end
