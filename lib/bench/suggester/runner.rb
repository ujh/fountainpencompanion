require "active_support/testing/time_helpers"

module Bench
  module Suggester
    class Runner
      include ActiveSupport::Testing::TimeHelpers

      BASELINE =
        lambda do |bench_case, user|
          BaselineSuggester.new(
            user,
            bench_case.instruction&.first(WidgetsController::MAX_EXTRA_USER_INPUT_LENGTH),
            bench_case.rejected_pairs,
            as_of: bench_case.as_of,
            tier: bench_case.tier
          )
        end

      BUDGET = "budget"
      UNPRICED = "unpriced"

      attr_accessor :cases, :seed, :max_usd, :build, :spent_usd, :stop_reason

      def initialize(cases:, seed: 1, max_usd: 5.0, build: BASELINE)
        self.cases = cases
        self.seed = seed
        self.max_usd = max_usd
        self.build = build
        self.spent_usd = 0.0
      end

      def run
        results = {}
        cases.each do |bench_case|
          if spent_usd >= max_usd
            self.stop_reason = BUDGET
            break
          end

          result = run_case(bench_case)
          next unless result

          results[bench_case.id] = result
          yield bench_case, result if block_given?
          if result["cost_usd"].nil?
            self.stop_reason = UNPRICED
            break
          end

          self.spent_usd += result["cost_usd"]
        end
        results
      end

      def case_seed(bench_case)
        Zlib.crc32("#{seed}:#{bench_case.id}")
      end

      private

      def run_case(bench_case)
        user = User.find_by(id: bench_case.user_id)
        return unless user

        result = nil
        ActiveRecord::Base.transaction do
          travel_to(bench_case.as_of) { result = replay(bench_case, user) }
          raise ActiveRecord::Rollback
        end
        result
      end

      def replay(bench_case, user)
        srand(case_seed(bench_case))
        suggester = build.call(bench_case, user)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        exception = perform(suggester)
        latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
        agent_log = suggester.agent_log.reload
        usages = [agent_log.usage, *agent_log.agent_logs.map(&:usage)]
        {
          "extra_data" => exception ? error_extra_data(exception) : agent_log.extra_data || {},
          "usages" => usages,
          "cost_usd" => Pricing.total_cost(usages),
          "latency_ms" => latency_ms,
          "seed" => case_seed(bench_case),
          "prompt_chars" => prompt_chars(agent_log)
        }
      end

      def error_extra_data(exception)
        {
          "message" => PenAndInkSuggester::ERROR_MESSAGE,
          "status" => "error",
          "error" => exception
        }
      end

      def prompt_chars(agent_log)
        agent_log
          .transcript
          .select { |entry| entry["role"].in?(%w[system user]) }
          .sum { |entry| entry["content"].to_s.length }
      end

      def perform(suggester)
        suggester.perform
        nil
      rescue RubyLLM::Error, Faraday::Error => e
        e.class.name
      end
    end
  end
end
