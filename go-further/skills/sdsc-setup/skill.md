---
name: sdsc-setup
description: >
  Set up the Spatial Intelligence for Insurance demo environment on your own
  Snowflake account: database/schema/warehouse, a semantic view, a Cortex
  Agent, a scoped viewer role, and (optionally) the CARTO MCP connector.
  Sample Hurricane Sandy NFIP data loading is optional -- skip it and point
  the semantic view at your own geospatial dataset instead. Use when a
  workshop attendee or reader wants to replicate the SDSC 2026 New York demo,
  or wants a working example of a semantic view + Cortex Agent + MCP
  connector pattern to adapt for a different industry.
---

# SDSC Spatial Intelligence Setup Skill

This skill recreates the environment behind the **Spatial Intelligence for
Insurance: From Risk and Exposure to Action** workshop (SDSC 2026 New York).
It is a reference implementation, not a packaged installer -- read each step,
adapt names/values to your account, and run the SQL yourself. Steps 1-4 and 6
are required to get a working agent. Step 5 (CARTO) is optional. The data
load in step 3b is optional.

## What you end up with

- A database with `RAW` / `ANALYTICS` / `SEMANTIC` schemas
- A semantic view defining business terms over your data (exposure, risk
  tier, whatever fits your domain)
- A Cortex Agent that answers natural-language questions using that semantic
  view, queryable through Snowflake CoWork with native map rendering
- (Optional) The CARTO MCP Server attached to the same agent, so it can
  geocode, compute isochrones, and enrich data via CARTO's Data Observatory
- A viewer role scoped to exactly what an end user should see

## Step 1 (required): Database foundation

```sql
CREATE DATABASE IF NOT EXISTS MY_SPATIAL_DEMO;
CREATE WAREHOUSE IF NOT EXISTS MY_SPATIAL_DEMO_WH
  WAREHOUSE_SIZE = 'MEDIUM'
  AUTO_SUSPEND = 300
  AUTO_RESUME = TRUE;

CREATE SCHEMA IF NOT EXISTS MY_SPATIAL_DEMO.RAW;
CREATE SCHEMA IF NOT EXISTS MY_SPATIAL_DEMO.ANALYTICS;
CREATE SCHEMA IF NOT EXISTS MY_SPATIAL_DEMO.SEMANTIC;
```

## Step 2 (optional): Open geospatial data from the Marketplace

If you want free, open geospatial context data (places, administrative
boundaries, buildings, transportation) without any ETL, get it from the
Marketplace:

1. In Snowsight, go to **Data Products &gt; Marketplace**
2. Search for **Overture Maps** and get the listing
3. It imports as a share -- query it directly, no loading required

Skip this step entirely if you only need your own proprietary data.

## Step 3a (required): Your own analytical tables

Land your source data in `RAW`, and build whatever aggregation your use case
needs in `ANALYTICS`. The Sandy reference implementation uses:

- `RAW.NFIP_CLAIMS_SANDY` -- individual claim records with `LATITUDE`,
  `LONGITUDE`, and coordinate columns
- `ANALYTICS.SANDY_CLAIMS_GEOCODED` -- claims geocoded via Overture Maps ZIP
  centroids, with `LOCATION` (GEOGRAPHY point) and H3 cell IDs at res 7/8/9
- `ANALYTICS.SANDY_EXPOSURE_H3_V2` -- claims aggregated into 354 H3 hexagons
  at resolution 8, with per-hex `CLAIM_COUNT`, `TOTAL_DAMAGE`,
  `AVG_FLOOD_DEPTH`, and a `BOUNDARY` column (GEOGRAPHY polygon)

If you are adapting this for a different domain, the pattern that matters is:
**a point-level fact table with a `GEOGRAPHY` column, aggregated into an H3
grid, joined back to whatever record needs the zone-level context.** Swap
claims/policies for deliveries/routes, incidents/facilities, or whatever your
domain's point and zone data are.

## Step 3b (optional): Load the sample Hurricane Sandy dataset

Only needed if you want to run the demo with the exact same data used at
SDSC. The source is FEMA's National Flood Insurance Program (NFIP) public
claims and policy data, filtered to Hurricane Sandy / New York.

1. Download the NFIP claims and policies extracts from FEMA's OpenFEMA API
   (`https://www.fema.gov/openfema-data-page/fima-nfip-redacted-claims-v2`
   and the corresponding policies dataset)
2. Filter to the Sandy event window and New York geography
3. Load into `RAW.NFIP_CLAIMS_SANDY` / `RAW.NFIP_POLICIES_SANDY_AREA` via
   `COPY INTO` from a stage
4. Build the `GEO` column: `UPDATE ... SET geo = ST_MAKEPOINT(longitude, latitude)`
5. Build the H3 exposure aggregation and policy join described in Step 3a

If you would rather bring your own dataset, skip this entirely -- just make
sure your fact table has a `GEOGRAPHY` column (or lat/lon you can convert)
and go straight to Step 3a's pattern.

## Step 4 (required): Semantic view

Define your business terms once. Minimal shape:

```yaml
name: my_exposure_view
tables:
  - name: policy_exposure
    base_table:
      database: MY_SPATIAL_DEMO
      schema: ANALYTICS
      table: POLICY_EXPOSURE
    dimensions:
      - name: risk_tier
        expr: RISK_TIER
      - name: occupancy_type
        expr: OCCUPANCY_TYPE
    facts:
      - name: insured_value
        expr: TOTAL_BUILDING_INSURANCE_COVERAGE + TOTAL_CONTENTS_INSURANCE_COVERAGE
metrics:
  - name: total_exposure
    expr: SUM(insured_value)
```

Adapt the table names, dimensions, and metrics to your own schema. See
Snowflake's semantic view documentation for the full spec.

```sql
CREATE OR REPLACE SEMANTIC VIEW MY_SPATIAL_DEMO.SEMANTIC.MY_EXPOSURE_VIEW
  FROM SPECIFICATION $$ <paste your YAML here> $$;
```

## Step 5 (required): Cortex Agent

```sql
CREATE OR REPLACE AGENT MY_SPATIAL_DEMO.SEMANTIC.MY_EXPOSURE_AGENT
  COMMENT = 'Answers exposure and risk questions over the semantic view.'
  FROM SPECIFICATION $$
  {
    "models": { "orchestration": "claude-sonnet-4-6" },
    "tools": [
      {
        "tool_spec": {
          "type": "cortex_analyst_text_to_sql",
          "name": "exposure_analyst",
          "description": "Answers questions about insured exposure and risk."
        }
      }
    ],
    "tool_resources": {
      "exposure_analyst": {
        "semantic_view": "MY_SPATIAL_DEMO.SEMANTIC.MY_EXPOSURE_VIEW",
        "warehouse": "MY_SPATIAL_DEMO_WH"
      }
    }
  }
  $$;
```

Test it in Snowflake CoWork before moving on: open CoWork, start a new chat,
select your agent, and ask a question that should hit your semantic view.

## Step 6 (optional): CARTO MCP connector

Requires a CARTO account. The client **must be confidential and have a
Client Secret** -- Snowflake does not support public/PKCE-only clients for
this integration.

1. In CARTO, go to **Developers &gt; Credentials &gt; SPA OAuth Clients**,
   create a client, and copy its Client ID and Client Secret
2. In that same client's settings, turn off "Use default logout/callback
   URLs and Origins" and add `https://identity.snowflake.com/oauth2/callback`
   to Allowed Callback URLs
3. In Snowflake, as ACCOUNTADMIN:

```sql
CREATE API INTEGRATION CARTO_MCP_OAUTH2
  API_PROVIDER = external_mcp
  API_ALLOWED_PREFIXES = ('https://<region>.api.carto.com')
  API_USER_AUTHENTICATION = (
    TYPE = OAUTH2
    OAUTH_CLIENT_ID = '<the actual Client ID, not the client display name>'
    OAUTH_CLIENT_SECRET = '<the Client Secret>'
    OAUTH_TOKEN_ENDPOINT = 'https://auth.carto.com/oauth/token'
    OAUTH_AUTHORIZATION_ENDPOINT = 'https://auth.carto.com/authorize'
    OAUTH_CLIENT_AUTH_METHOD = CLIENT_SECRET_BASIC
    OAUTH_ALLOWED_SCOPES = ('openid','profile','email','read:workflows','write:workflows')
  )
  ENABLED = TRUE;

CREATE EXTERNAL MCP SERVER MY_SPATIAL_DEMO.PUBLIC.CARTO_MCP
  WITH DISPLAY_NAME = 'CARTO MCP'
  URL = 'https://<region>.api.carto.com/mcp/<your_account_id>'
  API_INTEGRATION = CARTO_MCP_OAUTH2;
```

4. In Snowsight, open your agent, go to **MCP Connectors**, add the CARTO
   MCP server, and complete the OAuth consent flow

**Common failure:** `invalid_request: Unknown client` means the Client ID
field was filled with the client's display name instead of its actual
Client ID hash. Double-check you copied the ID, not the name.

## Step 7 (required): Viewer role

```sql
CREATE ROLE IF NOT EXISTS MY_SPATIAL_VIEWER;

GRANT USAGE ON DATABASE MY_SPATIAL_DEMO TO ROLE MY_SPATIAL_VIEWER;
GRANT USAGE ON SCHEMA MY_SPATIAL_DEMO.SEMANTIC TO ROLE MY_SPATIAL_VIEWER;
GRANT USAGE ON WAREHOUSE MY_SPATIAL_DEMO_WH TO ROLE MY_SPATIAL_VIEWER;
GRANT USAGE ON SEMANTIC VIEW MY_SPATIAL_DEMO.SEMANTIC.MY_EXPOSURE_VIEW TO ROLE MY_SPATIAL_VIEWER;
GRANT USAGE ON AGENT MY_SPATIAL_DEMO.SEMANTIC.MY_EXPOSURE_AGENT TO ROLE MY_SPATIAL_VIEWER;

-- If you added the CARTO MCP connector:
GRANT USAGE ON EXTERNAL MCP SERVER MY_SPATIAL_DEMO.PUBLIC.CARTO_MCP TO ROLE MY_SPATIAL_VIEWER;
GRANT USAGE ON INTEGRATION CARTO_MCP_OAUTH2 TO ROLE MY_SPATIAL_VIEWER;

GRANT ROLE MY_SPATIAL_VIEWER TO USER <username>;
```

This role can use the agent through CoWork but cannot see raw tables, modify
the semantic view, or change the agent spec.

## Verifying it works

1. Sign in to Snowsight as a user with `MY_SPATIAL_VIEWER`
2. Open CoWork, start a new chat, select the agent
3. Ask a question that should hit the semantic view (e.g. "what is our total
   insured exposure?")
4. If you added a `GEOGRAPHY` column, ask for a map (e.g. "show me the top
   exposure hotspots as H3 hexagons")
5. If you added CARTO, ask something that needs geocoding or isochrones

If step 3-4 fail, check that the semantic view's table/column references
match your actual schema. If step 6 fails with an OAuth error, see the
troubleshooting note above.
