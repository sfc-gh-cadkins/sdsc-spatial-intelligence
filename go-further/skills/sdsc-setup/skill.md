---
name: sdsc-setup
description: >
  Set up the Spatial Intelligence for Insurance demo environment on your own
  Snowflake account: database/schema/warehouse, a semantic view, a Cortex
  Agent, a scoped viewer role, and (optionally) the CARTO MCP connector.
  The data comes free from the Snowflake Marketplace. Use when a
  workshop attendee or reader wants to replicate the SDSC 2026 New York demo,
  or wants a working example of a semantic view + Cortex Agent + MCP
  connector pattern to adapt for a different industry.
---

# SDSC Spatial Intelligence Setup Skill

This skill recreates the environment behind the **Spatial Intelligence for
Insurance: From Risk and Exposure to Action** workshop (SDSC 2026 New York).
It is a reference implementation, not a packaged installer -- read each step,
adapt names/values to your account, and run the SQL yourself. Steps 1 to 5 and 7
are required to get a working agent. Step 6 (CARTO) is optional.

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

## Step 2 (required): Get the free data

In Snowsight, open **Marketplace**, find **Snowflake Public Data (Free)**, and
click **Get**. It imports as a share named `SNOWFLAKE_PUBLIC_DATA_FREE`, with
FEMA's public NFIP claims and county and ZIP code boundaries. Nothing to load.

## Step 3 (required): Your analytical layer

The workshop builds two views over the share. Run
`labs/04_build_the_pipeline.sql` from this repo, or adapt it:

- `RAW.NFIP_CLAIMS_SANDY_NYNJ`: Hurricane Sandy claims for NY and NJ
- `ANALYTICS.SANDY_COUNTY_CLAIMS`: one row per county, with claim counts,
  payments, and a `BOUNDARY` column (GEOGRAPHY polygon)

**Grain matters.** FEMA truncates public claim coordinates to about 11 km for
privacy and recommends county or census-tract aggregation. Don't geocode
individual claims to points or hexagons: that implies precision the source
removed. If you adapt this for your own data, aggregate to the finest zone
your data genuinely supports.

## Step 4 (required): Semantic view

Define your business terms once. `go-further/ai-agent-reference.sql` has a
working semantic view over `ANALYTICS.SANDY_COUNTY_CLAIMS`. It's created with
the YAML procedure:

```sql
CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML('MY_SPATIAL_DEMO.SEMANTIC', $$
name: MY_EXPOSURE_VIEW
tables:
  - name: county_claims
    base_table: { database: MY_SPATIAL_DEMO, schema: ANALYTICS, table: SANDY_COUNTY_CLAIMS }
    ...
$$);
```

Adapt the table names, dimensions, and facts to your own schema. See
Snowflake's semantic view documentation for the full spec.

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
4. Ask for a county comparison (e.g. "compare claim volume with mean paid
   amount by county")
5. If you added CARTO, ask something that needs geocoding or isochrones

If steps 3 or 4 fail, check that the semantic view's table/column references
match your actual schema. If step 6 fails with an OAuth error, see the
troubleshooting note above.
