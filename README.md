# Spatial Intelligence for Insurance: From Risk and Exposure to Action

Workshop resources for **SDSC 2026 New York | Spatial Data Science Conference**.
Presented by Caleb Alexander (Snowflake) and Ryan Miller (CARTO).

> **The question:** Where were Hurricane Sandy flood claims heaviest, and are
> the places with the most claims also the places with the costliest ones?

## Four pillars, one question

| Pillar | What you'll see | Where |
|---|---|---|
| **1. Native spatial types** | `GEOGRAPHY` (spherical, WGS84, metres) and `GEOMETRY` (planar, CRS-defined units) | Lab A |
| **2. Native spatial functions** | `ST_INTERSECTS`, `ST_DWITHIN`, `ST_DISTANCE`, plus H3 as an optional extension | Labs A + B |
| **3. Ecosystem of data and capabilities** | Free Marketplace data (FEMA NFIP + county boundaries), and CARTO for interactive exploration | Lab B + Ryan's section |
| **4. AI across the workflow** | Presenter-led: CoCo explains or edits a query, CoWork answers a question with an inspectable query | Presenter demo |

## Participant path: browser only

You need a browser and a Snowflake trial account. Nothing to install or clone. You don't need Python, a CLI, a CARTO account, or a credit card.

**Everything you need is in the [`labs/`](labs/) folder.** You can ignore the rest of the repo.

1. **Create a trial:** <https://signup.snowflake.com/>
2. **Get the free data:** open *Snowflake Public Data (Free)* at
   <https://app.snowflake.com/marketplace/listing/GZTSZ290BV255> and click **Get**.
3. **Open a SQL worksheet** in Snowsight. Paste and run each file in order:

| File | Time | What it does |
|---|---|---|
| [`labs/00_setup_and_check.sql`](labs/00_setup_and_check.sql) | 2 min | Creates one X-Small auto-suspending warehouse, then runs a read-only check that every row returns OK |
| [`labs/01_locations_and_types.sql`](labs/01_locations_and_types.sql) | 3 min | **Lab A:** synthetic points and a polygon. Which are inside, and which are within 10 km? |
| [`labs/02_county_claims.sql`](labs/02_county_claims.sql) | 5 min | **Lab B:** Sandy claims by county, joined to real county boundaries and filtered spatially |
| [`labs/03_change_the_question.sql`](labs/03_change_the_question.sql) | 4 min | **Lab C:** rank by mean payout instead of count, and watch the story change |
| [`labs/99_cleanup.sql`](labs/99_cleanup.sql) | 1 min | Optional. Drops only the workshop warehouse |

Each lab starts with a question. Each one ends with something to change and a question to interpret. Compare your output against [`labs/EXPECTED_RESULTS.md`](labs/EXPECTED_RESULTS.md).

> **AI note:** Snowflake documentation says AI features are disabled by default in self-service trials until a payment method is added. The core labs are SQL-only on purpose. The AI and CARTO portions are demonstrated from the presenters' account. Please don't add payment details just for this workshop.

## Read this before drawing conclusions

FEMA truncates public NFIP claim coordinates to one decimal place (about 11 km) for privacy, and recommends county or census-tract fields for aggregation. These labs therefore aggregate by county and **never** infer property-level locations. This is descriptive history for one event, not a flood-risk model or an underwriting recommendation. See [`SOURCES.md`](SOURCES.md).

## Go further

[`go-further/`](go-further/) has more to explore after the labs: the workshop slide decks, the SQL behind the AI demo (it needs AI features, which trial accounts unlock when a card is added), and a CoCo skill that rebuilds the full demo environment. None of it is required for the labs.

## License / attribution

The site's CSS/JS scaffolding in `go-further/presentations/assets/` is adapted from
[`coco-adoption-template`](https://github.com/sfc-gh-calexander/coco-adoption-template).
