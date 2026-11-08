module Bench
  module Clusterer
    class CaseExporter
      Export = Data.define(:cases)

      CHECKER_SQL = <<~SQL
        WITH logs AS (
          SELECT DISTINCT ON (al.owner_id, al.extra_data->>'action')
            al.id, al.owner_id, al.created_at, al.extra_data, al.transcript,
            mc.ignored, mc.macro_cluster_id, mac.created_at AS macro_created_at
          FROM agent_logs al
          JOIN micro_clusters mc ON mc.id = al.owner_id
          LEFT JOIN macro_clusters mac ON mac.id = mc.macro_cluster_id
          WHERE al.name = 'InkClusterer' AND al.owner_type = 'MicroCluster'
            AND al.extra_data->>'action' IN ('assign_to_cluster', 'ignore_ink', 'create_new_cluster')
            AND al.extra_data->>'follow_up_action' IN ('approve', 'reject')
            AND al.created_at >= :since AND al.created_at < :before
            AND NOT (al.id = ANY(CAST(:exclude_logs AS bigint[])))
            AND NOT (al.owner_id = ANY(CAST(:exclude_micro_clusters AS bigint[])))
            AND EXISTS (SELECT 1 FROM collected_inks ci WHERE ci.micro_cluster_id = mc.id)
          ORDER BY al.owner_id, al.extra_data->>'action', al.created_at DESC
        ),
        graded AS (
          SELECT logs.*,
            CASE extra_data->>'action'
              WHEN 'assign_to_cluster' THEN
                CASE WHEN macro_cluster_id = (extra_data->>'cluster_id')::bigint THEN 'approve'
                     WHEN ignored OR macro_cluster_id IS NOT NULL THEN 'reject' END
              WHEN 'ignore_ink' THEN
                CASE WHEN ignored THEN 'approve'
                     WHEN macro_cluster_id IS NOT NULL THEN 'reject' END
              WHEN 'create_new_cluster' THEN
                CASE WHEN macro_created_at >= created_at THEN 'approve'
                     WHEN ignored OR macro_cluster_id IS NOT NULL THEN 'reject' END
            END AS expected
          FROM logs
        ),
        ranked AS (
          SELECT graded.*,
            extra_data->>'follow_up_action' <> expected AS disputed,
            row_number() OVER (
              PARTITION BY extra_data->>'action', expected, extra_data->>'follow_up_action' <> expected
              ORDER BY md5(:seed || id::text)
            ) AS position
          FROM graded
          WHERE expected IS NOT NULL
        )
        SELECT id, owner_id, extra_data, transcript, expected, disputed
        FROM ranked
        WHERE position <= :per_group
        ORDER BY id
      SQL

      ROUND1_SQL = <<~SQL
        WITH firsts AS (
          SELECT mc.id, mc.ignored, mc.macro_cluster_id, mac.created_at AS macro_created_at,
            min(al.created_at) AS first_log_at
          FROM micro_clusters mc
          JOIN agent_logs al
            ON al.owner_type = 'MicroCluster' AND al.owner_id = mc.id AND al.name = 'InkClusterer'
          LEFT JOIN macro_clusters mac ON mac.id = mc.macro_cluster_id
          WHERE (mc.ignored OR mc.macro_cluster_id IS NOT NULL)
            AND NOT (mc.id = ANY(CAST(:exclude_micro_clusters AS bigint[])))
            AND EXISTS (SELECT 1 FROM collected_inks ci WHERE ci.micro_cluster_id = mc.id)
          GROUP BY mc.id, mac.created_at
          HAVING min(al.created_at) >= :since AND min(al.created_at) < :before
        ),
        graded AS (
          SELECT firsts.*,
            CASE WHEN ignored THEN 'ignore_ink'
                 WHEN macro_created_at < first_log_at THEN 'assign_to_cluster'
                 ELSE 'create_new_cluster' END AS expected
          FROM firsts
        ),
        ranked AS (
          SELECT graded.*,
            row_number() OVER (PARTITION BY expected ORDER BY md5(:seed || id::text)) AS position
          FROM graded
        )
        SELECT id, macro_cluster_id, expected FROM ranked WHERE position <= :per_group ORDER BY id
      SQL

      INKS_SQL = <<~SQL
        SELECT micro_cluster_id, brand_name, line_name, ink_name, color, kind, user_id
        FROM collected_inks
        WHERE micro_cluster_id = ANY(CAST(:micro_cluster_ids AS bigint[]))
        ORDER BY id
      SQL

      attr_accessor :source, :since, :before, :per_group, :round1_per_group, :seed, :excluded

      def initialize(source:, since:, before:, per_group:, round1_per_group:, seed:, excluded: [])
        self.source = source
        self.since = since
        self.before = before
        self.per_group = per_group
        self.round1_per_group = round1_per_group
        self.seed = seed
        self.excluded = excluded
      end

      def export
        checker_rows = source.rows(CHECKER_SQL, binds.merge(per_group:))
        round1_rows = source.rows(ROUND1_SQL, binds.merge(per_group: round1_per_group))
        inks =
          inks_by_micro_cluster(
            checker_rows.map { |row| row["owner_id"] } + round1_rows.map { |row| row["id"] }
          )

        Export.new(
          cases:
            checker_rows.map { |row| checker_case(row, inks) } +
              round1_rows.map { |row| round1_case(row, inks) }
        )
      end

      private

      def binds
        {
          since:,
          before:,
          seed: seed.to_s,
          exclude_logs: pg_array(excluded.map(&:log_id)),
          exclude_micro_clusters: pg_array(excluded.map(&:micro_cluster_id))
        }
      end

      def checker_case(row, inks)
        data = parse_json(row["extra_data"])
        kind = {
          "assign_to_cluster" => "assign",
          "ignore_ink" => "ignore",
          "create_new_cluster" => "create"
        }.fetch(data["action"])
        BenchCase.new(
          id: "#{kind}-#{row["id"]}",
          kind:,
          log_id: row["id"],
          micro_cluster_id: row["owner_id"],
          expected: row["expected"],
          cluster_id: data["cluster_id"]&.to_i,
          disputed: ActiveModel::Type::Boolean.new.cast(row["disputed"]),
          explanation: data["explanation_of_decision"],
          transcript: parse_json(row["transcript"]),
          inks: inks.fetch(row["owner_id"])
        )
      end

      def round1_case(row, inks)
        BenchCase.new(
          id: "round1-#{row["id"]}",
          kind: "round1",
          log_id: nil,
          micro_cluster_id: row["id"],
          expected: row["expected"],
          cluster_id: row["macro_cluster_id"],
          disputed: false,
          explanation: nil,
          transcript: nil,
          inks: inks.fetch(row["id"])
        )
      end

      def inks_by_micro_cluster(ids)
        source
          .rows(INKS_SQL, micro_cluster_ids: pg_array(ids))
          .group_by { |row| row.delete("micro_cluster_id") }
      end

      def parse_json(value)
        value.is_a?(String) ? JSON.parse(value) : value
      end

      def pg_array(ids)
        "{#{ids.compact.uniq.join(",")}}"
      end
    end
  end
end
