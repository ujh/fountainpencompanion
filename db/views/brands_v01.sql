SELECT
  simplified_brand_name,
  (select brand_name from collected_inks as ci
     	where ci.simplified_brand_name = collected_inks.simplified_brand_name
     	group by ci.brand_name order by count(*) desc limit 1
  ) as popular_name
FROM "collected_inks"
GROUP BY "collected_inks"."simplified_brand_name"
