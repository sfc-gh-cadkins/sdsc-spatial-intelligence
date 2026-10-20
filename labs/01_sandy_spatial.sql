-- =============================================================================
-- The Lab · Where did Hurricane Sandy's flood claims hit hardest, and did
--           they land where the flood maps said they would?    (~10 minutes)
-- =============================================================================
-- One script, three steps, one story:
--   Step 1  Types      Manhattan ZIP codes as real shapes (GEOGRAPHY).
--   Step 2  Functions  Counties near Manhattan, ranked two ways:
--                      by claim COUNT and by MEAN building payout.
--   Step 3  Surprise   Were these properties even in the flood zone?
--
-- At the end of this file are two Cortex Code (CoCo) prompts: one turns this
-- script into a Python file, the other into a notebook with visuals.
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
       DECODE(zip, '10009','East Village', '10013','Tribeca / SoHo',
                   '10038','Seaport', '10011','Chelsea', '10029','East Harlem',
                   '10014','West Village', '10004','Battery Park',
                   '10128','Upper East Side', '10010','Gramercy',
                   '10035','East Harlem (north)', '10002','Lower East Side',
                   '10282','Battery Park City', '10280','Battery Park City',
                   '10003','East Village / Union Sq', 'Other')    AS neighborhood,
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

-- Expected (snapshot October 2026; the listing refreshes, so expect small drift):
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

-- Expected (distance_m = 25000, min_claims = 500, snapshot October 2026). 10 rows:
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
       DECODE(zip, '10009','East Village', '10013','Tribeca / SoHo',
                   '10038','Seaport', '10011','Chelsea', '10029','East Harlem',
                   '10014','West Village', '10004','Battery Park',
                   '10128','Upper East Side', '10010','Gramercy',
                   '10035','East Harlem (north)', 'Other')            AS neighborhood,
       COUNT(*)                                                     AS claims,
       COUNT_IF(NOT policy_rated_flood_zone ILIKE 'Special Flood%') AS outside_high_risk_zone,
       ROUND(100 * outside_high_risk_zone / claims)                 AS pct_outside
FROM IDENTIFIER($claims_tbl)
WHERE flood_event = 'Hurricane Sandy'
  AND county_geo_id = 'geoId/36061'
GROUP BY zip_geo_id
ORDER BY claims DESC
LIMIT 10;

-- Expected (snapshot October 2026):
--   10009 East Village   94 claims, 31 outside (33%)
--   10013 Tribeca / SoHo 80 claims,  8 outside (10%)  waterfront: map got it right
--   10038 Seaport        74 claims,  6 outside  (8%)
--   10011 Chelsea        62 claims, 20 outside (32%)
--   10029 East Harlem    58 claims, 29 outside (50%)
--   All of Manhattan: 188 of 668 claims (28%) came from outside the high-risk
--   zone. More than one in four.
-- Interpret: the flood map said these places were lower risk. The water
-- disagreed. That's why underwriting needs geography.

-- =============================================================================
-- Take it further with Cortex Code (CoCo)
-- =============================================================================
-- Open CoCo in Snowsight (needs AI features; on a trial, watch on screen).
-- Copy everything between the dashed lines into CoCo.
-- If CoCo isn't available, the finished versions are in labs/reference/.

-- ---- CoCo prompt 1 · SQL to Python -----------------------------------------
-- Convert labs/01_sandy_spatial.sql into a Snowpark Python file named
-- 02_sandy_spatial.py. Keep the same three steps and the same three knobs
-- (WITHIN_M, DISTANCE_M, MIN_CLAIMS) at the top. Use get_active_session(),
-- Snowpark DataFrames and snowflake.snowpark.functions, and call the spatial
-- functions (TO_GEOGRAPHY, TRY_TO_GEOGRAPHY, ST_CENTROID, ST_AREA, ST_DISTANCE,
-- ST_DWITHIN) with F.call_function so they still run inside Snowflake. Show
-- each step's result with .show(). Then run it and confirm the numbers match
-- the SQL: East Village 10009 is the top ZIP with 94 claims, and Manhattan is
-- #9 by count but #1 by mean paid ($236,483).
-- ----------------------------------------------------------------------------

-- ---- CoCo prompt 2 · SQL to a notebook with visuals -------------------------
-- Turn labs/01_sandy_spatial.sql into a new Snowflake Workspace notebook named
-- labs/03_sandy_spatial_<your initials>.ipynb, adding a number if that name
-- exists and never overwriting an existing notebook. Put get_active_session(),
-- the table names and the knobs WITHIN_M = 6000, DISTANCE_M = 25000 and
-- MIN_CLAIMS = 500 in one Python Parameters cell at the top, keep every query
-- as a real SQL cell with a result variable that uses the knobs through Jinja,
-- and add a short markdown cell before each chart saying what it shows. Use
-- Altair only with alt.renderers.enable("mimetype"), get shapes with
-- ST_ASGEOJSON(...)::STRING, simplify county boundaries with
-- ST_SIMPLIFY(boundary, 200), never reverse polygon rings, and draw every map
-- with .project(type="identity", reflectY=True). Use blues for counts, oranges
-- for dollars and percentages, #29B5E8 and #FF9F36 for single-colour marks,
-- and give every chart a clear title and formatted tooltips. Build:
--   1. A map of Manhattan ZIP codes coloured by Sandy claims, with tooltips.
--   2. Two county maps side by side: claim count vs mean building paid, with
--      independent colour scales.
--   3. A labelled slope chart of each county's rank by count vs rank by mean
--      paid.
--   4. An alt.param slider from 100 to 10,000 that filters counties by minimum
--      claims and re-ranks them by mean paid in the browser with a window rank
--      transform, showing the rank on each bar.
--   5. A Python loop that reruns the Step 2 spatial query with the distance as
--      a bound parameter at 0 to 80 km in 10 km steps and charts claims
--      captured, with points coloured by the #1 county.
--   6. Stacked bars of claims inside vs outside FEMA's high-risk flood zone for
--      the top 10 ZIPs, next to a map of percent outside.
-- Run every cell, then fix and rerun until there are no errors, every map shows
-- distinct outlines rather than a solid rectangle, 10009 is the top ZIP with 94
-- claims, Manhattan is #9 by count and #1 by mean paid ($236,483) at 25 km, and
-- 10009 has 31 of 94 claims outside the high-risk zone (33%). End with a short
-- pass/fail list for these checks.
-- ----------------------------------------------------------------------------

-- ---- CoCo prompt 3 · CARTO forecast-cone map (CoCo CLI) --------------------
-- This prompt runs in CoCo CLI (Desktop or terminal), not in Snowsight.
-- It needs the CARTO CLI, a CARTO connection to your Snowflake account, and
-- the tract-population table from go-further/carto-cli-forecast-cones/.
-- See that folder's README for prerequisites and install steps.
--
-- Build a Hurricane Sandy forecast-cone population workflow and interactive
-- CARTO map using the CARTO CLI. Download the NHC forecast-cone archives for
-- advisories 010, 012, 014, 020, 023, 026, and 028 from
-- https://www.nhc.noaa.gov/gis/forecast/archive/ and the actual track from
-- https://www.nhc.noaa.gov/gis/best_track/al182012_best_track.zip. Select
-- each archive's _pgn shapefile and the best-track line shapefile, then load
-- them with carto import. Use only the 120-hour cone for each advisory. Create
-- and run a CARTO workflow that counts each tract once per advisory when its
-- point falls inside the cone, and sums its full population, retaining
-- zero-match cones. Create a private CARTO map with a seven-position slider
-- for the selected advisories, population and tract counts, advisory and issue
-- time, and the actual track above the cone. Prefix all new tables, the
-- workflow, and the map with your initials and a unique run ID. Ask me for my
-- CARTO connection name, writable Snowflake database and schema, initials, and
-- the tract table's fully qualified name. Do not assume access to the
-- presenters' environment.
-- ----------------------------------------------------------------------------
