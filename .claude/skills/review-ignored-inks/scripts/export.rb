# Exports every ignored micro cluster that still has inks into
# RUN_DIR/candidates.jsonl and picks the ones to review in this run into
# RUN_DIR/pending.jsonl (at most LIMIT, default 100, highest priority first).
#
#   ruby export.rb RUN_DIR [--limit N]
#
# A cluster is due for review when it has no IgnoredInkReview log yet, or when
# its latest one says it should be looked at again (see revisit_due?).
require_relative "lib/common"

UNSURE_RECHECK_DAYS = 180
# Users that must have added the ink since the last review before a
# keep_ignored verdict in a REVISIT_CATEGORIES category is looked at again.
REVISIT_USER_GROWTH = 2
# Categories where more users can change the answer. The others (mix, diy,
# placeholder, not_ink, generic) stay final.
REVISIT_CATEGORIES = %w[unidentified incomplete personal_brand other].freeze
# An ignore right after a rejected create is prioritised when this many users
# entered the ink, or the brand has this many catalogue inks.
REJECTED_CREATE_MIN_USERS = 3
REJECTED_CREATE_MIN_CATALOGUE_INKS = 3
# Date of the last clusterer prompt change. export.json and finalize.rb split
# clusters by whether their latest approved ignore came before or after it.
CLUSTERER_PROMPT_CHANGED_AT = "2026-10-21T11:51:47Z"

dir = IgnoredInksReview.run_dir(ARGV[0])
limit = 100
if (flag = ARGV.index("--limit"))
  limit = ARGV[flag + 1].to_s.match?(/\A[1-9]\d*\z/) ? ARGV[flag + 1].to_i : nil
  abort "Usage: export.rb RUN_DIR [--limit N] (N a positive number)" unless limit
end
macro_name = IgnoredInksReview::MACRO_NAME_SQL

blacklist = IgnoredInksReview.blacklisted_brands
placeholders = IgnoredInksReview.placeholder_brands
params = [
  IgnoredInksReview::REVIEW_LOG_NAME,
  "{#{blacklist.join(",")}}",
  "{#{placeholders.join(",")}}"
]
rows = IgnoredInksReview.query(<<~SQL, params)
  with ign as (
    select mc.* from micro_clusters mc
    where mc.ignored and exists (select 1 from collected_inks ci where ci.micro_cluster_id = mc.id)
      and not mc.simplified_brand_name = any($2::text[])
  ),
  brands as materialized (
    select b.brand, coalesce(i.ignored_clusters, 0) as ignored_clusters, coalesce(u.users, 0) as users,
      coalesce(c.catalogue_inks, 0) as catalogue_inks
    from (select distinct simplified_brand_name as brand from ign) b
    left join (select simplified_brand_name as brand, count(*) as ignored_clusters from ign group by 1) i
      on i.brand = b.brand
    left join (
      select mc.simplified_brand_name as brand, count(distinct ci.user_id) as users
      from micro_clusters mc join collected_inks ci on ci.micro_cluster_id = mc.id
      where mc.simplified_brand_name in (select simplified_brand_name from ign) group by 1) u on u.brand = b.brand
    left join (
      select simplified_brand_name as brand, count(distinct macro_cluster_id) as catalogue_inks from micro_clusters
      where not ignored and macro_cluster_id is not null and not simplified_brand_name = any($3::text[])
      group by 1) c on c.brand = b.brand
  )
  select
    ign.id,
    ign.simplified_brand_name, ign.simplified_line_name, ign.simplified_ink_name,
    ign.created_at, ign.updated_at, ign.macro_cluster_id,
    (select count(distinct user_id) from collected_inks where micro_cluster_id = ign.id) as users,
    (select count(*) from collected_inks where micro_cluster_id = ign.id) as inks,
    (select json_agg(n) from (
       select ci.brand_name, ci.line_name, ci.ink_name, count(*) as inks, count(distinct ci.user_id) as users
       from collected_inks ci where ci.micro_cluster_id = ign.id
       group by 1, 2, 3 order by count(*) desc limit 10) n) as names,
    (select json_agg(c.color) from (
       select ci.color from collected_inks ci
       where ci.micro_cluster_id = ign.id and ci.color <> ''
       group by ci.color order by count(*) desc limit 5) c) as colors,
    (select row_to_json(a) from (
       select m.id, #{macro_name} as name,
         (select count(*) from micro_clusters o where o.macro_cluster_id = m.id and o.id <> ign.id) as other_micro_clusters
       from macro_clusters m where m.id = ign.macro_cluster_id) a) as assigned_macro,
    not ign.simplified_brand_name = any($3::text[]) and exists (
      select 1 from micro_clusters o
      where o.macro_cluster_id is not null and not o.ignored and o.simplified_brand_name = ign.simplified_brand_name
    ) as brand_known,
    (select json_agg(x) from (
       select distinct m.id, #{macro_name} as name
       from micro_clusters o join macro_clusters m on m.id = o.macro_cluster_id
       where o.id <> ign.id and not o.ignored
         and o.simplified_brand_name = ign.simplified_brand_name
         and o.simplified_ink_name = ign.simplified_ink_name
       limit 5) x) as same_brand_and_ink,
    (select json_agg(x) from (
       select distinct m.id, #{macro_name} as name
       from micro_clusters o join macro_clusters m on m.id = o.macro_cluster_id
       where length(ign.simplified_ink_name) >= 6 and not o.ignored
         and o.simplified_ink_name = ign.simplified_ink_name
         and o.simplified_brand_name <> ign.simplified_brand_name
       limit 5) x) as same_ink_other_brand,
    (select json_agg(l order by l.id desc) from (
       select al.id, al.created_at::date as created, al.state, al.agent_approved,
         al.extra_data->>'action' as action,
         al.extra_data->>'cluster_id' as cluster_id,
         left(al.extra_data->>'explanation_of_decision', 400) as explanation,
         al.extra_data->>'follow_up_action' as follow_up_action,
         left(al.extra_data->>'follow_up_action_explanation', 400) as follow_up_explanation,
         left(al.extra_data->>'manual_rejection_note', 400) as manual_rejection_note
       from agent_logs al
       where al.owner_type = 'MicroCluster' and al.owner_id = ign.id and al.name = 'InkClusterer'
       order by al.id desc limit 5) l) as clusterer_logs,
    (select to_char(max(al.created_at), 'YYYY-MM-DD"T"HH24:MI:SS"Z"') from agent_logs al
     where al.owner_type = 'MicroCluster' and al.owner_id = ign.id and al.name = 'InkClusterer'
       and al.state = 'approved' and al.extra_data->>'action' = 'ignore_ink') as last_ignore_at,
    (select json_agg(r order by r.id desc) from (
       select al.id, al.created_at, al.extra_data->>'action' as action, al.extra_data->>'category' as category,
         (al.extra_data->>'reviewed_users')::int as reviewed_users,
         al.extra_data->>'run_id' as run_id
       from agent_logs al
       where al.owner_type = 'MicroCluster' and al.owner_id = ign.id and al.name = $1) r) as reviews
    , (select row_to_json(x) from (select ignored_clusters, users, catalogue_inks from brands where brands.brand = ign.simplified_brand_name) x) as brand_stats
  from ign
  order by ign.id
SQL

candidates =
  rows.map do |row|
    {
      "id" => row["id"].to_i,
      "simplified" => [
        row["simplified_brand_name"],
        row["simplified_line_name"],
        row["simplified_ink_name"]
      ],
      "created_at" => row["created_at"][0, 10],
      "updated_at" => row["updated_at"][0, 10],
      "users" => row["users"].to_i,
      "inks" => row["inks"].to_i,
      "names" => IgnoredInksReview.json_column(row["names"]),
      "colors" => IgnoredInksReview.json_column(row["colors"]) || [],
      "assigned_macro" => IgnoredInksReview.json_column(row["assigned_macro"]),
      "brand_known" => row["brand_known"] == "t",
      "brand_stats" => IgnoredInksReview.json_column(row["brand_stats"]),
      "same_brand_and_ink" => IgnoredInksReview.json_column(row["same_brand_and_ink"]) || [],
      "same_ink_other_brand" => IgnoredInksReview.json_column(row["same_ink_other_brand"]) || [],
      "clusterer_logs" => IgnoredInksReview.json_column(row["clusterer_logs"]) || [],
      "last_ignore_at" => row["last_ignore_at"],
      "reviews" => IgnoredInksReview.json_column(row["reviews"]) || []
    }
  end

# The clusterer's newest approved ignore came right after its create was
# rejected, for an ink several users entered or of a brand the catalogue knows.
def ignored_after_rejected_create?(candidate, placeholders)
  return false if placeholders.include?(candidate["simplified"][0])

  logs = candidate["clusterer_logs"]
  index = logs.index { |log| log["action"] == "ignore_ink" && log["state"] == "approved" }
  previous = index && logs[index + 1]
  unless previous && previous["action"] == "create_new_cluster" && previous["state"] == "rejected"
    return false
  end

  candidate["users"] >= REJECTED_CREATE_MIN_USERS ||
    candidate.dig("brand_stats", "catalogue_inks").to_i >= REJECTED_CREATE_MIN_CATALOGUE_INKS
end

# "after" or "before" the last clusterer prompt change, or "none" when no
# approved clusterer ignore exists (e.g. an admin ignored it directly).
def prompt_change_side(candidate)
  return "none" unless candidate["last_ignore_at"]

  if Time.iso8601(candidate["last_ignore_at"]) >= Time.iso8601(CLUSTERER_PROMPT_CHANGED_AT)
    "after"
  else
    "before"
  end
end

def revisit_due?(candidate, latest)
  growth = candidate["users"] - latest["reviewed_users"].to_i
  case latest["action"]
  when "keep_ignored"
    REVISIT_CATEGORIES.include?(latest["category"]) && growth >= REVISIT_USER_GROWTH
  when "unsure"
    growth.positive? ||
      Time.parse(latest["created_at"]) < Time.now - UNSURE_RECHECK_DAYS * 24 * 3600
  else
    # A change was applied, yet the cluster is ignored again.
    true
  end
end

def due?(candidate)
  latest = candidate["reviews"].first
  latest.nil? || revisit_due?(candidate, latest)
end

def priority(candidate, placeholders)
  [
    placeholders.include?(candidate["simplified"][0]) ? 1 : 0,
    candidate["assigned_macro"] ? 0 : 1,
    candidate["ignored_after_rejected_create"] ? 0 : 1,
    candidate["reviews"].any? ? 0 : 1,
    -candidate["users"],
    candidate["same_brand_and_ink"].any? ? 0 : 1,
    -Date.parse(candidate["updated_at"]).jd,
    candidate["id"]
  ]
end

candidates.each do |candidate|
  candidate["ignored_after_rejected_create"] = ignored_after_rejected_create?(
    candidate,
    placeholders
  )
  candidate["ignored_vs_prompt_change"] = prompt_change_side(candidate)
end
due = candidates.select { |candidate| due?(candidate) }
pending = due.sort_by { |candidate| priority(candidate, placeholders) }.first(limit)

IgnoredInksReview.write_jsonl(File.join(dir, "candidates.jsonl"), candidates)
IgnoredInksReview.write_jsonl(File.join(dir, "pending.jsonl"), pending)
IgnoredInksReview.write_json(
  File.join(dir, "export.json"),
  {
    "exported_at" => Time.now.utc.iso8601,
    "excluded_brands" => blacklist,
    "placeholder_brands" => placeholders.size,
    "candidates" => candidates.size,
    "due" => due.size,
    "pending" => pending.size,
    "never_reviewed" => candidates.count { |c| c["reviews"].empty? },
    "ignored_but_assigned" => pending.count { |c| c["assigned_macro"] },
    "ignored_after_rejected_create" => pending.count { |c| c["ignored_after_rejected_create"] },
    "ignored_after_rejected_create_due" => due.count { |c| c["ignored_after_rejected_create"] },
    "multi_user" => pending.count { |c| c["users"] > 1 },
    "clusterer_prompt_changed_at" => CLUSTERER_PROMPT_CHANGED_AT,
    "latest_ignore_vs_prompt_change" => {
      "due" => due.map { |c| c["ignored_vs_prompt_change"] }.tally,
      "pending" => pending.map { |c| c["ignored_vs_prompt_change"] }.tally
    }
  }
)
puts File.read(File.join(dir, "export.json"))
