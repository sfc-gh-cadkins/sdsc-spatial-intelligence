-- =============================================================================
-- Lab A · Turn coordinates into a relationship        (pillars 1 + 2 · 3 min)
-- =============================================================================
-- Question: Which of these locations falls inside this study area?
--
-- ALL DATA HERE IS SYNTHETIC. Three made-up sites and one rectangle near New
-- York. This teaches mechanics. It says nothing about real flood risk.
--
-- Two things to notice:
--   * ST_MAKEPOINT takes (LONGITUDE, LATITUDE) — x before y.
--     (H3_LATLNG_TO_CELL takes latitude first. Watch the order.)
--   * GEOGRAPHY models the Earth as a sphere (WGS84). Distances come back in
--     metres. GEOMETRY is planar; its units depend on the coordinate system.
-- =============================================================================

USE WAREHOUSE SDSC_WORKSHOP_WH;

WITH study_area AS (
  SELECT TO_GEOGRAPHY(
    'POLYGON((-74.05 40.57, -73.85 40.57, -73.85 40.70, -74.05 40.70, -74.05 40.57))'
  ) AS geog
),
sites AS (
  SELECT * FROM VALUES
    ('Site A (synthetic)', -73.95, 40.63),
    ('Site B (synthetic)', -73.90, 40.60),
    ('Site C (synthetic)', -73.70, 40.75)   -- <-- TRY: change -73.70 to -73.88
  AS t(site, lon, lat)
)
SELECT s.site,
       ST_ASWKT(ST_MAKEPOINT(s.lon, s.lat))                         AS point_wkt,
       ST_INTERSECTS(ST_MAKEPOINT(s.lon, s.lat), a.geog)             AS inside_study_area,
       ROUND(ST_DISTANCE(ST_MAKEPOINT(s.lon, s.lat), ST_CENTROID(a.geog))) AS metres_to_centre,
       ST_DWITHIN(ST_MAKEPOINT(s.lon, s.lat), ST_CENTROID(a.geog), 10000)  AS within_10km_of_centre
FROM sites s
CROSS JOIN study_area a
ORDER BY s.site;

-- Expected:
--   SITE                | POINT_WKT            | INSIDE | METRES | WITHIN_10KM
--   Site A (synthetic)  | POINT(-73.95 40.63)  | TRUE   |    558 | TRUE
--   Site B (synthetic)  | POINT(-73.9 40.6)    | TRUE   |   5742 | TRUE
--   Site C (synthetic)  | POINT(-73.7 40.75)   | FALSE  |  24652 | FALSE
--
-- Your change: set Site C's longitude to -73.88 and its latitude to 40.65.
-- Site C's INSIDE value should flip to TRUE.
--
-- Interpret: the database evaluated "inside" and "within 10 km" itself.
-- You can read and audit the logic — no GIS desktop needed.
