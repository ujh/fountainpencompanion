module Bench
  module Clusterer
    class Replayer
      class Committed < StandardError
      end

      attr_accessor :cases, :runs, :threads

      def initialize(cases:, runs: 1, threads: 1)
        self.cases = cases
        self.runs = runs
        self.threads = threads
      end

      def run
        queue = Queue.new
        cases.each { |bench_case| runs.times { |run| queue << [bench_case, run] } }
        results = []
        lock = Mutex.new
        Array
          .new(threads) do
            Thread.new do
              Sidekiq.testing!(:fake) do
                while (job = next_job(queue))
                  result = replay_in_own_connection(*job)
                  lock.synchronize do
                    results << result
                    yield result if block_given?
                  end
                end
              end
            end
          end
          .each(&:join)
        results.sort_by { |result| [result["case_id"], result["run"]] }
      end

      private

      def next_job(queue)
        queue.pop(true)
      rescue ThreadError
        nil
      end

      def replay_in_own_connection(bench_case, run)
        ActiveRecord::Base.connection_pool.with_connection do
          { "case_id" => bench_case.id, "run" => run }.merge(replay(bench_case))
        rescue Committed
          raise
        rescue StandardError => e
          {
            "case_id" => bench_case.id,
            "run" => run,
            "got" => "error",
            "error" => "#{e.class}: #{e.message}"
          }
        end
      end

      def replay(bench_case)
        if missing_cluster?(bench_case)
          return { "got" => "skipped", "error" => "target cluster missing" }
        end

        result = nil
        micro_cluster_id = nil
        ActiveRecord::Base.transaction(requires_new: true) do
          micro_cluster = build_micro_cluster(bench_case)
          micro_cluster_id = micro_cluster.id
          evidence = micro_cluster.clustering_evidence
          result = bench_case.round1? ? cluster(micro_cluster) : check(bench_case, micro_cluster)
          result["evidence"] = evidence
          raise ActiveRecord::Rollback
        end
        if MicroCluster.exists?(micro_cluster_id)
          raise Committed, "replay of #{bench_case.id} was committed"
        end

        result
      end

      def missing_cluster?(bench_case)
        needs_cluster = bench_case.kind == "assign" || bench_case.expected == "assign_to_cluster"
        needs_cluster && !MacroCluster.exists?(bench_case.cluster_id)
      end

      def build_micro_cluster(bench_case)
        micro_cluster =
          MicroCluster.create!(
            simplified_brand_name: "bench",
            simplified_ink_name: "bench-#{bench_case.id}"
          )
        users = users_for(bench_case.inks)
        bench_case.inks.each do |ink|
          CollectedInk.new(
            user: users.fetch(ink["user_id"]),
            micro_cluster:,
            brand_name: ink["brand_name"],
            line_name: ink["line_name"].to_s,
            ink_name: ink["ink_name"],
            color: ink["color"].to_s,
            kind: ink["kind"].presence || "bottle"
          ).save!(validate: false)
        end
        first = micro_cluster.collected_inks.reload.first
        names = first.slice(:simplified_brand_name, :simplified_line_name, :simplified_ink_name)
        MicroCluster
          .where(names)
          .where.not(id: micro_cluster.id)
          .update_all(simplified_ink_name: "bench-moved-#{bench_case.id}", macro_cluster_id: nil)
        micro_cluster.update!(names)
        CollectedInk.where(micro_cluster:).update_all(updated_at: 1.hour.ago)
        micro_cluster
      end

      def users_for(inks)
        ids = inks.map { |ink| ink["user_id"] }.uniq
        users = User.order(:id).limit(ids.size).to_a
        if users.size < ids.size
          raise ArgumentError, "the database needs at least #{ids.size} users"
        end

        ids.zip(users).to_h
      end

      def cluster(micro_cluster)
        clusterer = InkClusterer.new(micro_cluster.id)
        clusterer.perform
        data = clusterer.agent_log.reload.extra_data || {}
        {
          "got" => data["action"],
          "cluster_id" => data["cluster_id"],
          "explanation" => data["explanation_of_decision"]
        }
      end

      def check(bench_case, micro_cluster)
        agent_log =
          micro_cluster.agent_logs.create!(
            name: InkClusterer.name,
            transcript: bench_case.transcript || [],
            extra_data: {
              "action" => bench_case.action,
              "cluster_id" => bench_case.cluster_id,
              "explanation_of_decision" => bench_case.explanation
            }.compact
          )
        agent_log.waiting_for_approval!
        checker = bench_case.checker_class.new(agent_log.id)
        checker.perform
        data = checker.agent_log.reload.extra_data || {}
        { "got" => data["action"], "explanation" => data["explanation_of_decision"] }
      end
    end
  end
end
