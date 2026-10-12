-- =============================================================================
-- The Lab · Where did Hurricane Sandy hit, and does the answer change
--           when we change the question?                       (~10 minutes)
-- =============================================================================
-- One script, three steps, one story:
--   Step 1  Types      Manhattan ZIP codes as real shapes (GEOGRAPHY).
--   Step 2  Functions  Counties near Manhattan, ranked two ways:
--                      by claim COUNT and by MEAN building payout.
--   Step 3  Surprise   Were these properties even in the flood zone?
--
-- The same script exists in Python (02_sandy_spatial.py) and as a notebook
-- with maps and charts (03_sandy_spatial.ipynb).
--
-- Data: real FEMA NFIP claims plus real ZIP and county boundaries, all from
-- the free "Snowflake Public Data (Free)" Marketplace listing.
--
-- Privacy note: FEMA rounds public claim coordinates, so we count claims by
-- the ZIP or county FEMA assigns. We never place an individual claim on a map.
-- This is descriptive history for one event, not a flood risk model.
-- =============================================================================

USE WAREHOUSE SDSC_WORKSHOP_WH;

-- Scaling: same SQL, 16x the compute, one line. Uncomment, rerun, compare the
-- query time in Query History. (Needs SDSC_WORKSHOP_WH_LARGE from 00.)
-- USE WAREHOUSE SDSC_WORKSHOP_WH_LARGE;

SET listing_db = 'SNOWFLAKE_PUBLIC_DATA_FREE';   -- <-- change if you renamed it
SET claims_tbl = $listing_db || '.PUBLIC_DATA_FREE.FEMA_NATIONAL_FLOOD_INSURANCE_PROGRAM_CLAIM_INDEX';
SET geo_chars  = $listing_db || '.PUBLIC_DATA_FREE.GEOGRAPHY_CHARACTERISTICS';
SET geo_index  = $listing_db || '.PUBLIC_DATA_FREE.GEOGRAPHY_INDEX';

-- The three knobs. Each one changes the story.
SET within_m   = 3000;    -- Step 1 <-- TRY: 6000
SET distance_m = 25000;   -- Step 2 <-- TRY: 75000
SET min_claims = 500;     -- Step 2 <-- TRY: 5000

-- =============================================================================
-- Step 1 · Types: which Manhattan ZIP codes filed the most Sandy claims?
-- =============================================================================
-- TO_GEOGRAPHY turns a ZIP boundary stored as WKT text into a real shape.
-- ST_AREA, ST_CENTROID and ST_DISTANCE then measure it on the Earth's surface,
-- in metres. GEOGRAPHY is spherical (WGS84); GEOMETRY is the planar option.

WITH manhattan_claims AS (
  SELECT zip_geo_id,
         COUNT(*)                                   AS claims,
         ROUND(AVG(amount_paid_on_building_claim))  AS mean_bldg_paid
  FROM IDENTIFIER($claims_tbl)
  WHERE flood_event = 'Hurricane Sandy'
    AND county_geo_id = 'geoId/36061'               -- Manhattan
  GROUP BY zip_geo_id
),
zip_shapes AS (
  SELECT geo_id, TO_GEOGRAPHY(value) AS geog
  FROM IDENTIFIER($geo_chars)
  WHERE relationship_type = 'coordinates_wkt'
    AND geo_id IN (SELECT zip_geo_id FROM manhattan_claims)
),
southern_tip AS (
  -- ZIP 10004: Battery Park, where the surge came ashore.
  SELECT ST_CENTROID(geog) AS pt FROM zip_shapes WHERE geo_id = 'zip/10004'
)
SELECT REPLACE(c.zip_geo_id, 'zip/', '')                          AS zip,
       c.claims,
       c.mean_bldg_paid,
       ROUND(ST_AREA(z.geog) / 1e6, 2)                             AS area_km2,
       ROUND(ST_DISTANCE(ST_CENTROID(z.geog), t.pt) / 1000, 1)     AS km_from_southern_tip,
       ST_DWITHIN(ST_CENTROID(z.geog), t.pt, $within_m)            AS near_southern_tip
FROM manhattan_claims c
JOIN zip_shapes z ON z.geo_id = c.zip_geo_id
CROSS JOIN southern_tip t
ORDER BY c.claims DESC
LIMIT 10;

-- Expected (snapshot 2026-10-11; the listing refreshes, so expect small drift):
--   ZIP   | CLAIMS | MEAN_BLDG_PAID | KM_FROM_SOUTHERN_TIP | NEAR (3 km)
--   10009 |     94 |         128165 |                  4.9 | FALSE  East Village
--   10013 |     80 |         242294 |                  3.1 | FALSE  Tribeca/SoHo
--   10038 |     74 |         268773 |                  2.1 | TRUE   Seaport
--   10011 |     62 |         239722 |                  5.5 | FALSE  Chelsea
--   10029 |     58 |         109056 |                 12.5 | FALSE  East Harlem
--   ... 10 rows. Only 10038 and 10004 are TRUE at 3 km.
--
-- Interpret: the ZIP with the most claims is not at the tip. East Harlem,
-- 12.5 km north, is fifth. The surge pushed up both rivers.
-- Your change: within_m = 6000. Five more ZIPs turn TRUE (10009, 10013, 10011,
-- 10014, 10010); East Harlem still doesn't. Distance alone doesn't explain it.

-- =============================================================================
-- Step 2 · Functions: zoom out to counties. Rank them two ways.
-- =============================================================================
-- TRY_TO_GEOGRAPHY turns county WKT into polygons (bad rows become NULL, not
-- errors). ST_DWITHIN keeps counties whose boundary is within distance_m of
-- Manhattan's. Then we rank the same counties by COUNT and by MEAN payout.
-- Mean paid excludes records with no payment; paid_missing shows how many.

WITH county_claims AS (
  SELECT county_geo_id,
         COUNT(*)                                        AS claim_records,
         COUNT(amount_paid_on_building_claim)            AS paid_denominator,
         COUNT(*) - COUNT(amount_paid_on_building_claim) AS paid_missing,
         AVG(amount_paid_on_building_claim)              AS mean_bldg_paid_usd
  FROM IDENTIFIER($claims_tbl)
  WHERE flood_event   = 'Hurricane Sandy'
    AND state_geo_id IN ('geoId/36', 'geoId/34')    -- New York, New Jersey
    AND county_geo_id IS NOT NULL
  GROUP BY county_geo_id
  HAVING COUNT(*) >= $min_claims
),
county_shapes AS (
  SELECT geo_id, TRY_TO_GEOGRAPHY(value) AS boundary
  FROM IDENTIFIER($geo_chars)
  WHERE relationship_type = 'coordinates_wkt'
    AND geo_id IN (SELECT county_geo_id FROM county_claims UNION SELECT 'geoId/36061')
  QUALIFY ROW_NUMBER() OVER (PARTITION BY geo_id
                             ORDER BY relationship_start_date DESC NULLS LAST) = 1
),
manhattan AS (
  SELECT boundary FROM county_shapes WHERE geo_id = 'geoId/36061'
),
nearby AS (
  SELECT c.*,
         ROUND(ST_DISTANCE(s.boundary, m.boundary) / 1000, 1) AS km_from_manhattan
  FROM county_claims c
  JOIN county_shapes s ON s.geo_id = c.county_geo_id
  CROSS JOIN manhattan m
  WHERE ST_DWITHIN(s.boundary, m.boundary, $distance_m)
)
SELECT g.geo_name                                     AS county,
       claim_records,
       paid_missing,
       ROUND(mean_bldg_paid_usd)                      AS mean_bldg_paid_usd,
       km_from_manhattan,
       RANK() OVER (ORDER BY claim_records DESC)      AS rank_by_count,
       RANK() OVER (ORDER BY mean_bldg_paid_usd DESC) AS rank_by_mean_paid
FROM nearby n
JOIN IDENTIFIER($geo_index) g ON g.geo_id = n.county_geo_id
ORDER BY rank_by_count;

-- Expected (distance_m = 25000, min_claims = 500, snapshot 2026-10-12). 10 rows:
--   COUNTY           | CLAIMS | MISSING | MEAN_PAID | KM   | BY_COUNT | BY_MEAN
--   Nassau County    |  26964 |    1086 |     67115 | 11.3 |        1 |       6
--   Monmouth County  |  10032 |     607 |     74362 | 18.2 |        2 |       4
--   Queens           |   7639 |     267 |     74836 |  0.0 |        3 |       3
--   Richmond County  |   4095 |      97 |     54333 |  4.1 |        4 |       8
--   Brooklyn         |   3561 |     161 |     81335 |  0.0 |        5 |       2
--   Hudson County    |   2327 |     393 |     59990 |  0.0 |        6 |       7
--   Bergen County    |   2072 |     159 |     51821 |  0.0 |        7 |       9
--   Middlesex County |    742 |      48 |     68370 | 17.0 |        8 |       5
--   Manhattan        |    668 |     223 |    236483 |  0.0 |        9 |       1
--   Bronx County     |    537 |     122 |     28623 |  0.0 |       10 |      10
--
--   The story flips: Manhattan is 9th by count but 1st by mean paid. Fewer,
--   much bigger buildings. And 223 of its 668 records have no payment.
--   Who's MISSING? Ocean County, NJ: 37,459 claims, the biggest of the event,
--     60.6 km away.
-- Your change: distance_m = 75000. Ocean County appears at #1 by count.
--   Then min_claims = 5000: Manhattan and Brooklyn drop out entirely.
-- Interpret: the area you draw and the metric you pick decide the answer.

-- =============================================================================
-- Step 3 · The surprise: were these properties even in the flood zone?
-- =============================================================================
-- POLICY_RATED_FLOOD_ZONE is the FEMA zone each policy was rated in at the
-- time of the loss. "Special Flood..." is FEMA's high-risk zone (A and V).

SELECT REPLACE(zip_geo_id, 'zip/', '')                              AS zip,
       COUNT(*)                                                     AS claims,
       COUNT_IF(NOT policy_rated_flood_zone ILIKE 'Special Flood%') AS outside_high_risk_zone,
       ROUND(100 * outside_high_risk_zone / claims)                 AS pct_outside
FROM IDENTIFIER($claims_tbl)
WHERE flood_event = 'Hurricane Sandy'
  AND county_geo_id = 'geoId/36061'
GROUP BY zip_geo_id
ORDER BY claims DESC
LIMIT 10;

-- Expected (snapshot 2026-10-12):
--   10009 East Village 94 claims, 31 outside (33%)
--   10029 East Harlem  58 claims, 29 outside (50%)
--   All of Manhattan: 188 of 668 claims (28%) came from outside the high-risk
--   zone, and were paid MORE on average ($265,319 vs $227,798).
-- Interpret: the flood map said these places were lower risk. The water
-- disagreed. That's why underwriting needs geography.
