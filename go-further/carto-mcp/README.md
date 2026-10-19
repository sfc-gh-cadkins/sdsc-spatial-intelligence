# Connect the CARTO MCP Server to Snowflake

This connects CARTO's MCP server to a Cortex Agent, so the agent (and CoWork)
can use CARTO tools, for example "make that a CARTO Builder map I can share".
It's the connection behind the CoWork section of the workshop.

You don't need this for the lab.

## What you need

- A **CARTO account** with permission to create OAuth clients.
- A Snowflake role that can create integrations. On a trial, use
  `ACCOUNTADMIN`.
- **AI features on** in Snowflake. Trials need a payment method first.
- A **Cortex Agent** to attach it to. The
  [semantic view and agent](../semantic-view-and-agent/README.md) folder
  builds `SDSC_WORKSHOP.SEMANTIC.SDSC_FLOOD_RISK_AGENT`.

## 1. Create an OAuth client in CARTO

1. In CARTO, go to **Developers » Credentials » SPA OAuth Clients** and
   create a client.
2. Copy its **Client ID** and **Client Secret**. Copy the ID, not the client's
   display name.
3. In the client's settings, turn off **Use default logout/callback URLs and
   Origins**. Add both of these to **Allowed Callback URLs**:

   ```
   https://identity.snowflake.com/oauth2/callback
   https://apps-api.c1.<your-snowflake-region>.app.snowflake.com/oauth/complete-secret
   ```

   To find the second one for your account, run
   `SELECT SYSTEM$ALLOWLIST();` and look for the `apps-api` host.

## 2. Find your MCP URL

In CARTO, open **Settings » CARTO MCP Server** and copy the URL. It looks like:

```
https://<carto-region>.api.carto.com/mcp/<your_account_id>
```

Use the copy button. Account IDs mix look-alike characters such as `i` and
`l`, and a wrong ID can still connect, just to the wrong organization. The ID
should match your **Organization ID** under **Settings » General**.

## 3. Create the integration and MCP server in Snowflake

Run as `ACCOUNTADMIN`. Replace every `<...>` value.

```sql
CREATE API INTEGRATION CARTO_MCP_OAUTH2
  API_PROVIDER = external_mcp
  API_ALLOWED_PREFIXES = ('https://<carto-region>.api.carto.com')
  API_USER_AUTHENTICATION = (
    TYPE = OAUTH2
    OAUTH_CLIENT_ID = '<Client ID>'
    OAUTH_CLIENT_SECRET = '<Client Secret>'
    OAUTH_TOKEN_ENDPOINT = 'https://auth.carto.com/oauth/token'
    OAUTH_AUTHORIZATION_ENDPOINT = 'https://auth.carto.com/authorize?audience=carto-cloud-native-api'
    OAUTH_CLIENT_AUTH_METHOD = CLIENT_SECRET_BASIC
    OAUTH_ALLOWED_SCOPES = ('openid','profile','email','read:workflows','write:workflows')
  )
  ENABLED = TRUE;

CREATE SCHEMA IF NOT EXISTS SDSC_WORKSHOP.PUBLIC;

CREATE EXTERNAL MCP SERVER SDSC_WORKSHOP.PUBLIC.CARTO_MCP
  WITH DISPLAY_NAME = 'CARTO MCP'
  URL = 'https://<carto-region>.api.carto.com/mcp/<your_account_id>'
  API_INTEGRATION = CARTO_MCP_OAUTH2;

SHOW EXTERNAL MCP SERVERS IN SCHEMA SDSC_WORKSHOP.PUBLIC;
```

Keep the Client Secret out of files you commit or share.

`CREATE OR REPLACE` isn't supported for `external_mcp` integrations. To change
the client later, use
`ALTER API INTEGRATION CARTO_MCP_OAUTH2 SET API_USER_AUTHENTICATION = (...)`.

## 4. If your account has a network policy

Skip this on a new trial. If your account restricts IPs, CARTO's servers must
be allowed to reach Snowflake. Add CARTO's egress IPs, listed in CARTO's
documentation for your CARTO region, to the network rule your policy uses.
Check with:

```sql
SHOW PARAMETERS LIKE 'NETWORK_POLICY' IN ACCOUNT;
```

## 5. Attach it to your agent and sign in

1. In Snowsight, open **AI & ML » Agents**, then your agent.
2. Go to **MCP Connectors**, add **CARTO MCP**, and save.
3. Open the agent in CoWork and ask something that needs CARTO. The first
   time, CoWork asks you to sign in to CARTO. Each user signs in with their
   own CARTO account.

To let a non-admin role use it:

```sql
GRANT USAGE ON SCHEMA SDSC_WORKSHOP.PUBLIC TO ROLE <role>;
GRANT USAGE ON EXTERNAL MCP SERVER SDSC_WORKSHOP.PUBLIC.CARTO_MCP TO ROLE <role>;
GRANT USAGE ON INTEGRATION CARTO_MCP_OAUTH2 TO ROLE <role>;
```

## 6. Test it

In CoWork, ask:

> Show building damage by county on a map

then:

> Now make that a CARTO Builder map I can share

You should get a CARTO map link.

Tip: in the agent's orchestration instructions, tell it to answer data
questions from the semantic view and use CARTO only when asked for a CARTO
map. Otherwise it may route every question to CARTO.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `invalid_request: Unknown client` | The Client ID field holds the client's display name. Paste the real Client ID. |
| `Callback URL mismatch` at sign-in | A callback URL from step 1 is missing or has a typo. |
| Sign-in works but token errors follow | Check `OAUTH_AUTHORIZATION_ENDPOINT` includes `?audience=carto-cloud-native-api`. |
| Connected, but no tools or the wrong data | The account ID in the MCP URL doesn't match your CARTO Organization ID. |
| No CARTO sign-in prompt after reconnecting | Snowflake keeps your CARTO token per user and reuses it. To force a fresh sign-in, create a new MCP server object. |
| Timeouts reaching CARTO | Your network policy blocks CARTO. See step 4. |
