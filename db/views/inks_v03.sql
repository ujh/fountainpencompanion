select
	count(*) as count,
    simplified_brand_name,
    (
      SELECT ci.simplified_line_name
      FROM collected_inks AS ci
      WHERE ci.simplified_brand_name = collected_inks.simplified_brand_name
        AND ci.simplified_ink_name = collected_inks.simplified_ink_name
      GROUP BY ci.simplified_line_name
      ORDER BY count(*) DESC
      LIMIT 1
    ) AS simplified_line_name,
    simplified_ink_name,
    (SELECT ci.ink_name
     FROM collected_inks as ci
     WHERE ci.simplified_brand_name = collected_inks.simplified_brand_name
       AND ci.simplified_ink_name = collected_inks.simplified_ink_name
     GROUP BY ci.ink_name
     ORDER BY count(*) DESC
     LIMIT 1
    ) AS popular_ink_name
from collected_inks
WHERE collected_inks.private = false
group by simplified_brand_name, simplified_ink_name
