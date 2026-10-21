require "json"
require "pg"
require "fileutils"
require "time"

# Shared helpers for the review-ignored-inks skill scripts. Plain Ruby plus the
# pg gem; the scripts run on the operator's machine, never inside the app.
module IgnoredInksReview
  ROOT = File.expand_path("../../../../..", __dir__)
  STATE_DIR = File.join(ROOT, "tmp", "ignored-inks-review")
  DATABASE_URL_FILE = File.join(STATE_DIR, "database_url")

  REVIEW_LOG_NAME = "IgnoredInkReview".freeze

  TRIAGE_VERDICTS = %w[keep_ignored research].freeze
  RESEARCH_VERDICTS = %w[keep_ignored assign create unignore unsure].freeze
  VERIFY_VERDICTS = %w[confirm reject].freeze
  MERGE_VERDICTS = %w[confirm reject].freeze
  CHANGE_VERDICTS = %w[assign create unignore].freeze
  CATEGORIES = %w[
    generic
    unidentified
    mix
    diy
    personal_brand
    incomplete
    not_ink
    placeholder
    other
  ].freeze

  # Mirrors MacroCluster#name (manual names win, line_name_is_empty drops the line).
  MACRO_NAME_SQL = <<~SQL.strip.freeze
    concat_ws(' ',
      nullif(coalesce(nullif(m.manual_brand_name, ''), m.brand_name), ''),
      case when m.line_name_is_empty then null
           else nullif(coalesce(nullif(m.manual_line_name, ''), m.line_name), '') end,
      nullif(coalesce(nullif(m.manual_ink_name, ''), m.ink_name), ''))
  SQL

  BATCH_SIZES = { "triage" => 150, "research" => 10, "verify" => 8, "merge" => 6 }.freeze
  STAGES = %w[triage research verify merge].freeze
  # Tables the review reads. The scripts refuse to run with a role that can
  # change any of them.
  WRITE_CHECK_TABLES = %w[micro_clusters macro_clusters collected_inks agent_logs].freeze
  WRITE_PRIVILEGES = %w[INSERT UPDATE DELETE TRUNCATE].freeze

  module_function

  def database_url
    url = ENV["FPC_READONLY_DATABASE_URL"]
    url = File.read(DATABASE_URL_FILE).strip if (url.nil? || url.empty?) &&
      File.exist?(DATABASE_URL_FILE)
    if url.nil? || url.empty?
      abort "No read-only database URL. Set FPC_READONLY_DATABASE_URL or write #{DATABASE_URL_FILE}."
    end
    url
  end

  def connection
    @connection ||=
      begin
        conn = PG.connect(database_url)
        refuse_writable_role(conn)
        conn.exec("SET SESSION CHARACTERISTICS AS TRANSACTION READ ONLY")
        conn.exec("SET statement_timeout = '120s'")
        conn
      end
  end

  def refuse_writable_role(conn)
    writable =
      conn.exec_params(
        <<~SQL,
        select t as table_name, p as privilege
        from unnest($1::text[]) t, unnest($2::text[]) p
        where has_table_privilege(t, p)
      SQL
        ["{#{WRITE_CHECK_TABLES.join(",")}}", "{#{WRITE_PRIVILEGES.join(",")}}"]
      ).to_a
    return if writable.empty?

    conn.close
    tables = writable.map { |w| w["table_name"] }.uniq.join(", ")
    abort "The database role can write to #{tables}. These scripts only run with a read-only role; " \
            "use a read-only connection URL."
  end

  def query(sql, params = [])
    connection.exec_params(sql, params).to_a
  end

  def json_column(value)
    value.nil? ? nil : JSON.parse(value)
  end

  # Brands the app itself never sends to the clusterer
  # (UpdateMicroCluster::IGNORED_BRANDS); their clusters are ignored by design.
  def blacklisted_brands
    source = File.read(File.join(ROOT, "app", "workers", "update_micro_cluster.rb"))
    source[/IGNORED_BRANDS\s*=\s*%w\[([^\]]*)\]/, 1].to_s.split
  end

  # Generic and placeholder brands (MicroCluster::PLACEHOLDER_BRAND_NAMES) that
  # never count as catalogued brands.
  def placeholder_brands
    source = File.read(File.join(ROOT, "app", "models", "micro_cluster.rb"))
    names = source[/PLACEHOLDER_BRAND_NAMES\s*=\s*%w\[([^\]]*)\]/, 1]
    if names.nil?
      warn "WARNING: MicroCluster::PLACEHOLDER_BRAND_NAMES not found; placeholder brands count as catalogued brands"
      return []
    end

    names.split
  end

  def run_dir(arg)
    abort "Usage: #{$PROGRAM_NAME} RUN_DIR ..." if arg.nil?
    dir = File.expand_path(arg)
    abort "Run dir #{dir} does not exist" unless Dir.exist?(dir)
    dir
  end

  def read_jsonl(path)
    return [] unless File.exist?(path)

    File.readlines(path, chomp: true).reject(&:empty?).map { |line| JSON.parse(line) }
  end

  def write_jsonl(path, rows)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, rows.map { |row| JSON.generate(row) }.join("\n") + "\n")
  end

  def read_json(path)
    JSON.parse(File.read(path))
  end

  def write_json(path, data)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(data) + "\n")
  end

  def candidates(dir)
    read_jsonl(File.join(dir, "candidates.jsonl"))
  end

  def pending(dir)
    read_jsonl(File.join(dir, "pending.jsonl"))
  end

  def batch_files(dir, stage)
    stage_dir = File.join(dir, stage)
    Dir.glob("in-*.jsonl", base: stage_dir).sort.map { |name| File.join(stage_dir, name) }
  end

  def output_for(input_path)
    input_path.sub(%r{/in-(\d+)\.jsonl\z}, '/out-\1.json')
  end

  # Results of a stage keyed by micro cluster id. Only batches with an output
  # file count; later batches win if an id was re-issued.
  def results(dir, stage)
    batch_files(dir, stage).each_with_object({}) do |input, acc|
      output = output_for(input)
      next unless File.exist?(output)

      read_json(output).each { |row| acc[row["id"]] = row }
    end
  end

  def overrides(dir)
    path = File.join(dir, "overrides.json")
    File.exist?(path) ? read_json(path).to_h { |row| [row["id"], row] } : {}
  end

  def short_name(names_row)
    [names_row["brand_name"], names_row["line_name"], names_row["ink_name"]].map(&:to_s)
      .map(&:strip)
      .reject(&:empty?)
      .join(" / ")
  end

  def display_name(candidate)
    short_name(candidate["names"].first)
  end

  # Details of the given macro clusters, in the order given. Ids that are not
  # integers or do not exist are left out.
  def macro_details(ids)
    ids = ids.grep(Integer)
    return [] if ids.empty?

    query(<<~SQL, ["{#{ids.join(",")}}"])
      select m.id, #{MACRO_NAME_SQL} as name, m.color, m.created_at::date as created, left(m.description, 200) as description,
        (select count(*) from collected_inks ci join micro_clusters o on o.id = ci.micro_cluster_id where o.macro_cluster_id = m.id) as inks,
        (select count(distinct ci.user_id) from collected_inks ci join micro_clusters o on o.id = ci.micro_cluster_id where o.macro_cluster_id = m.id) as users,
        (select json_agg(s.name) from (
           select concat_ws(' / ', ci.brand_name, nullif(ci.line_name, ''), ci.ink_name) as name
           from collected_inks ci join micro_clusters o on o.id = ci.micro_cluster_id
           where o.macro_cluster_id = m.id group by 1 order by count(*) desc limit 8) s) as synonyms
      from macro_clusters m where m.id = any($1::bigint[])
    SQL
      .map { |row| format_macro(row) }
      .sort_by { |m| ids.index(m["id"]) || ids.size }
  end

  def format_macro(row)
    {
      "id" => row["id"].to_i,
      "name" => row["name"],
      "color" => row["color"],
      "created" => row["created"],
      "inks" => row["inks"].to_i,
      "users" => row["users"].to_i,
      "synonyms" => IgnoredInksReview.json_column(row["synonyms"]) || [],
      "description" => row["description"]
    }
  end
end
