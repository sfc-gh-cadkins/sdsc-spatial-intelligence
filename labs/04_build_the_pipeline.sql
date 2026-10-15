-- =============================================================================
-- 04 · Build the pipeline
-- =============================================================================
-- Question: how does a one-off query become something a team can use every day?
--
-- This file turns Steps 2 and 3 of the lab into two permanent views in your own account:
--   RAW.NFIP_CLAIMS_SANDY_NYNJ       the Sandy claims for NY and NJ (a filter)
--   ANALYTICS.SANDY_COUNTY_CLAIMS    claims by county, with county boundaries
--
-- Both are views over the Marketplace share, so nothing is copied and every
-- query reads the current data. The county view is the one object a map tool
-- (such as CARTO) or an AI agent reads.
--
-- Runs on a trial account. Creates one database, SDSC_WORKSHOP.
-- If you renamed the listing database, replace SNOWFLAKE_PUBLIC_DATA_FREE
-- below (views can't read session variables).
-- =============================================================================

USE WAREHOUSE SDSC_WORKSHOP_WH;

CREATE DATABASE IF NOT EXISTS SDSC_WORKSHOP;
CREATE SCHEMA IF NOT EXISTS SDSC_WORKSHOP.RAW;
CREATE SCHEMA IF NOT EXISTS SDSC_WORKSHOP.ANALYTICS;

-- Layer 1: the same filter you used in the labs, as a view.
CREATE OR REPLACE VIEW SDSC_WORKSHOP.RAW.NFIP_CLAIMS_SANDY_NYNJ
  COMMENT = 'Hurricane Sandy NFIP claims, NY and NJ, from Snowflake Public Data (Free).'
AS
SELECT *
FROM SNOWFLAKE_PUBLIC_DATA_FREE.PUBLIC_DATA_FREE.FEMA_NATIONAL_FLOOD_INSURANCE_PROGRAM_CLAIM_INDEX
WHERE flood_event = 'Hurricane Sandy'
  AND state_geo_id IN ('geoId/36', 'geoId/34');

-- Layer 2: Steps 2 and 3 made permanent. One row per county, with its boundary.
CREATE OR REPLACE VIEW SDSC_WORKSHOP.ANALYTICS.SANDY_COUNTY_CLAIMS
  COMMENT = 'Hurricane Sandy NFIP claims by county (NY and NJ) with simplified boundaries.'
AS
WITH counties AS (
  SELECT geo_id, geo_name
  FROM SNOWFLAKE_PUBLIC_DATA_FREE.PUBLIC_DATA_FREE.GEOGRAPHY_INDEX
  WHERE level = 'County'
    AND (STARTSWITH(geo_id, 'geoId/36') OR STARTSWITH(geo_id, 'geoId/34'))
),
claims AS (
  SELECT county_geo_id,
         COUNT(*)                            AS claim_records,
         COUNT(amount_paid_on_building_claim) AS paid_denominator,
         SUM(amount_paid_on_building_claim)   AS bldg_paid_usd,
         AVG(amount_paid_on_building_claim)   AS mean_bldg_paid_usd
  FROM SDSC_WORKSHOP.RAW.NFIP_CLAIMS_SANDY_NYNJ
  WHERE county_geo_id IS NOT NULL
  GROUP BY county_geo_id
),
shapes AS (
  SELECT geo_id, TRY_TO_GEOGRAPHY(value) AS boundary
  FROM SNOWFLAKE_PUBLIC_DATA_FREE.PUBLIC_DATA_FREE.GEOGRAPHY_CHARACTERISTICS
  WHERE relationship_type = 'coordinates_wkt'
    AND geo_id IN (SELECT geo_id FROM counties)
  QUALIFY ROW_NUMBER() OVER (PARTITION BY geo_id ORDER BY relationship_start_date DESC NULLS LAST) = 1
)
SELECT c.geo_id                                   AS county_geo_id,
       c.geo_name                                 AS county,
       IFF(STARTSWITH(c.geo_id, 'geoId/36'), 'NY', 'NJ') AS state,
       COALESCE(cl.claim_records, 0)              AS claim_records,
       COALESCE(cl.paid_denominator, 0)           AS paid_denominator,
       cl.bldg_paid_usd,
       ROUND(cl.mean_bldg_paid_usd)               AS mean_bldg_paid_usd,
       ST_SIMPLIFY(s.boundary, 250)               AS boundary
FROM counties c
JOIN shapes s ON s.geo_id = c.geo_id
LEFT JOIN claims cl ON cl.county_geo_id = c.geo_id;

-- Check it: the five counties with the most claims.
SELECT county, state, claim_records, paid_denominator, mean_bldg_paid_usd
FROM SDSC_WORKSHOP.ANALYTICS.SANDY_COUNTY_CLAIMS
ORDER BY claim_records DESC
LIMIT 5;

-- Expected (5 rows):
-- | COUNTY          | STATE | CLAIM_RECORDS | PAID_DENOMINATOR | MEAN_BLDG_PAID_USD |
-- |-----------------|-------|---------------|------------------|--------------------|
-- | Ocean County    | NJ    | 37459         | 34738            | 59274              |
-- | Nassau County   | NY    | 26964         | 25878            | 67115              |
-- | Suffolk County  | NY    | 13167         | 12193            | 62311              |
-- | Atlantic County | NJ    | 11344         | 10436            | 35224              |
-- | Cape May County | NJ    | 10060         | 8665             | 27857              |
-- These match the top five counties by count (min_claims = 500, no distance filter). The raw view has 132,388 rows and
-- the county view has 83 counties (50 with at least one Sandy claim).

-- Now open the view in the Catalog and click the Lineage tab: upstream is the
-- Marketplace share, downstream is anything that reads it.
--
-- To remove these objects later: DROP DATABASE IF EXISTS SDSC_WORKSHOP;
-- (labs/99_cleanup.sql does this for you.)
