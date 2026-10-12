-- =============================================================================
-- AI over the pipeline: semantic view + Cortex Agent (for CoWork)
-- =============================================================================
-- Run labs/04_build_the_pipeline.sql first. This file adds:
--   SEMANTIC.SDSC_INSURANCE          business meaning over the county view
--   SEMANTIC.SDSC_FLOOD_RISK_AGENT   an agent you can chat with in CoWork
--
-- Needs AI features. Self-service trials disable them by default until a
-- payment method is added. You don't need this file for Labs A to C.
--
-- Data grain: county. FEMA truncates claim coordinates for privacy, so nothing
-- here places an individual claim on a map.
-- =============================================================================

USE WAREHOUSE SDSC_WORKSHOP_WH;
CREATE SCHEMA IF NOT EXISTS SDSC_WORKSHOP.SEMANTIC;

-- Step 1: the semantic view. It tells the agent what each column means, so
-- "mean paid" always uses the same definition you used in Lab C.
CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML('SDSC_WORKSHOP.SEMANTIC', $$
name: SDSC_INSURANCE
description: Hurricane Sandy NFIP claims by county, NY and NJ.
tables:
  - name: county_claims
    description: One row per county in New York and New Jersey, with Hurricane Sandy NFIP claim totals.
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
        description: County name. New York County appears as Manhattan, Kings County as Brooklyn.
      - name: state
        expr: STATE
        data_type: VARCHAR
        description: NY or NJ.
    facts:
      - name: claim_records
        expr: CLAIM_RECORDS
        data_type: NUMBER
        description: Number of Sandy claim records in the county.
      - name: paid_denominator
        expr: PAID_DENOMINATOR
        data_type: NUMBER
        description: Claim records with a building payment recorded. Use this as the denominator for mean paid.
      - name: bldg_paid_usd
        expr: BLDG_PAID_USD
        data_type: NUMBER
        description: Total building payments in USD.
      - name: mean_bldg_paid_usd
        expr: MEAN_BLDG_PAID_USD
        data_type: NUMBER
        description: Mean building payment per claim with a payment recorded, in USD.
$$);

-- Step 2: the agent. CoWork uses it to turn a question into SQL over the
-- semantic view, and shows you the SQL it ran.
CREATE OR REPLACE AGENT SDSC_WORKSHOP.SEMANTIC.SDSC_FLOOD_RISK_AGENT
  COMMENT = 'Hurricane Sandy NFIP claims by county (NY and NJ).'
FROM SPECIFICATION
$$
models:
  orchestration: "auto"
instructions:
  response: "Lead with the finding, then the numbers. Format USD with commas. Always show how many claims lack a recorded payment. State that this is historical Hurricane Sandy (2012) claim data at county level and does not establish future property risk."
  orchestration: "Use the county_claims tool for every question about Sandy claims, payouts, counties, or states."
  sample_questions:
    - question: "Which counties had the most Sandy claims?"
    - question: "Compare claim volume with mean paid amount for counties with at least 500 claims."
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

SELECT 'Agent ready. Open CoWork and choose SDSC_FLOOD_RISK_AGENT.' AS status;
