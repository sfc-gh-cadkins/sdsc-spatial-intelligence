---
name: sdsc-setup
description: >
  Set up the Spatial Intelligence for Insurance demo environment on your own
  Snowflake account: warehouse, database and schemas, a semantic view, a
  Cortex Agent, a scoped viewer role, and (optionally) the CARTO MCP
  connector. The data comes free from the Snowflake Marketplace. Use when a
  workshop attendee or reader wants to replicate the SDSC 2026 New York demo,
  or wants a working example of a semantic view + Cortex Agent + MCP
  connector pattern to adapt for a different industry.
---

# SDSC Spatial Intelligence Setup Skill

This skill recreates the environment behind the **Spatial Intelligence for
Insurance: From Risk and Exposure to Action** workshop (SDSC 2026 New York).
It is a reference implementation, not a packaged installer: read each step,
adapt names and values to your account, and run the SQL yourself. Steps 1 to 5
and 7 are required to get a working agent. Step 6 (CARTO) is optional.

It uses the same object names as the labs (`SDSC_WORKSHOP`,
`SDSC_WORKSHOP_WH`), so the files in this repo run as-is. If you want
different names, find-and-replace them in every file you run.

**AI features:** steps 4, 5 and 7 need Cortex AI features. Self-service
trials disable them until a payment method is added.

## What you end up with

- A database with `RAW` / `ANALYTICS` / `SEMANTIC` schemas
- A semantic view defining business terms over the county claims view
- A Cortex Agent that answers natural-language questions using that semantic
  view, and shows the SQL it ran, in Snowflake CoWork
- (Optional) The CARTO MCP Server attached to the same agent, so it can use
  CARTO tools
- A viewer role scoped to what an end user should see

## Step 1 (required): Get the free data

In Snowsight, open **Marketplace**, find **Snowflake Public Data (Free)**, and
click **Get**. It imports as a share named `SNOWFLAKE_PUBLIC_DATA_FREE`, with
FEMA's public NFIP claims and county and ZIP code boundaries. Nothing to load.

## Step 2 (required): Warehouse and readiness check

Run `labs/00_setup_and_check.sql`. It creates the `SDSC_WORKSHOP_WH`
warehouse and checks that the Marketplace data is reachable.

## Step 3 (required): Your analytical layer

Run `labs/04_build_the_pipeline.sql`. It creates the `SDSC_WORKSHOP`
database and builds two views over the share:

- `SDSC_WORKSHOP.RAW.NFIP_CLAIMS_SANDY_NYNJ`: Hurricane Sandy claims for NY and NJ
- `SDSC_WORKSHOP.ANALYTICS.SANDY_COUNTY_CLAIMS`: one row per county, with
  claim counts, payments, and a `BOUNDARY` column (GEOGRAPHY polygon)

**Grain matters.** FEMA truncates public claim coordinates to about 11 km for
privacy and recommends county or census-tract aggregation. Don't geocode
individual claims to points or hexagons: that implies precision the source
removed. If you adapt this for your own data, aggregate to the finest zone
your data genuinely supports.

## Steps 4 and 5 (required): Semantic view and Cortex Agent

Run `go-further/semantic-view-and-agent/create-semantic-view-and-agent.sql`.
It creates:

- `SDSC_WORKSHOP.SEMANTIC.SDSC_INSURANCE`: the semantic view, with metrics
  that roll counties up correctly
- `SDSC_WORKSHOP.SEMANTIC.SDSC_FLOOD_RISK_AGENT`: the agent you chat with in
  CoWork

The same file includes a check query (Brooklyn should show 3,561 claims) and
the step to make the agent visible in CoWork. The folder's `README.md` covers
troubleshooting, and `COCO_PROMPT.md` lets Cortex Code build it for you.

Test it in Snowflake CoWork before moving on: open CoWork, start a new chat,
select `SDSC_FLOOD_RISK_AGENT`, and ask "Which counties had the most Sandy
claims?"

## Step 6 (optional): CARTO MCP connector

Requires a CARTO account.

1. In CARTO, go to **Developers > Credentials > SPA OAuth Clients**,
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

CREATE EXTERNAL MCP SERVER SDSC_WORKSHOP.PUBLIC.CARTO_MCP
  WITH DISPLAY_NAME = 'CARTO MCP'
  URL = 'https://<region>.api.carto.com/mcp/<your_account_id>'
  API_INTEGRATION = CARTO_MCP_OAUTH2;
```

CARTO's **Workflow API & MCP Server** page shows the full MCP URL, including
`<region>` and `<your_account_id>`.

4. In Snowsight, open your agent, go to **MCP Connectors**, add the CARTO
   MCP server, and complete the OAuth consent flow

**Common failure:** `invalid_request: Unknown client` means the Client ID
field was filled with the client's display name instead of its actual
Client ID. Double-check you copied the ID, not the name.

## Step 7 (required): Viewer role

```sql
CREATE ROLE IF NOT EXISTS SDSC_VIEWER;

GRANT USAGE ON DATABASE SDSC_WORKSHOP TO ROLE SDSC_VIEWER;
GRANT USAGE ON SCHEMA SDSC_WORKSHOP.ANALYTICS TO ROLE SDSC_VIEWER;
GRANT USAGE ON SCHEMA SDSC_WORKSHOP.SEMANTIC TO ROLE SDSC_VIEWER;
GRANT SELECT ON ALL VIEWS IN SCHEMA SDSC_WORKSHOP.ANALYTICS TO ROLE SDSC_VIEWER;
GRANT SELECT ON SEMANTIC VIEW SDSC_WORKSHOP.SEMANTIC.SDSC_INSURANCE TO ROLE SDSC_VIEWER;
GRANT USAGE ON AGENT SDSC_WORKSHOP.SEMANTIC.SDSC_FLOOD_RISK_AGENT TO ROLE SDSC_VIEWER;
GRANT USAGE ON WAREHOUSE SDSC_WORKSHOP_WH TO ROLE SDSC_VIEWER;
-- The views read a Marketplace share, so the role also needs:
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_PUBLIC_DATA_FREE TO ROLE SDSC_VIEWER;

-- If you added the CARTO MCP connector:
GRANT USAGE ON SCHEMA SDSC_WORKSHOP.PUBLIC TO ROLE SDSC_VIEWER;
GRANT USAGE ON EXTERNAL MCP SERVER SDSC_WORKSHOP.PUBLIC.CARTO_MCP TO ROLE SDSC_VIEWER;
GRANT USAGE ON INTEGRATION CARTO_MCP_OAUTH2 TO ROLE SDSC_VIEWER;

GRANT ROLE SDSC_VIEWER TO USER <username>;
```

This role can query the analytics views and use the agent through CoWork, but
cannot modify the semantic view or change the agent spec.

## Verifying it works

1. Sign in to Snowsight as a user with `SDSC_VIEWER`
2. Open CoWork, start a new chat, select `SDSC_FLOOD_RISK_AGENT`
3. Ask "Which counties had the most Sandy claims?"
4. Ask "What was the mean paid amount in NY versus NJ?"
5. If you added CARTO, ask something that needs a CARTO tool

If 3 or 4 fail, check that the semantic view's table and column references
match your schema and that the role has the grants above. If 5 fails with
an OAuth error, see the common failure note in step 6.
