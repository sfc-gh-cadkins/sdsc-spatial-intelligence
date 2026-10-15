-- =============================================================================
-- 00 · Setup and readiness check                               (~2 minutes)
-- =============================================================================
-- Question: Is my account ready for the three workshop exercises?
--
-- Before running this file:
--   1. Get "Snowflake Public Data (Free)" from Snowflake Marketplace:
--      https://app.snowflake.com/marketplace/listing/GZTSZ290BV255
--   2. If you named the installed database something other than
--      SNOWFLAKE_PUBLIC_DATA_FREE, change the value on the SET line below.
--
-- This file creates ONE small warehouse. It does not create tables.
-- =============================================================================

SET listing_db = 'SNOWFLAKE_PUBLIC_DATA_FREE';   -- <-- change if you renamed it

-- One X-Small warehouse that suspends after 60 seconds idle.
CREATE WAREHOUSE IF NOT EXISTS SDSC_WORKSHOP_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND   = 60
  AUTO_RESUME    = TRUE
  INITIALLY_SUSPENDED = TRUE;

-- Optional: a Large warehouse for the scaling demo in the lab. It costs nothing
-- while suspended, and suspends after 60 seconds idle. Skip it if you like.
CREATE WAREHOUSE IF NOT EXISTS SDSC_WORKSHOP_WH_LARGE
  WAREHOUSE_SIZE = 'LARGE'
  AUTO_SUSPEND   = 60
  AUTO_RESUME    = TRUE
  INITIALLY_SUSPENDED = TRUE;

USE WAREHOUSE SDSC_WORKSHOP_WH;

-- Readiness check: read-only. Every row should say OK.
SET claims_tbl = $listing_db || '.PUBLIC_DATA_FREE.FEMA_NATIONAL_FLOOD_INSURANCE_PROGRAM_CLAIM_INDEX';
SET geo_chars  = $listing_db || '.PUBLIC_DATA_FREE.GEOGRAPHY_CHARACTERISTICS';

SELECT 'NFIP claims table readable' AS check_name,
       IFF(COUNT(*) > 100000, 'OK', 'CHECK LISTING') AS status,
       COUNT(*) AS detail
FROM IDENTIFIER($claims_tbl)
WHERE flood_event = 'Hurricane Sandy'
UNION ALL
SELECT 'County boundaries readable',
       IFF(COUNT(*) > 0, 'OK', 'CHECK LISTING'),
       COUNT(*)
FROM IDENTIFIER($geo_chars)
WHERE relationship_type = 'coordinates_wkt' AND geo_id = 'geoId/36047'   -- Kings County (Brooklyn)
UNION ALL
SELECT 'Native GEOGRAPHY works',
       IFF(ST_INTERSECTS(ST_MAKEPOINT(-73.95, 40.65),
                         TO_GEOGRAPHY('POLYGON((-74 40.6,-73.9 40.6,-73.9 40.7,-74 40.7,-74 40.6))')),
           'OK', 'UNEXPECTED'),
       NULL;

-- Expected (snapshot October 2026; the free listing refreshes, so counts can drift):
--   NFIP claims table readable | OK | ~144,848
--   County boundaries readable | OK | 1
--   Native GEOGRAPHY works     | OK | NULL
