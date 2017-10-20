SELECT
  simplified_brand_name,
  simplified_line_name,
  (
    SELECT line_name FROM collected_inks AS ci
    WHERE ci.simplified_brand_name = collected_inks.simplified_brand_name
      AND ci.simplified_line_name = collected_inks.simplified_line_name
    GROUP BY ci.line_name
    ORDER BY count(*) DESC
    LIMIT 1
  ) AS popular_line_name
FROM collected_inks
WHERE collected_inks.private = false
GROUP BY simplified_brand_name, simplified_line_name
