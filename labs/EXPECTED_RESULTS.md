# Expected results

Snapshot captured **2026-10-09** against *Snowflake Public Data (Free)*
(`SNOWFLAKE_PUBLIC_DATA_FREE.PUBLIC_DATA_FREE`). The free listing is refreshed
by the provider, so later runs can drift by a handful of records. A difference
of a few rows is expected; a difference of thousands means a filter changed.

## 00 · Setup and readiness check

| CHECK_NAME | STATUS | DETAIL |
|---|---|---|
| NFIP claims table readable | OK | 144,848 |
| County boundaries readable | OK | 1 |
| Native GEOGRAPHY works | OK | NULL |

## Lab A · Locations and types (synthetic)

| SITE | POINT_WKT | INSIDE_STUDY_AREA | METRES_TO_CENTRE | WITHIN_10KM |
|---|---|---|---|---|
| Site A (synthetic) | POINT(-73.95 40.63) | TRUE | 558 | TRUE |
| Site B (synthetic) | POINT(-73.9 40.6) | TRUE | 5,742 | TRUE |
| Site C (synthetic) | POINT(-73.7 40.75) | FALSE | 24,652 | FALSE |

**After the change** (Site C → `-73.88, 40.65`): INSIDE = TRUE, 6,136 m, WITHIN_10KM = TRUE.

## Lab B · County claims (default study area)

16 counties returned. Top 8:

| COUNTY | CLAIM_RECORDS | RECORDS_WITH_BLDG_PAYMENT |
|---|---|---|
| Nassau County | 26,964 | 25,878 |
| Suffolk County | 13,167 | 12,193 |
| Monmouth County | 10,032 | 9,425 |
| Queens | 7,639 | 7,372 |
| Richmond County | 4,095 | 3,998 |
| Brooklyn | 3,561 | 3,400 |
| Hudson County | 2,327 | 1,934 |
| Bergen County | 2,072 | 1,913 |

Not included: **Ocean County** (37,459 records, the largest in the event) is south of the rectangle.

**After the change** (south edge 40.45 → 39.70): Ocean County appears at #1 with 37,459.

Reconciliation: 132,388 Hurricane Sandy claim records in NY + NJ. 141 have no `COUNTY_GEO_ID`, so they're excluded before the join.

## Lab C · Change the question (`min_claims = 500`)

14 counties returned. Selected rows:

| COUNTY | CLAIMS | PAID_DENOMINATOR | PAID_MISSING | MEAN_BLDG_PAID | RANK_BY_COUNT | RANK_BY_MEAN |
|---|---|---|---|---|---|---|
| Ocean County | 37,459 | 34,738 | 2,721 | $59,274 | 1 | 9 |
| Nassau County | 26,964 | 25,878 | 1,086 | $67,115 | 2 | 6 |
| Atlantic County | 11,344 | 10,436 | 908 | $35,224 | 4 | 12 |
| Brooklyn | 3,561 | 3,400 | 161 | $81,335 | 9 | 2 |
| Manhattan | 668 | 445 | 223 | $236,483 | 13 | 1 |

**After the change** (`min_claims = 5000`): 7 counties remain: Ocean, Nassau, Suffolk, Atlantic, Cape May, Monmouth, Queens. Manhattan and Brooklyn are gone.
