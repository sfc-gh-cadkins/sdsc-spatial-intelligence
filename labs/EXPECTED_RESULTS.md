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

## Lab A · Where did Sandy hit Manhattan?

Real FEMA claims and real ZIP boundaries. Top 10 ZIPs by claims, `within_m = 3000`:

| ZIP | Neighborhood | CLAIMS | MEAN_BLDG_PAID | AREA_KM2 | KM_FROM_SOUTHERN_TIP | NEAR_SOUTHERN_TIP |
|---|---|---|---|---|---|---|
| 10009 | East Village | 94 | 128,165 | 1.60 | 4.9 | FALSE |
| 10013 | Tribeca / SoHo | 80 | 242,294 | 1.41 | 3.1 | FALSE |
| 10038 | Seaport | 74 | 268,773 | 0.75 | 2.1 | TRUE |
| 10011 | Chelsea | 62 | 239,722 | 1.67 | 5.5 | FALSE |
| 10029 | East Harlem | 58 | 109,056 | 3.03 | 12.5 | FALSE |
| 10014 | West Village | 42 | 445,064 | 1.25 | 4.6 | FALSE |
| 10004 | Battery Park / FiDi | 29 | 433,761 | 1.18 | 0.0 | TRUE |
| 10128 | Upper East Side | 27 | 99,119 | 1.17 | 11.3 | FALSE |
| 10010 | Gramercy | 24 | 209,605 | 0.95 | 5.8 | FALSE |
| 10035 | East Harlem | 23 | 113,958 | 3.63 | 13.5 | FALSE |

**After the change** (`within_m = 6000`): 10009, 10013, 10011, 10014 and 10010 also turn TRUE. 10029, 10128 and 10035 stay FALSE.

## Lab B · Counties near Manhattan (`distance_m = 25000`)

15 counties returned. Top 8:

| COUNTY | CLAIM_RECORDS | RECORDS_WITH_BLDG_PAYMENT | KM_FROM_MANHATTAN |
|---|---|---|---|
| Nassau County | 26,964 | 25,878 | 11.3 |
| Monmouth County | 10,032 | 9,425 | 18.2 |
| Queens | 7,639 | 7,372 | 0.0 |
| Richmond County | 4,095 | 3,998 | 4.1 |
| Brooklyn | 3,561 | 3,400 | 0.0 |
| Hudson County | 2,327 | 1,934 | 0.0 |
| Bergen County | 2,072 | 1,913 | 0.0 |
| Middlesex County | 742 | 694 | 17.0 |

Manhattan is 9th with 668. Not included: **Ocean County** (37,459 records, the largest in the event) is 60.6 km away.

**After the change** (`distance_m = 75000`): 25 counties. Ocean County is #1 with 37,459, and Suffolk County (13,167, 34.8 km) is #3.

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
