-- Values that only differ in case or surrounding whitespace are merged and
-- shown with their most common spelling. Models are grouped per brand so that
-- they can be filtered by it.
SELECT
  'brand' AS field,
  lower(trim(brand)) AS brand_key,
  lower(trim(brand)) AS value_key,
  mode() WITHIN GROUP (ORDER BY trim(brand)) AS value,
  count(DISTINCT user_id) AS popularity
FROM collected_pens
WHERE trim(brand) <> ''
GROUP BY lower(trim(brand))

UNION ALL

SELECT
  'model' AS field,
  lower(trim(brand)) AS brand_key,
  lower(trim(model)) AS value_key,
  mode() WITHIN GROUP (ORDER BY trim(model)) AS value,
  count(DISTINCT user_id) AS popularity
FROM collected_pens
WHERE trim(model) <> ''
GROUP BY lower(trim(brand)), lower(trim(model))
