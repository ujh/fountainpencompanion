SELECT
  micro_clusters.macro_cluster_id,
  count(collected_inks.id) AS public_collected_inks_count
FROM collected_inks
JOIN micro_clusters ON micro_clusters.id = collected_inks.micro_cluster_id
WHERE collected_inks.private = false
  AND micro_clusters.macro_cluster_id IS NOT NULL
GROUP BY micro_clusters.macro_cluster_id
