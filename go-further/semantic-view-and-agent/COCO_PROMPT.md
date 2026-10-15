# Build the semantic view and agent with Cortex Code (CoCo)

Paste the prompt below into Cortex Code (Snowsight » Cortex Code, or the
CoCo desktop app) while connected to your account. It builds the same
objects as [`create-semantic-view-and-agent.sql`](create-semantic-view-and-agent.sql),
but it checks your account first and asks before it changes anything.

Before you paste it:

- Run [`../../labs/04_build_the_pipeline.sql`](../../labs/04_build_the_pipeline.sql).
- If you used different names for the database, warehouse, or listing
  database, change them in the **Names** block at the top of the prompt.
- If CoCo isn't available in your account (it needs AI features), use the
  SQL file instead, or see "No AI features?" in [`README.md`](README.md).

---

## The prompt

```text
Help me build a semantic view and a Cortex Agent over Hurricane Sandy
flood insurance claims, so I can ask questions about it in Snowflake CoWork.
Work step by step, show me each SQL statement before you run anything that
creates or changes an object, and stop to ask me if a check fails.

Names (change these if mine are different):
- Database:            SDSC_WORKSHOP
- Source view:         SDSC_WORKSHOP.ANALYTICS.SANDY_COUNTY_CLAIMS
- Target schema:       SDSC_WORKSHOP.SEMANTIC (create it if missing)
- Semantic view name:  SDSC_INSURANCE
- Agent name:          SDSC_FLOOD_RISK_AGENT
- Warehouse:           SDSC_WORKSHOP_WH

Step 1. Pre-flight checks. Read-only. Report the results in a short table
before going further.
  a. SELECT CURRENT_ROLE(), CURRENT_WAREHOUSE(), CURRENT_REGION().
  b. Confirm the source view exists and has 83 rows, and that the top county
     by CLAIM_RECORDS is Ocean County, NJ with 37,459 claims. If the view is
     missing, stop and tell me to run labs/04_build_the_pipeline.sql.
  c. Confirm my role can create semantic views and agents in the target
     schema (check SHOW GRANTS or try a dry run). If not, tell me which
     privilege is missing and the GRANT that an admin would need to run.
  d. Confirm Cortex AI is usable: run
     SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b', 'Say OK');
     If it fails because AI features are disabled (common on trial accounts
     without a payment method) or the model isn't available in my region,
     stop and explain the options; don't try to work around it.
  e. Run SHOW SNOWFLAKE INTELLIGENCES and remember the result for step 5.
  f. Check whether a semantic view or agent with these names already exists.
     If one does, ask me before replacing it.

Step 2. Describe the source view: its columns, types, and a few sample rows.
The columns are COUNTY_GEO_ID, COUNTY, STATE, CLAIM_RECORDS,
PAID_DENOMINATOR, BLDG_PAID_USD, MEAN_BLDG_PAID_USD, BOUNDARY. One row per
county in NY and NJ.

Step 3. Write the semantic view YAML and validate it with
SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML('<target schema>', $$...$$, TRUE)
before creating it. Requirements:
  - One logical table, county_claims, primary key county_geo_id.
  - Dimensions: county_geo_id, county (synonyms: county name, borough; note
    that New York County is Manhattan and Kings County is Brooklyn), state
    (NY or NJ).
  - Facts: claim_records, paid_denominator (claims with a building payment
    recorded; this is the denominator for mean paid), bldg_paid_usd,
    mean_bldg_paid_usd (per-county mean; must never be averaged across
    counties).
  - Metrics for rollups across counties:
      total_claims                 = SUM(claim_records)
      total_claims_with_payment    = SUM(paid_denominator)
      total_claims_without_payment = SUM(claim_records - paid_denominator)
      total_bldg_paid_usd          = SUM(bldg_paid_usd)
      mean_paid_usd                = SUM(bldg_paid_usd) / NULLIF(SUM(paid_denominator), 0)
  - Leave BOUNDARY out. The agent doesn't need geometry and CoWork can't
    draw maps.
  - Write clear descriptions: these are historical Hurricane Sandy (2012)
    NFIP claims at county level; FEMA truncates coordinates for privacy, so
    no individual claim locations.
  A reference version is in go-further/semantic-view-and-agent/sdsc_insurance.yaml
  in the workshop repo. Match it if you can.

Step 4. After I approve, create the semantic view (same call without TRUE),
then prove the metrics are right with:
  SELECT * FROM SEMANTIC_VIEW(<view>
    DIMENSIONS county_claims.county
    METRICS county_claims.total_claims, county_claims.total_claims_with_payment,
            county_claims.mean_paid_usd)
  WHERE county = 'Brooklyn';
Expected: 3,561 claims, 3,400 with payment, mean about 81,335. Also show the
NY versus NJ mean_paid_usd and confirm it is not a simple average of county
means.

Step 5. After I approve, create the agent with CREATE OR REPLACE AGENT ...
FROM SPECIFICATION:
  - orchestration model: auto
  - one cortex_analyst_text_to_sql tool named county_claims, using the
    semantic view and the warehouse above
  - response instructions: lead with the finding, then the numbers; USD with
    commas; always say how many claims lack a recorded payment; state that
    this is historical 2012 county-level data and does not establish future
    property risk
  - orchestration instructions: use county_claims for every claims question;
    use metrics for any multi-county total or average
  - sample questions: "Which counties had the most Sandy claims?",
    "Compare claim volume with mean paid amount for counties with at least
    500 claims.", "What was the mean paid amount in NY versus NJ?"
  If step 1e returned a Snowflake CoWork object, add the agent to it with
  ALTER SNOWFLAKE INTELLIGENCE <name from SHOW> ADD AGENT <agent>. If I
  can't (needs ACCOUNTADMIN or MODIFY on that object), tell me who to ask.
  If SHOW returned nothing, skip this; all agents I can use are visible.

Step 6. Wrap up:
  - Check that my user has a default role and default warehouse
    (DESCRIBE USER or SHOW USERS). CoWork starts sessions with those. If
    either is missing, show me the ALTER USER statement and ask before
    running it.
  - Tell me how to open it: ai.snowflake.com, or AI & ML > Agents > select
    the agent > Preview in Snowflake CoWork.
  - Give me three questions to try, and remind me that CoWork draws bar,
    line, and scatter charts but not maps.
  - List every object you created so I can drop them later.
```

---

## If CoCo goes off track

- **It wants to average `mean_bldg_paid_usd`.** Tell it: "Use the
  mean_paid_usd metric, not an average of county means."
- **It adds BOUNDARY or H3 columns.** Tell it to leave geometry out.
- **It skips the dry run.** Ask it to validate with the `TRUE` flag first.
- **It can't find the source view.** Check that you're using the role you
  ran `04_build_the_pipeline.sql` with. CoCo uses your current role.
- **It gets stuck on anything.** Run `create-semantic-view-and-agent.sql`
  instead. It builds the same objects.
