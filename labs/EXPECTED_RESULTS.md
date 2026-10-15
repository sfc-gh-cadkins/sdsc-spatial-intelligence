# Expected results

Snapshot captured **October 2026** against *Snowflake Public Data (Free)*
(`SNOWFLAKE_PUBLIC_DATA_FREE.PUBLIC_DATA_FREE`). The free listing is refreshed
by the provider, so later runs can drift by a handful of records. A difference
of a few rows is expected; a difference of thousands means a filter changed.

## 00 · Setup and readiness check

| CHECK_NAME | STATUS | DETAIL |
|---|---|---|
| NFIP claims table readable | OK | 144,848 |
| County boundaries readable | OK | 1 |
| Native GEOGRAPHY works | OK | NULL |

## The lab (`01_sandy_spatial.sql`)

The CoCo-generated Python and notebook versions (and `labs/reference/`) should return the same numbers.

### Step 1 · Manhattan by ZIP code

Real FEMA claims and real ZIP boundaries. Top 10 ZIPs by claims, `within_m = 3000`:

| ZIP | Neighborhood | CLAIMS | MEAN_BLDG_PAID | AREA_KM2 | KM_FROM_SOUTHERN_TIP | NEAR_SOUTHERN_TIP |
|---|---|---|---|---|---|---|
| 10009 | East Village | 94 | 128,165 | 1.60 | 4.9 | FALSE |
| 10013 | Tribeca / SoHo | 80 | 242,294 | 1.41 | 3.1 | FALSE |
| 10038 | Seaport | 74 | 268,773 | 0.75 | 2.1 | TRUE |
| 10011 | Chelsea | 62 | 239,722 | 1.67 | 5.5 | FALSE |
| 10029 | East Harlem | 58 | 109,056 | 3.03 | 12.5 | FALSE |
| 10014 | West Village | 42 | 445,064 | 1.25 | 4.6 | FALSE |
| 10004 | Battery Park | 29 | 433,761 | 1.18 | 0.0 | TRUE |
| 10128 | Upper East Side | 27 | 99,119 | 1.17 | 11.3 | FALSE |
| 10010 | Gramercy | 24 | 209,605 | 0.95 | 5.8 | FALSE |
| 10035 | East Harlem (north) | 23 | 113,958 | 3.63 | 13.5 | FALSE |

**After the change** (`within_m = 6000`): 10009, 10013, 10011, 10014 and 10010 also turn TRUE. 10029, 10128 and 10035 stay FALSE.

### Step 2 · Counties near Manhattan, ranked two ways (`distance_m = 25000`, `min_claims = 500`)

| COUNTY | CLAIM_RECORDS | PAID_MISSING | MEAN_BLDG_PAID_USD | KM_FROM_MANHATTAN | RANK_BY_COUNT | RANK_BY_MEAN_PAID |
|---|---|---|---|---|---|---|
| Nassau County | 26964 | 1086 | 67115 | 11.3 | 1 | 6 |
| Monmouth County | 10032 | 607 | 74362 | 18.2 | 2 | 4 |
| Queens | 7639 | 267 | 74836 | 0.0 | 3 | 3 |
| Richmond County | 4095 | 97 | 54333 | 4.1 | 4 | 8 |
| Brooklyn | 3561 | 161 | 81335 | 0.0 | 5 | 2 |
| Hudson County | 2327 | 393 | 59990 | 0.0 | 6 | 7 |
| Bergen County | 2072 | 159 | 51821 | 0.0 | 7 | 9 |
| Middlesex County | 742 | 48 | 68370 | 17.0 | 8 | 5 |
| Manhattan | 668 | 223 | 236483 | 0.0 | 9 | 1 |
| Bronx County | 537 | 122 | 28623 | 0.0 | 10 | 10 |

Manhattan is 9th by count and 1st by mean paid. Ocean County (37,459 claims, 60.6 km) is missing.

**Your change, `distance_m = 75000`:** 12 rows. Top three by count:

| COUNTY | CLAIM_RECORDS | PAID_MISSING | MEAN_BLDG_PAID_USD | KM_FROM_MANHATTAN | RANK_BY_COUNT | RANK_BY_MEAN_PAID |
|---|---|---|---|---|---|---|
| Ocean County | 37459 | 2721 | 59274 | 60.6 | 1 | 9 |
| Nassau County | 26964 | 1086 | 67115 | 11.3 | 2 | 6 |
| Suffolk County | 13167 | 974 | 62311 | 34.8 | 3 | 7 |

**Then `min_claims = 5000`:** Manhattan and Brooklyn drop out.

**Notebook extras:** the live slider at 5,000 puts Queens first by mean paid ($74,836). The distance sweep's #1 county is Queens at 0-10 km, Nassau from 20 km, and Ocean County from 70 km.

### Step 3 · The flood-zone surprise

| ZIP | CLAIMS | OUTSIDE_HIGH_RISK_ZONE | PCT_OUTSIDE |
|---|---|---|---|
| 10009 | 94 | 31 | 33 |
| 10013 | 80 | 8 | 10 |
| 10038 | 74 | 6 | 8 |
| 10011 | 62 | 20 | 32 |
| 10029 | 58 | 29 | 50 |
| 10014 | 42 | 10 | 24 |
| 10004 | 29 | 7 | 24 |
| 10128 | 27 | 1 | 4 |
| 10010 | 24 | 5 | 21 |
| 10035 | 23 | 5 | 22 |

All of Manhattan: 188 of 668 Sandy claims (28%) came from policies rated outside FEMA's high-risk ("Special Flood") zone. Mean building paid: $265,319 outside vs $227,798 inside.
