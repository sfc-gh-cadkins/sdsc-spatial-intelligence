-- =============================================================================
-- Lab C · Change the question. Explain the difference.          (~4 minutes)
-- =============================================================================
-- Question: Do the same counties stand out if we rank by AVERAGE paid amount
-- instead of claim COUNT?
--
-- Measure: mean of AMOUNT_PAID_ON_BUILDING_CLAIM over records where it is
-- present. Missing payments are NOT treated as zero — the denominator and the
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

-- Expected with min_claims = 500 (snapshot 2026-10-09):
--   COUNTY           CLAIMS  MEAN PAID  RANK BY COUNT  RANK BY MEAN
--   Ocean County     37,459    $59,274        1              9
--   Nassau County    26,964    $67,115        2              6
--   Atlantic County  11,344    $35,224        4             12
--   Brooklyn          3,561    $81,335        9              2
--   Manhattan           668   $236,483       13              1   <-- 223 of 668 missing
--
-- The story flips: Manhattan has relatively few claim records but the highest
-- mean building payout. Ocean County has the most records but ranks 9th on
-- mean payout. Neither ranking is "right" — they answer different questions.
--
-- Your change: set min_claims to 5000. Manhattan and Brooklyn drop out
-- entirely. The threshold you pick changes which story you can tell.
--
-- Interpret: a different metric changes the answer. Before an AI explains
-- this table, you should already know what it should say.
