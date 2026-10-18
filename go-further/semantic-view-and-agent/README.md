# Semantic view and Cortex Agent

This folder builds the AI layer from the CoWork section of the workshop:

| Object | What it is |
|---|---|
| `SDSC_WORKSHOP.SEMANTIC.SDSC_INSURANCE` | A **semantic view**: business definitions over the county view, for example what "mean paid" means and how to total counties correctly |
| `SDSC_WORKSHOP.SEMANTIC.SDSC_FLOOD_RISK_AGENT` | A **Cortex Agent** that turns a plain-English question into SQL over the semantic view. You chat with it in Snowflake CoWork |

You don't need any of this for the lab.

## Files

| File | Use it when |
|---|---|
| [`COCO_PROMPT.md`](COCO_PROMPT.md) | You want Cortex Code to build it with you. It checks your account first and asks before changing anything |
| [`create-semantic-view-and-agent.sql`](create-semantic-view-and-agent.sql) | You want to paste one script into a worksheet and run it |
| [`sdsc_insurance.yaml`](sdsc_insurance.yaml) | You want to read the definitions, upload them in Snowsight, or reuse them in your own tool. It's the same YAML that the SQL file uses |

## Before you start

Go through this list once. Most problems come from one of these.

1. **Build the pipeline first.** Run
   [`../../labs/04_build_the_pipeline.sql`](../../labs/04_build_the_pipeline.sql).
   Everything here reads `SDSC_WORKSHOP.ANALYTICS.SANDY_COUNTY_CLAIMS`.
   Check it with `SELECT COUNT(*) FROM SDSC_WORKSHOP.ANALYTICS.SANDY_COUNTY_CLAIMS;`,
   which should return 83.
2. **AI features must be on.** Semantic views are standard SQL, but Cortex
   Code, the agent, and CoWork all need Cortex AI. Self-service trial
   accounts disable AI features until you add a payment method (Admin »
   Billing). If you can't or don't want to, see
   [No AI features?](#no-ai-features) below.
3. **Region.** Cortex models aren't hosted in every region. If you get
   "model not available" errors, an admin can enable cross-region
   inference: `ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';`.
4. **Role.** On a trial, use `ACCOUNTADMIN`. On a company account, your
   role needs:
   - `USAGE` on the database and schemas, and `CREATE SCHEMA` if
     `SDSC_WORKSHOP.SEMANTIC` doesn't exist yet
   - `CREATE SEMANTIC VIEW` and `CREATE AGENT` on `SDSC_WORKSHOP.SEMANTIC`
   - `SELECT` on `SDSC_WORKSHOP.ANALYTICS.SANDY_COUNTY_CLAIMS`
   - `USAGE` on the warehouse
   - The `SNOWFLAKE.CORTEX_USER` database role. It's granted to `PUBLIC` by
     default, but some companies revoke it. If so, ask your admin for
     `CORTEX_USER` or `CORTEX_AGENT_USER`.
5. **Names.** The files use `SDSC_WORKSHOP` (database) and
   `SDSC_WORKSHOP_WH` (warehouse). If you used other names, find-and-replace
   them in the file you're running. In the YAML, the database name is under
   `base_table`.
6. **Existing objects.** Both scripts replace a semantic view or agent with
   the same name. If you already have objects with these names that you want
   to keep, rename `SDSC_INSURANCE` (the `name:` line of the YAML) and
   `SDSC_FLOOD_RISK_AGENT` first. If you rename the semantic view, also
   update `semantic_view:` in the agent spec.

## Build it: pick one path

### Path A: Cortex Code

Open [`COCO_PROMPT.md`](COCO_PROMPT.md), edit the **Names** block if needed,
and paste the prompt into Cortex Code. It runs read-only checks first, shows
you the YAML, validates it, and asks before creating anything.

### Path B: SQL worksheet

Open [`create-semantic-view-and-agent.sql`](create-semantic-view-and-agent.sql)
in a Snowsight worksheet and select **Run All**. It:

1. Creates the semantic view from the YAML.
2. Runs a check query. Brooklyn should show 3,561 claims, 3,400 with a
   payment, and a mean of about 81,335.
3. Creates the agent.
4. Runs `SHOW SNOWFLAKE INTELLIGENCES`. If that returns a row, run the
   commented `ALTER ... ADD AGENT` line using the name it returned (see
   [Troubleshooting](#troubleshooting)).

### Path C: Snowsight UI with the YAML

1. Download [`sdsc_insurance.yaml`](sdsc_insurance.yaml).
2. In Snowsight, go to **Workspaces » Add new » Semantic View**.
3. Choose the option to upload a YAML specification, and save to
   `SDSC_WORKSHOP.SEMANTIC`.
4. Create the agent: in **AI & ML » Agents**, select **Create agent**, add a
   Cortex Analyst tool that uses `SDSC_WORKSHOP.SEMANTIC.SDSC_INSURANCE` and
   your warehouse, and copy the instructions from step 3 of the SQL file. Or
   run just step 3 of the SQL file.

Snowsight menus change from time to time. If a menu name doesn't match, use
Path B.

## Use it

1. Go to [ai.snowflake.com](https://ai.snowflake.com), or **AI & ML » Agents**
   » select the agent » **Preview in Snowflake CoWork**.
2. Choose `SDSC_FLOOD_RISK_AGENT`.
3. Try:
   - "Which counties had the most Sandy claims?"
   - "Compare claim volume with mean paid amount for counties with at least
     500 claims."
   - "What was the mean paid amount in NY versus NJ?"
4. Open the SQL the agent ran. For the NY versus NJ question, it should
   divide total paid by total claims with a payment (the `mean_paid_usd`
   metric), not average the county means.

CoWork can draw bar, line, scatter, and other charts, but not maps. For
the map, use the county view's `BOUNDARY` column in CARTO or another map
tool.

## Schedule it: CoWork automations

An automation subscribes you to a question. On each run, CoWork asks the
question again against the current data and emails you a summary with a link
to the full thread, where you can ask follow-up questions.

**From the chat.** After an answer you like, reply:

> "Send me this as a short briefing every Monday at 8 AM: the top five counties
> by claims and by mean paid, plus anything that changed since the last run."

CoWork confirms the schedule and the first delivery date. You can also start
from the **Automations** tab: select **Create automation**, then give it a
name, the instructions (the question), and a frequency.

**Manage it in plain language:**

| To do this | Say something like |
|---|---|
| List them | "What automations do I have?" |
| Change the time | "Move my Monday Sandy briefing to 7 AM." |
| Pause or resume | "Pause my Monday Sandy briefing." |
| Delete | "Delete my Monday Sandy briefing." |

**Worth knowing:**

- **It runs as you.** Each run uses your own role and warehouse, so role-based
  access, row access policies, and masking policies all still apply.
- **It costs compute.** Each run is billed as a standard Snowflake task. The
  shortest schedule is hourly. Delete demo automations after the workshop.
- **Email needs a verified address.** Without one, you can still create the
  automation and review its runs in the Automations tab.
- **Admins control access** through the `EXECUTE AGENT TASK` account
  privilege, which is granted to `PUBLIC` by default.
- **The data here is historical.** Sandy claims don't change, so a weekly
  briefing on this dataset shows the mechanics, not new information. Point the
  same pattern at data that changes to get real value from it.

See [Automations in Snowflake CoWork](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-cowork/automations).

## What the semantic view defines

| Name | Kind | Meaning |
|---|---|---|
| `county`, `state`, `county_geo_id` | Dimensions | Group and filter by these. Manhattan is New York County and Brooklyn is Kings County |
| `claim_records` | Fact | Claims in one county |
| `paid_denominator` | Fact | Claims in one county with a building payment recorded |
| `bldg_paid_usd` | Fact | Total building payments in one county |
| `mean_bldg_paid_usd` | Fact | Mean payment for one county. Don't average it across counties |
| `total_claims`, `total_claims_with_payment`, `total_claims_without_payment`, `total_bldg_paid_usd` | Metrics | Sums across any set of counties |
| `mean_paid_usd` | Metric | Total paid divided by claims with a payment. This is the correct average for a state or any group of counties |

Why the metrics matter: Manhattan has 445 paid claims averaging about
$236K, and Brooklyn has 3,400 averaging about $81K. A plain average of
those two county means is about $159K. The real mean across both counties
is about $99K, because Brooklyn has far more claims.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Table ... SANDY_COUNTY_CLAIMS does not exist or not authorized` | `04_build_the_pipeline.sql` not run, or a different role | Run `04_build_the_pipeline.sql` with the same role, or grant `SELECT` on the view |
| `Insufficient privileges to operate on schema` | Role lacks `CREATE SEMANTIC VIEW` or `CREATE AGENT` | Use `ACCOUNTADMIN` on a trial, or ask an admin for the grants in [Before you start](#before-you-start) |
| Errors mentioning Cortex, AI features, or a disabled feature | Trial without a payment method, or Cortex turned off by an admin | Add a payment method, or use [No AI features?](#no-ai-features) |
| `Model ... not available in this region` | Region without that model | Ask an admin to enable cross-region inference (see Before you start) |
| Agent created but not listed in CoWork | Your account has a CoWork object, so agents are hidden until added | Run `SHOW SNOWFLAKE INTELLIGENCES;`, then `ALTER SNOWFLAKE INTELLIGENCE <name> ADD AGENT SDSC_WORKSHOP.SEMANTIC.SDSC_FLOOD_RISK_AGENT;`. This needs `ACCOUNTADMIN` or `MODIFY` on that object |
| CoWork opens with the wrong role, or "no warehouse" | CoWork uses your default role and warehouse | `ALTER USER <you> SET DEFAULT_ROLE = <role> DEFAULT_WAREHOUSE = SDSC_WORKSHOP_WH;` |
| A colleague can't see or use the agent | Missing grants for their role | Use step 5 of the SQL file |
| `Object ... already exists` or you replaced something you wanted | Name conflict | Rename before running (see Before you start, item 6) |
| The YAML won't validate after you edited it | YAML indentation, or a renamed database | Indent with spaces, not tabs. Check `base_table.database`. Validate by adding `, TRUE` after the closing `$$` |
| You renamed the listing database | The views in `04_build_the_pipeline.sql` reference `SNOWFLAKE_PUBLIC_DATA_FREE` | Fix and re-run that file. Nothing in this folder names the listing database |
| Numbers differ from the expected values | Underlying public data was refreshed | Compare with [`../../labs/EXPECTED_RESULTS.md`](../../labs/EXPECTED_RESULTS.md). Small drift is fine |

## No AI features?

You can still see everything the agent would use:

- **Read the definitions.** [`sdsc_insurance.yaml`](sdsc_insurance.yaml) is
  readable on its own. The descriptions are the business rules.
- **Create the semantic view anyway.** Step 1 of the SQL file is a standard
  schema object. If it fails on your account, skip it.
- **Ask the questions in SQL.** These queries match what the agent should
  write:

```sql
-- Which counties had the most Sandy claims?
SELECT county, state, claim_records
FROM SDSC_WORKSHOP.ANALYTICS.SANDY_COUNTY_CLAIMS
ORDER BY claim_records DESC
LIMIT 10;

-- Mean paid amount in NY versus NJ (the correct, weighted way)
SELECT state,
       SUM(claim_records)                                  AS claims,
       SUM(claim_records - paid_denominator)               AS claims_without_payment,
       ROUND(SUM(bldg_paid_usd) / NULLIF(SUM(paid_denominator), 0)) AS mean_paid_usd
FROM SDSC_WORKSHOP.ANALYTICS.SANDY_COUNTY_CLAIMS
GROUP BY state;
```

## Clean up

```sql
DROP AGENT IF EXISTS SDSC_WORKSHOP.SEMANTIC.SDSC_FLOOD_RISK_AGENT;
DROP SEMANTIC VIEW IF EXISTS SDSC_WORKSHOP.SEMANTIC.SDSC_INSURANCE;
```

If you added the agent to a CoWork object, remove it first with
`ALTER SNOWFLAKE INTELLIGENCE <name> DROP AGENT ...`.
[`../../labs/99_cleanup.sql`](../../labs/99_cleanup.sql) drops the whole
`SDSC_WORKSHOP` database, which includes both objects.

## About the data

These are historical Hurricane Sandy (2012) NFIP claims at county level.
They describe what was paid, not future flood risk. FEMA truncates claim
coordinates to about 11 km for privacy, so nothing here places an
individual claim on a map.
