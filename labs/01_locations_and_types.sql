-- =============================================================================
-- Lab A · Where did Sandy hit Manhattan?                (pillar 1 · 3 min)
-- =============================================================================
-- Question: Which Manhattan ZIP codes filed the most Hurricane Sandy flood
-- claims, and how far is each one from the southern tip, where the surge
-- came ashore?
--
-- Data: real FEMA NFIP claims and real ZIP code boundaries, both from the free
-- "Snowflake Public Data (Free)" Marketplace listing. Nothing is made up.
--
-- What you'll see:
--   TO_GEOGRAPHY turns a ZIP boundary stored as text into a real shape.
--   ST_AREA, ST_CENTROID and ST_DISTANCE measure it on the Earth's surface,
--   in metres, with no GIS tool and no export.
--
-- Privacy note: FEMA rounds public claim coordinates, so we count claims by
-- the ZIP code FEMA assigns. We never place an individual claim on the map.
-- =============================================================================

USE WAREHOUSE SDSC_WORKSHOP_WH;

SET listing_db = 'SNOWFLAKE_PUBLIC_DATA_FREE';   -- <-- change if you renamed it
SET claims_tbl = $listing_db || '.PUBLIC_DATA_FREE.FEMA_NATIONAL_FLOOD_INSURANCE_PROGRAM_CLAIM_INDEX';
SET geo_chars  = $listing_db || '.PUBLIC_DATA_FREE.GEOGRAPHY_CHARACTERISTICS';
SET within_m   = 3000;   -- <-- TRY: change to 6000

WITH manhattan_claims AS (
  -- Sandy claims in Manhattan (New York County), counted by ZIP code.
  SELECT zip_geo_id,
         COUNT(*)                                   AS claims,
         ROUND(AVG(amount_paid_on_building_claim))  AS mean_bldg_paid
  FROM IDENTIFIER($claims_tbl)
  WHERE flood_event = 'Hurricane Sandy'
    AND county_geo_id = 'geoId/36061'
  GROUP BY zip_geo_id
),
zip_shapes AS (
  -- Real ZIP boundaries, stored as WKT text, turned into GEOGRAPHY.
  SELECT geo_id, TO_GEOGRAPHY(value) AS geog
  FROM IDENTIFIER($geo_chars)
  WHERE relationship_type = 'coordinates_wkt'
    AND geo_id IN (SELECT zip_geo_id FROM manhattan_claims)
),
southern_tip AS (
  -- ZIP 10004 is the southern tip of Manhattan: Battery Park and the Financial District.
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
--   ZIP   | CLAIMS | KM_FROM_SOUTHERN_TIP | NEAR_SOUTHERN_TIP (3 km)
--   10009 |   94   |  4.9                 | FALSE   East Village
--   10013 |   80   |  3.1                 | FALSE   Tribeca / SoHo
--   10038 |   74   |  2.1                 | TRUE    Seaport
--   10011 |   62   |  5.5                 | FALSE   Chelsea
--   10029 |   58   | 12.5                 | FALSE   East Harlem
--   ... 10 rows. Only 10038 and 10004 are TRUE at 3 km.
--
-- Interpret: the ZIP with the most claims is not at the tip. 10009 is the
-- East Village, on the East River, and East Harlem, 12.5 km north, is fifth.
-- The surge pushed up both rivers, not just into the Financial District.
--
-- Your change: set within_m to 6000 and rerun. Six more ZIPs turn TRUE.
-- East Harlem (10029), 10128 and 10035 stay FALSE: distance from the tip
-- does not explain where Manhattan flooded.
