# sandy_tract_points.parquet

One row per US census tract in the area Hurricane Sandy's forecast cones cover
(longitude −83.1 to −59.7, latitude 12.1 to 51.5): **32,204 tracts,
125,730,415 people**. GeoParquet, EPSG:4326, about 1.5 MB.

| Column | Meaning |
|---|---|
| `geoid` | 11-digit census tract ID, unique |
| `state_fp`, `county_fp` | state and county FIPS codes |
| `population` | total population, ACS 2019–2023 5-year estimate (table DP05, field DP05_0001E). Today's population, not 2012 |
| `lon`, `lat` | the tract's Census internal point |
| `geom` | the same point as a geometry column |

The point is the Census Bureau's internal point (INTPTLAT, INTPTLON), which is
guaranteed to lie inside the tract. A tract counts as inside a forecast cone
when this point falls inside the cone, so the result is the population
represented by the tract points inside the cone, not hurricane impact.

**Source:** US Census Bureau TIGER/Line 2023 census tracts and the American
Community Survey 2023 5-year estimates, as published in CARTO's public data
(`carto-do-public-data.usa_tiger.geography_usa_censustract_2023` and
`carto-do-public-data.usa_acs.demographics_dp5demographic_usa_censustract_2023_5year_2023`).
Census data is public domain.

## Load into Snowflake

Use the CARTO CLI (about 25 seconds); the geometry arrives as a GEOGRAPHY
column named `GEOM`:

```bash
carto import --file sandy_tract_points.parquet --connection <your-connection> --destination <DB>.<SCHEMA>.SANDY_TRACT_POINTS
```

Checked: loaded with the command above, it gives 32,204 rows, population total
125,730,415, and no row differs from the source table in population or position.
