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

-- Scaling: same query, 16x the compute, one line. Uncomment, rerun, compare
-- the query time in Query History. (Needs SDSC_WORKSHOP_WH_LARGE from 00.)
-- USE WAREHOUSE SDSC_WORKSHOP_WH_LARGE;

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

-- Expected (snapshot 2026-10-11; the listing refreshes, so expect small drift).
-- 10 rows, in this order:
--
--   ZIP   | CLAIMS | MEAN_BLDG_PAID | AREA_KM2 | KM_FROM_SOUTHERN_TIP | NEAR_SOUTHERN_TIP
--   10009 |     94 |         128165 |     1.60 |                  4.9 | FALSE
--   10013 |     80 |         242294 |     1.41 |                  3.1 | FALSE
--   10038 |     74 |         268773 |     0.75 |                  2.1 | TRUE
--   10011 |     62 |         239722 |     1.67 |                  5.5 | FALSE
--   10029 |     58 |         109056 |     3.03 |                 12.5 | FALSE
--   10014 |     42 |         445064 |     1.25 |                  4.6 | FALSE
--   10004 |     29 |         433761 |     1.18 |                  0.0 | TRUE
--   10128 |     27 |          99119 |     1.17 |                 11.3 | FALSE
--   10010 |     24 |         209605 |     0.95 |                  5.8 | FALSE
--   10035 |     23 |         113958 |     3.63 |                 13.5 | FALSE
--
-- Neighborhoods: 10009 East Village, 10013 Tribeca/SoHo, 10038 Seaport,
-- 10011 Chelsea, 10029 East Harlem, 10014 West Village, 10004 Battery Park,
-- 10128 Upper East Side, 10010 Gramercy, 10035 East Harlem.
--
-- Interpret: the ZIP with the most claims is not at the tip. 10009 is the
-- East Village, on the East River, and East Harlem, 12.5 km north, is fifth.
-- The surge pushed up both rivers, not just into the Financial District.
--
-- Your change: set within_m to 6000 and rerun. Five more ZIPs turn TRUE:
-- 10009, 10013, 10011, 10014 and 10010. 10029, 10128 and 10035 stay FALSE,
-- so distance from the tip does not explain where Manhattan flooded.

-- =============================================================================
-- The surprise: were these properties even in the flood zone?
-- =============================================================================
-- POLICY_RATED_FLOOD_ZONE is the FEMA zone each policy was rated in at the time
-- of the loss. "Special Flood..." is FEMA's high-risk zone (A and V zones).
-- Everything else is outside it.

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

-- Expected (snapshot 2026-10-12). 10 rows, in this order:
--
--   ZIP   | CLAIMS | OUTSIDE_HIGH_RISK_ZONE | PCT_OUTSIDE
--   10009 |     94 |                     31 |          33
--   10013 |     80 |                      8 |          10
--   10038 |     74 |                      6 |           8
--   10011 |     62 |                     20 |          32
--   10029 |     58 |                     29 |          50
--   10014 |     42 |                     10 |          24
--   10004 |     29 |                      7 |          24
--   10128 |     27 |                      1 |           4
--   10010 |     24 |                      5 |          21
--   10035 |     23 |                      5 |          22
--
-- Interpret: half of East Harlem's Sandy claims, and a third of the East
-- Village's, came from properties FEMA had rated OUTSIDE the high-risk flood
-- zone. Across all of Manhattan it's 188 of 668 claims (28%), and those
-- claims were paid more on average ($265,319 vs $227,798).
-- The flood map said these places were lower risk. The water disagreed.
