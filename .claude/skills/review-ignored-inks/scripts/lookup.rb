# Read-only lookups for research and verification subagents. Prints JSON.
#
#   ruby lookup.rb neighbours MICRO_CLUSTER_ID...   nearest macro clusters and ignored micro clusters by embedding
#   ruby lookup.rb search "ink name" [--brand "brand"]  macro clusters and ignored micro clusters by name
#   ruby lookup.rb macro MACRO_CLUSTER_ID...        details of macro clusters (names, synonyms, colour, users)
require_relative "lib/common"

def simplify(text)
  text.to_s.downcase.gsub(/[&+]/, "and").gsub(/[^\p{Alnum}]/, "")
end

def ignored_micro_rows(sql_where, params)
  IgnoredInksReview
    .query(<<~SQL, params)
    select mi.id, (select count(distinct user_id) from collected_inks where micro_cluster_id = mi.id) as users,
      (select json_agg(distinct concat_ws(' / ', ci.brand_name, nullif(ci.line_name, ''), ci.ink_name))
       from collected_inks ci where ci.micro_cluster_id = mi.id) as names
    from micro_clusters mi
    where mi.ignored and exists (select 1 from collected_inks where micro_cluster_id = mi.id) and #{sql_where}
    limit 15
  SQL
    .map do |r|
      {
        "id" => r["id"].to_i,
        "users" => r["users"].to_i,
        "names" => IgnoredInksReview.json_column(r["names"])
      }
    end
end

command, *args = ARGV
result =
  case command
  when "neighbours"
    IgnoredInksReview.connection.exec("SET hnsw.ef_search = 200")
    args
      .map(&:to_i)
      .map do |id|
        macros = IgnoredInksReview.query(<<~SQL, [id])
          select me.owner_id as id, round((me.embedding <=> e.embedding)::numeric, 3) as distance
          from ink_embeddings e, ink_embeddings me
          where e.owner_type = 'MicroCluster' and e.owner_id = $1 and me.owner_type = 'MacroCluster'
          order by me.embedding <=> e.embedding limit 8
        SQL
        distances = macros.to_h { |r| [r["id"].to_i, r["distance"].to_f] }
        micros = IgnoredInksReview.query(<<~SQL, [id])
          select me.owner_id as id, round((me.embedding <=> e.embedding)::numeric, 3) as distance
          from ink_embeddings e, ink_embeddings me join micro_clusters mi on mi.id = me.owner_id
          where e.owner_type = 'MicroCluster' and e.owner_id = $1 and me.owner_type = 'MicroCluster'
            and me.owner_id <> $1 and mi.ignored
          order by me.embedding <=> e.embedding limit 6
        SQL
        micro_distances = micros.to_h { |r| [r["id"].to_i, r["distance"].to_f] }
        ignored =
          (
            if micro_distances.empty?
              []
            else
              ignored_micro_rows(
                "mi.id = any($1::bigint[])",
                ["{#{micro_distances.keys.join(",")}}"]
              )
            end
          )
        {
          "id" => id,
          "macro_clusters" =>
            IgnoredInksReview
              .macro_details(distances.keys)
              .map { |m| m.merge("distance" => distances[m["id"]]) }
              .sort_by { |m| m["distance"] },
          "ignored_micro_clusters" =>
            ignored
              .map { |m| m.merge("distance" => micro_distances[m["id"]]) }
              .sort_by { |m| m["distance"] }
        }
      end
  when "search"
    text = args[0] or abort "search needs a text"
    brand = args.index("--brand") && args[args.index("--brand") + 1]
    ink = simplify(text)
    brand_clause = brand ? "and o.simplified_brand_name like '%' || $2 || '%'" : ""
    params = brand ? [ink, simplify(brand)] : [ink]
    macro_ids = IgnoredInksReview.query(<<~SQL, params).map { |r| r["macro_cluster_id"].to_i }
        select o.macro_cluster_id, max(similarity(o.simplified_ink_name, $1)) as score
        from micro_clusters o
        where o.macro_cluster_id is not null and not o.ignored
          and (o.simplified_ink_name like '%' || $1 || '%' or similarity(o.simplified_ink_name, $1) > 0.45) #{brand_clause}
        group by 1 order by 2 desc limit 15
      SQL
    {
      "query" => {
        "ink" => ink,
        "brand" => brand && simplify(brand)
      },
      "macro_clusters" => IgnoredInksReview.macro_details(macro_ids),
      "ignored_micro_clusters" =>
        ignored_micro_rows(
          "(mi.simplified_ink_name like '%' || $1 || '%' or similarity(mi.simplified_ink_name, $1) > 0.45)" +
            brand_clause.sub("o.", "mi."),
          params
        )
    }
  when "macro"
    IgnoredInksReview.macro_details(args.map(&:to_i))
  else
    abort "Usage: lookup.rb neighbours ID... | search TEXT [--brand BRAND] | macro ID..."
  end

puts JSON.pretty_generate(result)
