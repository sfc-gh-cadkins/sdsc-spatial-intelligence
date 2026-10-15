# Sources, provenance, and caveats

## Data used by the participant labs

| Data | Where it comes from | Object in your account |
|---|---|---|
| NFIP redacted flood claims | FEMA OpenFEMA, republished by Snowflake Public Data Products | `SNOWFLAKE_PUBLIC_DATA_FREE.PUBLIC_DATA_FREE.FEMA_NATIONAL_FLOOD_INSURANCE_PROGRAM_CLAIM_INDEX` |
| County names / IDs | Snowflake Public Data geography tables | `...PUBLIC_DATA_FREE.GEOGRAPHY_INDEX` |
| County boundaries (WKT) | Snowflake Public Data geography tables | `...PUBLIC_DATA_FREE.GEOGRAPHY_CHARACTERISTICS` (`relationship_type = 'coordinates_wkt'`) |
| The lab: claims and ZIP boundaries | FEMA NFIP claims and ZIP code boundaries, Snowflake Public Data (Free) listing | See listing terms |

Marketplace listing: **Snowflake Public Data (Free)** —
<https://app.snowflake.com/marketplace/listing/GZTSZ290BV255>.
The listing describes a refresh lag. This repo **does not copy or redistribute** any provider data. Every lab queries the shared listing in your own account.

## Event filter

The labs filter on `FLOOD_EVENT = 'Hurricane Sandy'`, the event label in the source. Running the readiness check in October 2026 returned 144,848 records across 13 states, with dates of loss from 2012-10-27 to 2012-11-06. The labs narrow that to New York (`geoId/36`) and New Jersey (`geoId/34`).

## The coordinate-precision caveat

According to FEMA's NFIP data FAQ, public latitude and longitude are truncated to one decimal place (about 11 km) for privacy. As a result, mapped records can look artificially clustered. FEMA recommends county or census-tract fields for aggregation.
<https://agents.floodsmart.gov/flood-maps-and-data/faqs-about-nfip-data>

That is why these labs aggregate by `COUNTY_GEO_ID` and never place individual claims from their coordinates. A finer H3 grid can't recover precision the source removed.

## What these results are not

- Not a flood-risk model, and not an underwriting recommendation.
- Not a property-level view.
- Not causal. A county ranking reflects that county's exposure, insured population, and reporting, alongside storm severity.

## Reference documentation

- Geospatial data types: <https://docs.snowflake.com/en/sql-reference/data-types-geospatial>
- `ST_INTERSECTS`: <https://docs.snowflake.com/en/sql-reference/functions/st_intersects>
- `ST_DWITHIN`: <https://docs.snowflake.com/en/sql-reference/functions/st_dwithin>
- Trial accounts: <https://docs.snowflake.com/en/user-guide/admin-trial-account>
- Snowflake Public Data, FEMA: <https://data-docs.snowflake.com/sources/fema>
- Snowflake Public Data, geography: <https://data-docs.snowflake.com/sources/geography>
- CARTO Snowflake connection: <https://docs.carto.com/carto-user-manual/connections/snowflake>
