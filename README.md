# Spatial Intelligence for Insurance: From Risk and Exposure to Action

Workshop resources for **SDSC 2026 New York | Spatial Data Science Conference**,
presented by Snowflake and CARTO.

> **The question:** Where were Hurricane Sandy flood claims heaviest, and are
> the places with the most claims also the places with the costliest ones?

## Four pillars, one question

| Pillar | What you'll see | Where |
|---|---|---|
| **1. Native spatial types** | `GEOGRAPHY` (spherical, WGS84, metres) and `GEOMETRY` (planar, CRS-defined units) | Lab A |
| **2. Native spatial functions** | `ST_DWITHIN`, `ST_DISTANCE`, `ST_AREA`, `ST_CENTROID` | Labs A + B |
| **3. Ecosystem of data and capabilities** | Free Marketplace data (FEMA NFIP + county boundaries), and CARTO for interactive exploration | Marketplace tour, Lab B, CARTO section |
| **4. AI across the workflow** | CoCo explains or edits a query, CoWork answers a question with an inspectable query | AI sections of the walkthrough |

## Participant path: browser only

You need a browser and a Snowflake trial account. Nothing to install or clone. You don't need Python, a CLI, a CARTO account, or a credit card.

**Start with [`WALKTHROUGH.md`](WALKTHROUGH.md).** It covers every section of the
workshop in order: what to click, what to run, and what you should see.

1. **Create a trial:** <https://signup.snowflake.com/>
2. **Get the free data:** open *Snowflake Public Data (Free)* at
   <https://app.snowflake.com/marketplace/listing/GZTSZ290BV255> and click **Get**.
3. **Open a SQL worksheet** in Snowsight. Paste and run each file in order:

| File | Time | What it does |
|---|---|---|
| [`labs/00_setup_and_check.sql`](labs/00_setup_and_check.sql) | 2 min | Creates one X-Small auto-suspending warehouse, then runs a read-only check that every row returns OK |
| [`labs/01_locations_and_types.sql`](labs/01_locations_and_types.sql) | 3 min | **Lab A:** real Sandy claims by Manhattan ZIP code, with real ZIP boundaries. Where were claims heaviest, and how far from the southern tip? |
| [`labs/02_county_claims.sql`](labs/02_county_claims.sql) | 5 min | **Lab B:** Sandy claims by county, with real county boundaries. Which counties near Manhattan were hit hardest? |
| [`labs/03_change_the_question.sql`](labs/03_change_the_question.sql) | 4 min | **Lab C:** rank by mean payout instead of count, and watch the story change |
| [`labs/04_build_the_pipeline.sql`](labs/04_build_the_pipeline.sql) | 3 min | Turns Labs B and C into two views, the layer a map tool or AI agent reads |
| [`labs/99_cleanup.sql`](labs/99_cleanup.sql) | 1 min | Optional. Drops only what the workshop created |

Each lab starts with a question. Each one ends with something to change and a question to interpret. Compare your output against [`labs/EXPECTED_RESULTS.md`](labs/EXPECTED_RESULTS.md).

> **AI note:** Snowflake documentation says AI features are disabled by default in self-service trials until a payment method is added. The core labs are SQL-only on purpose. The AI and CARTO sections are shown on screen, and the walkthrough has the steps if you want to run them yourself later. Please don't add payment details just for this workshop.

## Read this before drawing conclusions

FEMA truncates public NFIP claim coordinates to one decimal place (about 11 km) for privacy, and recommends county or census-tract fields for aggregation. These labs therefore count claims by ZIP code and county and **never** infer property-level locations. This is descriptive history for one event, not a flood-risk model or an underwriting recommendation. See [`SOURCES.md`](SOURCES.md).

## Go further

[`go-further/`](go-further/) has more to explore after the labs: the workshop slide decks, the [semantic view and agent](go-further/semantic-view-and-agent/README.md) for the CoWork section, with a Cortex Code prompt, SQL, and YAML (it needs AI features, which trial accounts unlock when a card is added), and a CoCo skill that recreates a demo environment in your own account. None of it is required for the labs.

## License / attribution

The slide CSS/JS in `go-further/presentations/assets/` is adapted from
[`coco-adoption-template`](https://github.com/sfc-gh-calexander/coco-adoption-template).
