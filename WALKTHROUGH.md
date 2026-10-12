# Workshop walkthrough: every section, step by step

This guide follows the workshop in order. Do it live with us, or on your own
afterwards. Each section says what to click, what to run, and what you should
see.

**You need:** a browser and a Snowflake trial account. Nothing to install or
clone.

| # | Section | Runs on a trial? |
|---|---|---|
| 0 | [Set up](#0-set-up) | Yes |
| 1 | [Marketplace: where the data comes from](#1-marketplace-where-the-data-comes-from) | Yes |
| 2 | [Catalog: what the data looks like](#2-catalog-what-the-data-looks-like) | Yes |
| 3 | [Workspaces: where you work](#3-workspaces-where-you-work) | Yes |
| 4 | [The lab in SQL: types, functions, a surprise](#4-the-lab-in-sql-types-functions-a-surprise) | Yes |
| 5 | [AI in the editor: Cortex Code](#5-ai-in-the-editor-cortex-code) | Needs AI features |
| 6 | [The same lab in Python](#6-the-same-lab-in-python) | Yes |
| 7 | [The same lab as a notebook, with maps](#7-the-same-lab-as-a-notebook-with-maps) | Yes |
| 8 | [Build the pipeline](#8-build-the-pipeline) | Yes |
| 9 | [Ecosystem: CARTO on the same data](#9-ecosystem-carto-on-the-same-data) | Needs a CARTO account |
| 10 | [AI for the business user: CoWork](#10-ai-for-the-business-user-cowork) | Needs AI features |
| 11 | [Clean up](#11-clean-up) | Yes |

> **About AI features:** Snowflake documentation says AI features are disabled
> by default in self-service trials until a payment method is added. Sections
> 6 and 10 need them. Everything else is plain SQL. You don't need to add
> payment details for this workshop: watch those two sections on screen.

Compare every result with [`labs/EXPECTED_RESULTS.md`](labs/EXPECTED_RESULTS.md).

---

## 0. Set up

1. Create a free trial at <https://signup.snowflake.com/>. No credit card
   needed.
2. Get the free data: open **Snowflake Public Data (Free)** at
   <https://app.snowflake.com/marketplace/listing/GZTSZ290BV255> and click
   **Get**. Keep the default database name, `SNOWFLAKE_PUBLIC_DATA_FREE`.
3. In Snowsight, go to **Projects > Workspaces** and create a SQL file.
4. Paste [`labs/00_setup_and_check.sql`](labs/00_setup_and_check.sql) and run
   it all.

**You should see:** every check row returns `OK`. The script creates one
X-Small warehouse, `SDSC_WORKSHOP_WH`, that suspends after 60 seconds idle.

## 1. Marketplace: where the data comes from

1. Click **Marketplace**. You land on **Discover**.
2. Click the **Geospatial** category chip to see boundaries, places, mobility,
   weather and address data from many providers.
3. Search for `Snowflake Public Data` and open **Snowflake Public Data
   (Free)**. Note that it's free, instantly accessible, and installed as
   `SNOWFLAKE_PUBLIC_DATA_FREE`.

**Why it matters:** the provider shares the data live. It appears as a
database in your account, with nothing copied and no pipeline to maintain.

The two kinds of table the labs use:

- `FEMA_NATIONAL_FLOOD_INSURANCE_PROGRAM_CLAIM_INDEX`: FEMA's public NFIP
  claims, one row per claim. `FLOOD_EVENT = 'Hurricane Sandy'` labels the
  event, and every row has a county and ZIP code.
- `GEOGRAPHY_INDEX` and `GEOGRAPHY_CHARACTERISTICS`: names and boundaries for
  counties and ZIP codes.

## 2. Catalog: what the data looks like

1. Go to **Horizon Catalog > Catalog > SNOWFLAKE_PUBLIC_DATA_FREE >
   PUBLIC_DATA_FREE > GEOGRAPHY_CHARACTERISTICS > Data Preview**.
2. Find rows where `RELATIONSHIP_TYPE = coordinates_wkt`.

**You should see:** boundaries stored as text, in a format called WKT. Text
isn't a shape yet. The lab turns it into one.

## 3. Workspaces: where you work

1. **Projects > Workspaces** is where you write and run SQL.
2. **Manage > Compute** lists warehouses. `SDSC_WORKSHOP_WH` is the one the
   setup script created.

## 4. The lab in SQL: types, functions, a surprise

Run [`labs/01_sandy_spatial.sql`](labs/01_sandy_spatial.sql). It's one script
with three steps and three knobs at the top (`within_m`, `distance_m`,
`min_claims`). Run it top to bottom; each step has its expected result
underneath.

### Step 1 · Types: Manhattan by ZIP code

**The question:** where in Manhattan were Sandy claims heaviest, and was it
only the southern tip?

- `manhattan_claims` counts Sandy claims per Manhattan ZIP code.
- `zip_shapes` uses `TO_GEOGRAPHY` to turn the WKT text into shapes.
- `southern_tip` takes the centre of ZIP 10004 (Battery Park).
- The `SELECT` returns each ZIP's area (`ST_AREA`), its distance from the tip
  (`ST_DISTANCE`), and whether it is within 3 km (`ST_DWITHIN`).

**You should see:** 10 rows. The top ZIP is 10009, the East Village, almost
5 km north of the tip. East Harlem (10029) is fifth, 12.5 km up.

**Your change:** set `within_m` to `6000` and rerun. Five more ZIPs turn
`TRUE`, but East Harlem stays `FALSE`. Distance from the tip doesn't explain
where Manhattan flooded.

**Note:** `GEOGRAPHY` measures on the round Earth, in metres. `GEOMETRY` is
for data already on a flat, projected map. The lab uses only `GEOGRAPHY`.

### Step 2 · Functions: counties near Manhattan, ranked two ways

**The question:** which counties near Manhattan were hit hardest, and does the
answer change if we rank by payout instead of count?

1. Count Sandy claims by county, with the mean building payout (records with
   no payment are excluded from the mean and counted in `paid_missing`).
2. Turn each county boundary into a geography (`TRY_TO_GEOGRAPHY`).
3. Keep counties within 25 km of Manhattan's boundary (`ST_DWITHIN`).
4. Rank the same counties by count and by mean paid.

**You should see:** 10 counties. Nassau is #1 by count. Manhattan is #9 by
count but **#1 by mean paid** ($236,483), and 223 of its 668 records have no
payment. Always check what's missing.

**What's missing:** Ocean County, New Jersey, the hardest-hit county of the
event with 37,459 claims. It's 60.6 km away.

**Your change:** set `distance_m` to `75000` and rerun: Ocean County is #1 by
count. Then set `min_claims` to `5000`: Manhattan and Brooklyn drop out. The
area you draw and the metric you pick decide the answer.

**Note:** these are whole-county totals for counties near Manhattan, not
claims inside a circle. FEMA's coordinates aren't precise enough for that.

### Step 3 · The surprise: were these properties in the flood zone?

**You should see:** half of East Harlem's claims (29 of 58) came from outside
FEMA's high-risk flood zone. Across Manhattan it's 188 of 668 claims (28%),
and they were paid more on average: about $265,000 against $228,000.

**Scale it (optional):** uncomment `USE WAREHOUSE SDSC_WORKSHOP_WH_LARGE;`
near the top and rerun. Same SQL, 16x the compute, one line. Compare the
times in Query History.

## 5. AI in the editor: Cortex Code

*Needs AI features. On a trial, watch this one on screen.*

1. Open `01_sandy_spatial.sql` in a Workspace and open **Cortex Code** (CoCo).
2. Ask: *"Explain Step 2 for an underwriter."* It describes each step in
   business language, including the county-level caveat.
3. Ask: *"Change the distance so Ocean County is included."* Run it. Ocean
   should be #1, matching your own change.
4. Paste **CoCo prompt 1** from the end of the SQL file (SQL to Python). Compare the result with
   [`labs/reference/02_sandy_spatial.py`](labs/reference/02_sandy_spatial.py).

**The habit:** AI made the change, and you checked it against a result you
already knew.

## 6. The same lab in Python

Open [`labs/reference/02_sandy_spatial.py`](labs/reference/02_sandy_spatial.py) in a Workspace
(**+ > Python file**, paste, run). Same three steps, same knobs, same numbers,
written with Snowpark DataFrames. Every `ST_*` function still runs inside
Snowflake; Python only builds the query.

**You should see:** the same three tables as Section 4.

## 7. The same lab as a notebook, with maps

Paste **CoCo prompt 2** from the end of the SQL file, or use the finished version:
Upload [`labs/reference/03_sandy_spatial.ipynb`](labs/reference/03_sandy_spatial.ipynb) to a
Workspace and **Run all**. Same SQL, plus what a worksheet can't do:

- **Step 1:** a ZIP map of Manhattan, coloured by Sandy claims.
- **Step 2:** twin county maps (count vs mean paid) and a rank-flip chart.
- **Step 2, live:** a slider that re-ranks counties by mean paid as you raise
  the minimum claim count. At 5,000, Manhattan and Brooklyn vanish and Queens
  leads.
- **Step 2b:** a Python loop that reruns the spatial query at ten distances.
  The #1 county goes Queens (up to 10 km), Nassau (from 20 km), then Ocean
  County (from 70 km).
- **Step 3:** inside vs outside the high-risk zone, as bars and a map.

Hover any map for the numbers. Change `distance_m` or `min_claims` in the
Parameters cell and **Run all** again.

## 8. Build the pipeline

Run [`labs/04_build_the_pipeline.sql`](labs/04_build_the_pipeline.sql).

**The question:** how does a one-off query become something a team uses every
day?

The file creates the database `SDSC_WORKSHOP` with two views over the
Marketplace share:

```
Marketplace share   SNOWFLAKE_PUBLIC_DATA_FREE          FEMA claims and boundaries
  filter            RAW.NFIP_CLAIMS_SANDY_NYNJ          132,388 Sandy claims, NY and NJ
  aggregate + geo   ANALYTICS.SANDY_COUNTY_CLAIMS       83 counties, with boundaries
  consumers         a map tool, an AI agent, a dashboard
```

**You should see:** the top five counties by count are Ocean, Nassau,
Suffolk, Atlantic and Cape May.

Then:

1. Open `SDSC_WORKSHOP.ANALYTICS.SANDY_COUNTY_CLAIMS` in the **Catalog** and
   look at **Definition**: Labs B and C, made permanent.
2. Click **Lineage**. Upstream is the FEMA share, and downstream is anything
   that reads the view.

**Why views:** for curated public data, views mean no copies and always-current,
auditable results. For streaming claims you could use a dynamic table instead,
with the same SQL refreshed incrementally.

## 9. Ecosystem: CARTO on the same data

*Needs a CARTO account (CARTO offers a free trial). On screen, we show this
from our account.*

Section 1 covered the data side of the ecosystem. This is the partner side: a
spatial tool working on the same result, with nothing exported.

1. In CARTO Workspace, go to **Connections** and add a **Snowflake**
   connection to your account.
2. In **Data Explorer**, open `SDSC_WORKSHOP.ANALYTICS.SANDY_COUNTY_CLAIMS`.
3. Create a map in **Builder**. Add the view as a source and style the
   `BOUNDARY` column as a county choropleth by `CLAIM_RECORDS`.
4. Switch the colour to `MEAN_BLDG_PAID_USD`. That's Step 2 of the lab, on a map.
5. Add a filter, for example `CLAIM_RECORDS >= 5000`, to match the lab's
   change.
6. Share the map. People can explore it without writing SQL.

Menu names can differ between CARTO versions. CARTO's documentation has the
current steps for connecting to Snowflake.

## 10. AI for the business user: CoWork

*Needs AI features. On a trial, watch this one on screen.*

1. Build the semantic view and agent. It needs section 8 first. Full
   instructions, prerequisites, and troubleshooting are in
   [`go-further/semantic-view-and-agent/`](go-further/semantic-view-and-agent/README.md).
   Pick one:
   - Paste the prompt in
     [`COCO_PROMPT.md`](go-further/semantic-view-and-agent/COCO_PROMPT.md)
     into Cortex Code, or
   - Run [`create-semantic-view-and-agent.sql`](go-further/semantic-view-and-agent/create-semantic-view-and-agent.sql), or
   - Upload [`sdsc_insurance.yaml`](go-further/semantic-view-and-agent/sdsc_insurance.yaml)
     in Snowsight.

   The semantic view holds the business definitions, such as what "mean
   paid" means and how to total counties. The agent uses it to write SQL.
2. Open **Snowflake CoWork** ([ai.snowflake.com](https://ai.snowflake.com))
   and choose `SDSC_FLOOD_RISK_AGENT`. If it isn't listed, see the
   troubleshooting table in that folder's README.
3. Ask: *"For counties with at least 500 claims, compare claim volume with
   mean paid amount. Show counts, missing payments, and the query. Explain
   what changed and why this doesn't establish future property risk."*

**Check three things:**

1. It shows the SQL it ran.
2. Manhattan's mean is about $236,483, the same as Step 2 of the lab.
3. It says historical claims are not future risk.

## 11. Clean up

Run [`labs/99_cleanup.sql`](labs/99_cleanup.sql). It drops only what this
workshop created: the `SDSC_WORKSHOP` database (if you ran section 8 or 10)
and the `SDSC_WORKSHOP_WH` warehouse. It doesn't touch the Marketplace
listing.

---

**Before drawing conclusions:** FEMA truncates public claim coordinates to
about 11 km for privacy and recommends county or census-tract aggregation.
These labs count by ZIP code and county and never infer property locations.
This is descriptive history for one event, not a flood-risk model or an
underwriting recommendation. Sources are in [`SOURCES.md`](SOURCES.md).
