-- =============================================================================
-- Lab B · Find a historical concentration           (pillars 2 + 3 · 5 min)
-- =============================================================================
-- Question: Which counties in our study area recorded the most Hurricane Sandy
-- flood claims?
--
-- Data: FEMA NFIP redacted claims + county boundaries, both from the free
-- "Snowflake Public Data (Free)" Marketplace listing. No ETL, no loading.
--
-- IMPORTANT DATA CAVEAT
--   FEMA truncates public claim latitude/longitude to ONE decimal place
--   (~11 km) to protect policyholder privacy, and recommends county or census
--   tract fields for aggregation. So we aggregate by the source COUNTY_GEO_ID,
--   then use real county boundary polygons for the spatial step.
--   We never place individual claims from their coordinates.
--
-- What the spatial predicate does here: it selects COUNTIES whose boundary
-- intersects a study-area rectangle. Totals are whole-county totals — not
-- "claims inside the rectangle".
-- =============================================================================

USE WAREHOUSE SDSC_WORKSHOP_WH;

SET listing_db = 'SNOWFLAKE_PUBLIC_DATA_FREE';   -- <-- change if you renamed it
SET claims_tbl = $listing_db || '.PUBLIC_DATA_FREE.FEMA_NATIONAL_FLOOD_INSURANCE_PROGRAM_CLAIM_INDEX';
SET geo_chars  = $listing_db || '.PUBLIC_DATA_FREE.GEOGRAPHY_CHARACTERISTICS';
SET geo_index  = $listing_db || '.PUBLIC_DATA_FREE.GEOGRAPHY_INDEX';

WITH study_area AS (
  -- Synthetic rectangle covering New York Harbor and surrounding counties.
  SELECT TO_GEOGRAPHY(
    'POLYGON((-74.30 40.45, -73.40 40.45, -73.40 40.95, -74.30 40.95, -74.30 40.45))'
  ) AS geog
),
county_claims AS (
  -- 1. Aggregate claim records by the source county identifier.
  SELECT county_geo_id,
         COUNT(*)                              AS claim_records,
         COUNT(amount_paid_on_building_claim)  AS records_with_bldg_payment,
         SUM(amount_paid_on_building_claim)    AS bldg_paid_usd
  FROM IDENTIFIER($claims_tbl)
  WHERE flood_event   = 'Hurricane Sandy'           -- event label from FEMA
    AND state_geo_id IN ('geoId/36', 'geoId/34')    -- New York, New Jersey
    AND county_geo_id IS NOT NULL
  GROUP BY county_geo_id
),
county_shapes AS (
  -- 2. One boundary per county, converted from WKT to native GEOGRAPHY.
  SELECT geo_id, TRY_TO_GEOGRAPHY(value) AS boundary
  FROM IDENTIFIER($geo_chars)
  WHERE relationship_type = 'coordinates_wkt'
    AND geo_id IN (SELECT county_geo_id FROM county_claims)
  QUALIFY ROW_NUMBER() OVER (PARTITION BY geo_id
                             ORDER BY relationship_start_date DESC NULLS LAST) = 1
)
-- 3. Join on the identifier, then filter spatially.
SELECT g.geo_name                       AS county,
       c.county_geo_id,
       c.claim_records,
       c.records_with_bldg_payment,
       ROUND(c.bldg_paid_usd)           AS bldg_paid_usd
FROM county_claims  c
JOIN county_shapes  s ON s.geo_id = c.county_geo_id
JOIN IDENTIFIER($geo_index) g ON g.geo_id = c.county_geo_id
CROSS JOIN study_area a
WHERE ST_INTERSECTS(s.boundary, a.geog)
ORDER BY c.claim_records DESC;

-- Expected (snapshot 2026-10-09 — the listing refreshes, so expect small drift):
--   16 counties. Top rows by claim_records:
--     Nassau County   26,964  |  Suffolk County 13,167  |  Monmouth County 10,032
--     Queens           7,639  |  Richmond County 4,095  |  Brooklyn         3,561
--     Hudson County    2,327  |  Bergen County   2,072  |  ...
--
--   Notice who is MISSING: Ocean County, NJ — the single largest county in the
--   whole event with 37,459 claim records. Its boundary sits south of 40.45.
--   The study area you draw decides the answer you get.
--
--   Reconciliation: 132,388 Sandy claim records in NY + NJ; 141 have no
--   county_geo_id and are excluded before the join.
--
-- Your change: move the rectangle's southern edge from 40.45 to 39.70
-- (replace all THREE 40.45 values in the POLYGON). Ocean County now appears at #1
-- with 37,459 claim records.
--
-- Interpret: the shared dataset became part of the analysis, and geography
-- became a joinable dimension — not a screenshot.
