# Custom AI function: FLOOD_RISK_CLASSIFIER

A custom AI function that sorts an insured property into one of four flood
risk tiers: Critical, High, Moderate, or Low. It also returns a one-sentence
reason. It's the same logic the Flood Risk Hub app uses for its AI step.

You call it like any other SQL function:

```sql
SELECT SDSC_WORKSHOP.SEMANTIC.FLOOD_RISK_CLASSIFIER('VE', 'Single family', -2, 13, 180000);
-- {"risk_tier": "Critical", "explanation": "..."}
```

You don't need this for the lab.

## What's inside

The function wraps `AI_COMPLETE` with:

- **Fixed rules.** The tier rules live in the function, so every caller gets
  the same definition of "Critical" instead of writing their own prompt.
- **A JSON response schema.** Every call returns exactly `risk_tier` and
  `explanation`, so you can read the result with `:risk_tier::STRING`.
- **Missing-data handling.** NULL inputs are sent as "Unknown", and the
  function still returns its best tier.

| Argument | Type | Example |
|---|---|---|
| `FLOOD_ZONE` | VARCHAR | `'VE'`, `'AE'`, `'X'` |
| `BUILDING_TYPE` | VARCHAR | `'Single family'` |
| `ELEVATION_DIFFERENCE` | FLOAT | feet above (+) or below (-) base flood elevation |
| `FLOOD_DEPTH` | FLOAT | feet of water |
| `BUILDING_DAMAGE_AMOUNT` | FLOAT | dollars |

## Before you start

1. **AI features must be on.** Self-service trial accounts disable Cortex AI
   until you add a payment method (Admin » Billing).
2. **Role.** On a trial, use `ACCOUNTADMIN`. Otherwise you need
   `CREATE FUNCTION` on the schema, `USAGE` on the warehouse, and the
   `SNOWFLAKE.CORTEX_USER` database role.
3. **Model and region.** The function uses `claude-sonnet-4-6`. If you get
   "model not available", an admin can run
   `ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';`, or you can
   change the model name in the script to one listed by
   `SHOW CORTEX BASE MODELS IN SCHEMA SNOWFLAKE.MODELS;`.
4. **Names.** The script uses `SDSC_WORKSHOP` and `SDSC_WORKSHOP_WH`, the same
   as the labs. If you used other names, find-and-replace them.
5. **Data.** Step 3 reads the free *Snowflake Public Data (Free)* Marketplace
   listing. Click **Get** on it first. You don't need to build the pipeline.

## Run it

Open [`create-flood-risk-classifier.sql`](create-flood-risk-classifier.sql) in
a Snowsight worksheet and run it top to bottom:

1. Creates the function.
2. Scores two made-up properties. Expect Critical and Moderate.
3. Scores 10 real Hurricane Sandy claims.

## Cost and results

Each row is one model call, billed as Cortex AI credits. Keep the `LIMIT`
while you test, and score a summary table rather than every claim.

The tier comes from a language model, so it can vary between runs and
sometimes bend the rules, especially when most inputs are Unknown. Treat it
as a triage aid, not an underwriting decision. Check the `explanation`
column, and use plain SQL `CASE` logic where you need an exact, repeatable
rule.
