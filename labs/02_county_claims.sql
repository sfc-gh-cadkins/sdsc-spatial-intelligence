-- =============================================================================
-- Lab B · Find a historical concentration           (pillars 2 + 3 · 5 min)
-- =============================================================================
-- Question: Which counties near Manhattan recorded the most Hurricane Sandy
-- flood claims?
--
-- Data: real FEMA NFIP claims and real county boundaries, both from the free
-- "Snowflake Public Data (Free)" Marketplace listing. Nothing is made up.
--
-- Privacy note: FEMA rounds public claim coordinates, so we count claims by
-- the county FEMA assigns, then use the real county boundaries for the
-- spatial step. We never place an individual claim on the map.
--
-- What the spatial step does: it keeps every county whose boundary comes
-- within distance_m of Manhattan's boundary. Totals are whole-county totals.
-- =============================================================================

USE WAREHOUSE SDSC_WORKSHOP_WH;

SET listing_db = 'SNOWFLAKE_PUBLIC_DATA_FREE';   -- <-- change if you renamed it
SET claims_tbl = $listing_db || '.PUBLIC_DATA_FREE.FEMA_NATIONAL_FLOOD_INSURANCE_PROGRAM_CLAIM_INDEX';
SET geo_chars  = $listing_db || '.PUBLIC_DATA_FREE.GEOGRAPHY_CHARACTERISTICS';
SET geo_index  = $listing_db || '.PUBLIC_DATA_FREE.GEOGRAPHY_INDEX';
SET distance_m = 25000;   -- <-- TRY: change to 75000

WITH county_claims AS (
  -- 1. Count Sandy claims in New York and New Jersey by county.
  SELECT county_geo_id,
         COUNT(*)                              AS claim_records,
         COUNT(amount_paid_on_building_claim)  AS records_with_bldg_payment,
         SUM(amount_paid_on_building_claim)    AS bldg_paid_usd
  FROM IDENTIFIER($claims_tbl)
  WHERE flood_event   = 'Hurricane Sandy'
    AND state_geo_id IN ('geoId/36', 'geoId/34')    -- New York, New Jersey
    AND county_geo_id IS NOT NULL
  GROUP BY county_geo_id
),
county_shapes AS (
  -- 2. One real boundary per county, turned from WKT text into GEOGRAPHY.
  SELECT geo_id, TRY_TO_GEOGRAPHY(value) AS boundary
  FROM IDENTIFIER($geo_chars)
  WHERE relationship_type = 'coordinates_wkt'
    AND geo_id IN (SELECT county_geo_id FROM county_claims)
  QUALIFY ROW_NUMBER() OVER (PARTITION BY geo_id
                             ORDER BY relationship_start_date DESC NULLS LAST) = 1
),
manhattan AS (
  -- 3. Manhattan (New York County) is our anchor.
  SELECT boundary FROM county_shapes WHERE geo_id = 'geoId/36061'
)
-- 4. Join on the county ID, then keep counties within distance_m of Manhattan.
SELECT g.geo_name                                          AS county,
       c.claim_records,
       c.records_with_bldg_payment,
       ROUND(c.bldg_paid_usd)                              AS bldg_paid_usd,
       ROUND(ST_DISTANCE(s.boundary, m.boundary) / 1000, 1) AS km_from_manhattan
FROM county_claims  c
JOIN county_shapes  s ON s.geo_id = c.county_geo_id
JOIN IDENTIFIER($geo_index) g ON g.geo_id = c.county_geo_id
CROSS JOIN manhattan m
WHERE ST_DWITHIN(s.boundary, m.boundary, $distance_m)
ORDER BY c.claim_records DESC;

-- Expected (snapshot 2026-10-11; the listing refreshes, so expect small drift):
--   15 counties. Top rows by claim_records:
--     Nassau County   26,964  |  Monmouth County 10,032  |  Queens          7,639
--     Richmond County  4,095  |  Brooklyn         3,561  |  Hudson County   2,327
--   Manhattan itself is 10th with 668 claims.
--
--   Notice who is MISSING: Ocean County, NJ, the hardest-hit county of the
--   whole event with 37,459 claim records. It's 60.6 km from Manhattan.
--   The distance you choose decides the answer you get.
--
-- Your change: set distance_m to 75000 and rerun. Ocean County appears at #1.
--
-- Interpret: the shared dataset became part of the analysis, and geography
-- became a joinable dimension, not a screenshot.
