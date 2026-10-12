-- =============================================================================
-- Semantic view + Cortex Agent for the CoWork section
-- =============================================================================
-- Creates:
--   SDSC_WORKSHOP.SEMANTIC.SDSC_INSURANCE          semantic view (business meaning)
--   SDSC_WORKSHOP.SEMANTIC.SDSC_FLOOD_RISK_AGENT   agent you chat with in CoWork
--
-- Before you run this (see README.md in this folder for the full checklist):
--   1. Run labs/04_build_the_pipeline.sql. This file reads its county view.
--   2. AI features must be on. Self-service trials disable them until a
--      payment method is added. If you can't enable them, skip to the
--      "No AI features?" section of README.md.
--   3. Your role needs CREATE SEMANTIC VIEW and CREATE AGENT on the schema
--      (ACCOUNTADMIN on a trial has both).
--
-- Different names? If your warehouse or database isn't SDSC_WORKSHOP_WH /
-- SDSC_WORKSHOP, find-and-replace both names in this whole file, and in
-- sdsc_insurance.yaml if you use it.
--
-- Safe to re-run: both steps replace the object if it already exists.
-- The YAML in step 2 is identical to sdsc_insurance.yaml.
-- =============================================================================

USE WAREHOUSE SDSC_WORKSHOP_WH;
CREATE SCHEMA IF NOT EXISTS SDSC_WORKSHOP.SEMANTIC;

-- Step 1: the semantic view. It tells the agent what each column means and
-- how to roll counties up correctly (metrics), so "mean paid" always uses the
-- same definition you used in Lab C.
CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML('SDSC_WORKSHOP.SEMANTIC', $$
name: SDSC_INSURANCE
description: Hurricane Sandy NFIP claims by county, NY and NJ.

tables:
  - name: county_claims
    description: >-
      One row per county in New York and New Jersey, with Hurricane Sandy
      NFIP claim totals. Counties with no Sandy claims are included with
      zero claims.
    base_table:
      database: SDSC_WORKSHOP
      schema: ANALYTICS
      table: SANDY_COUNTY_CLAIMS
    primary_key:
      columns: [county_geo_id]

    dimensions:
      - name: county_geo_id
        expr: COUNTY_GEO_ID
        data_type: VARCHAR
        description: County identifier, for example geoId/36061 for Manhattan.
      - name: county
        expr: COUNTY
        data_type: VARCHAR
        synonyms: [county name, borough]
        description: >-
          County name. New York County appears as Manhattan, Kings County as
          Brooklyn.
      - name: state
        expr: STATE
        data_type: VARCHAR
        synonyms: [state code]
        description: NY or NJ.

    # Facts are per-county values. Use them for per-county questions.
    facts:
      - name: claim_records
        expr: CLAIM_RECORDS
        data_type: NUMBER
        synonyms: [claims, claim count, number of claims]
        description: Number of Sandy claim records in the county.
      - name: paid_denominator
        expr: PAID_DENOMINATOR
        data_type: NUMBER
        synonyms: [claims with payment, paid claims]
        description: >-
          Claim records with a building payment recorded. Use this as the
          denominator for mean paid.
      - name: bldg_paid_usd
        expr: BLDG_PAID_USD
        data_type: NUMBER
        synonyms: [building paid, total paid]
        description: Total building payments in USD.
      - name: mean_bldg_paid_usd
        expr: MEAN_BLDG_PAID_USD
        data_type: NUMBER
        synonyms: [mean paid, average payout, average building payment]
        description: >-
          Mean building payment per claim with a payment recorded, in USD,
          for one county. Do not average this across counties; use the
          mean_paid_usd metric for any rollup.

    # Metrics are for rollups across counties (by state, or all of NY and NJ).
    metrics:
      - name: total_claims
        expr: SUM(county_claims.claim_records)
        description: Total Sandy claim records across the selected counties.
      - name: total_claims_with_payment
        expr: SUM(county_claims.paid_denominator)
        description: Claim records with a building payment recorded.
      - name: total_claims_without_payment
        expr: SUM(county_claims.claim_records - county_claims.paid_denominator)
        synonyms: [missing payments, claims with no payment]
        description: Claim records with no building payment recorded (missingness).
      - name: total_bldg_paid_usd
        expr: SUM(county_claims.bldg_paid_usd)
        description: Total building payments in USD across the selected counties.
      - name: mean_paid_usd
        expr: SUM(county_claims.bldg_paid_usd) / NULLIF(SUM(county_claims.paid_denominator), 0)
        synonyms: [rollup mean paid, statewide mean paid]
        description: >-
          Mean building payment per claim with a payment recorded, weighted
          correctly across counties. Use this for state or multi-county
          averages.
$$);
-- Dry run tip: add  , TRUE  after the closing $$ above to check the YAML
-- without creating anything ("YAML file is valid ... No object has been
-- created yet.").

-- Step 2: check it. Brooklyn should show 3561 claims, 3400 with payment, mean 81335.
SELECT * FROM SEMANTIC_VIEW(
  SDSC_WORKSHOP.SEMANTIC.SDSC_INSURANCE
  DIMENSIONS county_claims.county, county_claims.state
  METRICS county_claims.total_claims,
          county_claims.total_claims_with_payment,
          county_claims.mean_paid_usd
)
WHERE county = 'Brooklyn';

-- Step 3: the agent. CoWork uses it to turn a question into SQL over the
-- semantic view, and shows you the SQL it ran.
CREATE OR REPLACE AGENT SDSC_WORKSHOP.SEMANTIC.SDSC_FLOOD_RISK_AGENT
  COMMENT = 'Hurricane Sandy NFIP claims by county (NY and NJ).'
FROM SPECIFICATION
$$
models:
  orchestration: "auto"
instructions:
  response: "Lead with the finding, then the numbers. Format USD with commas. Always show how many claims lack a recorded payment. State that this is historical Hurricane Sandy (2012) claim data at county level and does not establish future property risk."
  orchestration: "Use the county_claims tool for every question about Sandy claims, payouts, counties, or states. For any total or average across more than one county, use the metrics (total_claims, mean_paid_usd), never an average of per-county means."
  sample_questions:
    - question: "Which counties had the most Sandy claims?"
    - question: "Compare claim volume with mean paid amount for counties with at least 500 claims."
    - question: "What was the mean paid amount in NY versus NJ?"
tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "county_claims"
      description: "Hurricane Sandy NFIP claims aggregated by county for NY and NJ: claim counts, building payments, and mean payment."
tool_resources:
  county_claims:
    execution_environment:
      type: "warehouse"
      warehouse: "SDSC_WORKSHOP_WH"
    semantic_view: "SDSC_WORKSHOP.SEMANTIC.SDSC_INSURANCE"
$$;

-- Step 4: make sure CoWork can see it.
-- If your account has a Snowflake CoWork object, agents are hidden until you
-- add them. Check:
SHOW SNOWFLAKE INTELLIGENCES;
-- If that returns a row, use the name in its "name" column (often
-- SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT, but it can be anything), then
-- uncomment and run (needs ACCOUNTADMIN, or MODIFY on that object):
-- ALTER SNOWFLAKE INTELLIGENCE <name_from_show>
--   ADD AGENT SDSC_WORKSHOP.SEMANTIC.SDSC_FLOOD_RISK_AGENT;
-- If it returns nothing, there's nothing to do: you see every agent you can use.

-- Step 5 (only if someone else will use the agent with a different role):
-- SET r = 'YOUR_ROLE';
-- GRANT USAGE ON DATABASE SDSC_WORKSHOP TO ROLE IDENTIFIER($r);
-- GRANT USAGE ON SCHEMA SDSC_WORKSHOP.ANALYTICS TO ROLE IDENTIFIER($r);
-- GRANT USAGE ON SCHEMA SDSC_WORKSHOP.SEMANTIC TO ROLE IDENTIFIER($r);
-- GRANT SELECT ON ALL VIEWS IN SCHEMA SDSC_WORKSHOP.ANALYTICS TO ROLE IDENTIFIER($r);
-- GRANT SELECT ON SEMANTIC VIEW SDSC_WORKSHOP.SEMANTIC.SDSC_INSURANCE TO ROLE IDENTIFIER($r);
-- GRANT USAGE ON AGENT SDSC_WORKSHOP.SEMANTIC.SDSC_FLOOD_RISK_AGENT TO ROLE IDENTIFIER($r);
-- GRANT USAGE ON WAREHOUSE SDSC_WORKSHOP_WH TO ROLE IDENTIFIER($r);
-- Note: views over a Marketplace share also need the listing database
-- privilege: GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_PUBLIC_DATA_FREE TO ROLE IDENTIFIER($r);

SELECT 'Agent ready. Open ai.snowflake.com (or AI & ML > Agents > Preview) and choose SDSC_FLOOD_RISK_AGENT.' AS status;
