-- =============================================================================
-- Lab C · Change the question. Explain the difference.          (~4 minutes)
-- =============================================================================
-- Question: Do the same counties stand out if we rank by AVERAGE paid amount
-- instead of claim COUNT?
--
-- Measure: mean of AMOUNT_PAID_ON_BUILDING_CLAIM over records where it is
-- present. Missing payments are NOT treated as zero, the denominator and the
-- missing count are shown so you can judge each mean.
--
-- This is descriptive history for one event. It is not a calibrated flood
-- risk model and says nothing about any individual property.
-- =============================================================================

USE WAREHOUSE SDSC_WORKSHOP_WH;

SET listing_db = 'SNOWFLAKE_PUBLIC_DATA_FREE';   -- <-- change if you renamed it
SET claims_tbl = $listing_db || '.PUBLIC_DATA_FREE.FEMA_NATIONAL_FLOOD_INSURANCE_PROGRAM_CLAIM_INDEX';
SET geo_index  = $listing_db || '.PUBLIC_DATA_FREE.GEOGRAPHY_INDEX';

SET min_claims = 500;   -- <-- TRY: change to 5000, then to 100

WITH county_stats AS (
  SELECT county_geo_id,
         COUNT(*)                                            AS claim_records,
         COUNT(amount_paid_on_building_claim)                AS paid_denominator,
         COUNT(*) - COUNT(amount_paid_on_building_claim)     AS paid_missing,
         AVG(amount_paid_on_building_claim)                  AS mean_bldg_paid_usd
  FROM IDENTIFIER($claims_tbl)
  WHERE flood_event   = 'Hurricane Sandy'
    AND state_geo_id IN ('geoId/36', 'geoId/34')
    AND county_geo_id IS NOT NULL
  GROUP BY county_geo_id
  HAVING COUNT(*) >= $min_claims
)
SELECT g.geo_name                                       AS county,
       claim_records,
       paid_denominator,
       paid_missing,
       ROUND(mean_bldg_paid_usd)                        AS mean_bldg_paid_usd,
       RANK() OVER (ORDER BY claim_records DESC)        AS rank_by_count,
       RANK() OVER (ORDER BY mean_bldg_paid_usd DESC)   AS rank_by_mean_paid
FROM county_stats c
JOIN IDENTIFIER($geo_index) g ON g.geo_id = c.county_geo_id
ORDER BY rank_by_count;

-- Expected with min_claims = 500 (snapshot 2026-10-11; the listing refreshes,
-- so expect small drift). 14 rows, in this order:
--
--   COUNTY           | CLAIM_RECORDS | PAID_DENOMINATOR | PAID_MISSING | MEAN_BLDG_PAID_USD | RANK_BY_COUNT | RANK_BY_MEAN_PAID
--   Ocean County     |         37459 |            34738 |         2721 |              59274 |             1 |                 9
--   Nassau County    |         26964 |            25878 |         1086 |              67115 |             2 |                 6
--   Suffolk County   |         13167 |            12193 |          974 |              62311 |             3 |                 7
--   Atlantic County  |         11344 |            10436 |          908 |              35224 |             4 |                12
--   Cape May County  |         10060 |             8665 |         1395 |              27857 |             5 |                14
--   Monmouth County  |         10032 |             9425 |          607 |              74362 |             6 |                 4
--   Queens           |          7639 |             7372 |          267 |              74836 |             7 |                 3
--   Richmond County  |          4095 |             3998 |           97 |              54333 |             8 |                10
--   Brooklyn         |          3561 |             3400 |          161 |              81335 |             9 |                 2
--   Hudson County    |          2327 |             1934 |          393 |              59990 |            10 |                 8
--   Bergen County    |          2072 |             1913 |          159 |              51821 |            11 |                11
--   Middlesex County |           742 |              694 |           48 |              68370 |            12 |                 5
--   Manhattan        |           668 |              445 |          223 |             236483 |            13 |                 1
--   Bronx County     |           537 |              415 |          122 |              28623 |            14 |                13
--
-- The story flips: Manhattan has relatively few claim records but the highest
-- mean building payout. Ocean County has the most records but ranks 9th on
-- mean payout. Neither ranking is "right", they answer different questions.
--
-- Your change: set min_claims to 5000. Manhattan and Brooklyn drop out
-- entirely. The threshold you pick changes which story you can tell.
--
-- Interpret: a different metric changes the answer. Before an AI explains
-- this table, you should already know what it should say.
