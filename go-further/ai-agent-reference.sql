-- =============================================================================
-- PRESENTER REFERENCE: not part of the participant path
-- =============================================================================
-- Semantic view, Cortex Agent, and a custom AI function, as deployed in the
-- presenters' CARTO_SDSC_DEMO account. They depend on presenter-built tables
-- (RAW.NFIP_CLAIMS_SANDY = NY-only Sandy slice, ANALYTICS.*_H3_V2) and need
-- AI features, which self-service trials disable by default.
--
-- Caveat: the presenter H3 tables were built from ZIP-centroid locations.
-- They're useful for visual demos, but don't present them as property-level
-- precision. The participant labs aggregate by county instead.
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE CARTO_SDSC_DEMO_WH;
USE DATABASE CARTO_SDSC_DEMO;

-- =============================================================================
-- STEP 1: Create the Semantic View
-- =============================================================================
-- The semantic view defines what business terms mean in YAML.
-- It is the governed translation layer: "total damage" → the right SQL.
--
-- NOTE: This is the minimal version. The full production semantic view
-- includes verified queries, formatting rules, and relationship definitions.
-- See the workshop materials for the complete spec.

CREATE OR REPLACE SEMANTIC VIEW CARTO_SDSC_DEMO.SEMANTIC.SDSC_INSURANCE
  COMMENT = 'Hurricane Sandy flood insurance analysis — SDSC 2026 workshop'
  FROM SPECIFICATION $$
name: sdsc_insurance
tables:
  - name: nfip_claims
    base_table:
      database: CARTO_SDSC_DEMO
      schema: RAW
      table: NFIP_CLAIMS_SANDY
    dimensions:
      - name: flood_zone
        expr: FLOOD_ZONE
        description: FEMA flood zone designation
      - name: occupancy_type
        expr: OCCUPANCY_TYPE
        description: Building type (1-4 family, condo, etc.)
      - name: cause_of_damage
        expr: CAUSE_OF_DAMAGE
        description: Primary cause (tidal surge, rainfall, etc.)
      - name: state
        expr: STATE
    facts:
      - name: building_damage
        expr: AMOUNT_PAID_ON_BUILDING_CLAIM
        description: Structural damage payout in USD
      - name: contents_damage
        expr: AMOUNT_PAID_ON_CONTENTS_CLAIM
        description: Contents damage payout in USD
      - name: total_coverage
        expr: TOTAL_BUILDING_INSURANCE_COVERAGE + TOTAL_CONTENTS_INSURANCE_COVERAGE
        description: Total policy coverage limit in USD
      - name: flood_depth
        expr: WATER_DEPTH
        description: Reported flood depth in feet
  - name: exposure_h3
    base_table:
      database: CARTO_SDSC_DEMO
      schema: ANALYTICS
      table: SANDY_EXPOSURE_H3_V2
    dimensions:
      - name: h3_cell
        expr: H3_CELL
        description: H3 hexagon cell ID at resolution 8
      - name: boundary
        expr: BOUNDARY
        description: GEOGRAPHY polygon for the H3 cell boundary
    facts:
      - name: claim_count
        expr: CLAIM_COUNT
      - name: total_damage
        expr: TOTAL_DAMAGE
      - name: avg_damage
        expr: AVG_DAMAGE
      - name: total_coverage
        expr: TOTAL_COVERAGE
      - name: avg_flood_depth
        expr: AVG_FLOOD_DEPTH
  - name: geocoded_claims
    base_table:
      database: CARTO_SDSC_DEMO
      schema: ANALYTICS
      table: SANDY_CLAIMS_GEOCODED
    dimensions:
      - name: location
        expr: LOCATION
        description: GEOGRAPHY point for each claim (geocoded via Overture Maps ZIP centroids)
      - name: flood_zone
        expr: FLOOD_ZONE
      - name: building_type
        expr: OCCUPANCY_TYPE
    facts:
      - name: amount_paid
        expr: COALESCE(AMOUNT_PAID_ON_BUILDING_CLAIM, 0) + COALESCE(AMOUNT_PAID_ON_CONTENTS_CLAIM, 0)
        description: Total payout in USD
verified_queries:
  - name: FLOOD_EXPOSURE_MAP
    question: Show me Hurricane Sandy flood damage on a map
    sql: >
      SELECT H3_CELL,
        CONCAT('$', TO_CHAR(TOTAL_DAMAGE, '999,999,999,999')) AS "Total Damage",
        CLAIM_COUNT AS "Claims",
        CONCAT('$', TO_CHAR(AVG_DAMAGE, '999,999,999')) AS "Avg Damage",
        BOUNDARY
      FROM CARTO_SDSC_DEMO.ANALYTICS.SANDY_EXPOSURE_H3_V2
      ORDER BY TOTAL_DAMAGE DESC
  - name: GEOCODED_CLAIMS_MAP
    question: Show me every individual Sandy flood claim on a map colored by payout amount
    sql: >
      SELECT LOCATION,
        CONCAT('$', TO_CHAR(COALESCE(AMOUNT_PAID_ON_BUILDING_CLAIM,0)+COALESCE(AMOUNT_PAID_ON_CONTENTS_CLAIM,0), '999,999,999')) AS "Amount Paid",
        FLOOD_ZONE AS "Flood Zone",
        OCCUPANCY_TYPE AS "Building Type"
      FROM CARTO_SDSC_DEMO.ANALYTICS.SANDY_CLAIMS_GEOCODED
      ORDER BY (COALESCE(AMOUNT_PAID_ON_BUILDING_CLAIM,0)+COALESCE(AMOUNT_PAID_ON_CONTENTS_CLAIM,0)) DESC
$$;

-- =============================================================================
-- STEP 2: Create the Cortex Agent
-- =============================================================================
-- The agent orchestrates: it receives a natural language question, decides
-- which tool to call, generates SQL via the semantic view, and returns
-- results — including inline maps when GEOGRAPHY data is present.

CREATE OR REPLACE AGENT CARTO_SDSC_DEMO.SEMANTIC.SDSC_FLOOD_RISK_AGENT
COMMENT = 'Hurricane Sandy flood risk analysis agent for the SDSC workshop.'
FROM SPECIFICATION
$$
models:
  orchestration: "auto"
orchestration:
  capabilities:
    analytical_search: true
instructions:
  response: "Be direct and data-driven. Lead with the key finding, then support with numbers. Format dollar amounts as USD with commas. Format flood depth in feet. Format percentages to one decimal place. Use tables when presenting multiple rows. Always clarify that this data covers Hurricane Sandy (2012) NFIP claims and policies across the New York metro area."
  orchestration: "Use the flood_risk_analyst tool for all questions about flood damage, insurance claims, policy coverage, premiums, exposure concentration, underinsured communities, flood zones, and geographic risk patterns. MAP AND SPATIAL VISUALIZATION: When the user asks to see data on a map, query the data using flood_risk_analyst and include the BOUNDARY column (GEOGRAPHY polygons) or LOCATION column (GEOGRAPHY points) in the SELECT. The platform will automatically render GEOGRAPHY data as an interactive map."
  sample_questions:
    - question: "What is the total damage from Hurricane Sandy?"
    - question: "Show me Hurricane Sandy flood damage on a map"
    - question: "Show me every individual flood claim on a map colored by payout amount"
    - question: "Which building types suffered the most damage?"
    - question: "Which flood zones had the worst loss ratios?"
tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "flood_risk_analyst"
      description: "Query Hurricane Sandy flood insurance data — NFIP claims (57K), policies (2.3M), geocoded H3 hexagon exposure summaries (354 cells at resolution 8), and geocoded individual claim detail (57K points). Returns BOUNDARY column (GEOGRAPHY polygons) for filled hexagon maps or LOCATION column (GEOGRAPHY points) for point maps."
  - tool_spec:
      type: "code_execution"
      name: "code_execution"
tool_resources:
  code_execution:
    artifact_repositories:
      - "SNOWFLAKE.SNOWPARK.PYPI_SHARED_REPOSITORY"
  flood_risk_analyst:
    execution_environment:
      type: "warehouse"
      warehouse: "CARTO_SDSC_DEMO_WH"
    semantic_view: "CARTO_SDSC_DEMO.SEMANTIC.SDSC_INSURANCE"
$$;

-- =============================================================================
-- STEP 3: Custom AI Function — FLOOD_CLAIM_NARRATOR
-- =============================================================================
-- A custom function that takes structured claim parameters and generates
-- a professional underwriting narrative using Cortex AI.
-- This is AI built INTO the data pipeline, not bolted on.

CREATE OR REPLACE FUNCTION CARTO_SDSC_DEMO.ANALYTICS.FLOOD_CLAIM_NARRATOR(
    flood_zone VARCHAR,
    building_type VARCHAR,
    flood_depth NUMBER,
    building_damage NUMBER,
    contents_damage NUMBER,
    amount_paid NUMBER,
    property_value NUMBER,
    cause_of_damage VARCHAR
)
RETURNS VARCHAR
AS $$
SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-70b',
    'You are a senior flood insurance underwriter writing a concise risk assessment narrative. '
    || 'Given these claim details, write a 3-4 sentence professional assessment covering: '
    || '1) The severity and likely cause, 2) Whether the payout was appropriate relative to coverage, '
    || '3) A forward-looking risk recommendation. Be specific with numbers.\n\n'
    || 'Flood Zone: ' || COALESCE(flood_zone, 'Unknown')
    || '\nBuilding Type: ' || COALESCE(building_type, 'Unknown')
    || '\nFlood Depth: ' || COALESCE(TO_VARCHAR(flood_depth), 'Unknown') || ' feet'
    || '\nBuilding Damage Paid: $' || COALESCE(TO_VARCHAR(building_damage), '0')
    || '\nContents Damage Paid: $' || COALESCE(TO_VARCHAR(contents_damage), '0')
    || '\nTotal Amount Paid: $' || COALESCE(TO_VARCHAR(amount_paid), '0')
    || '\nProperty Value (Coverage): $' || COALESCE(TO_VARCHAR(property_value), '0')
    || '\nCause of Damage: ' || COALESCE(cause_of_damage, 'Unknown')
)
$$;

-- Test the custom AI function on the highest-damage claim:
-- SELECT CARTO_SDSC_DEMO.ANALYTICS.FLOOD_CLAIM_NARRATOR(
--     FLOOD_ZONE, OCCUPANCY_TYPE, WATER_DEPTH,
--     AMOUNT_PAID_ON_BUILDING_CLAIM, AMOUNT_PAID_ON_CONTENTS_CLAIM,
--     AMOUNT_PAID_ON_BUILDING_CLAIM + AMOUNT_PAID_ON_CONTENTS_CLAIM,
--     TOTAL_BUILDING_INSURANCE_COVERAGE + TOTAL_CONTENTS_INSURANCE_COVERAGE,
--     CAUSE_OF_DAMAGE
-- ) AS narrative
-- FROM CARTO_SDSC_DEMO.RAW.NFIP_CLAIMS_SANDY
-- ORDER BY (AMOUNT_PAID_ON_BUILDING_CLAIM + AMOUNT_PAID_ON_CONTENTS_CLAIM) DESC NULLS LAST
-- LIMIT 1;

-- =============================================================================
-- STEP 4: Test it
-- =============================================================================
-- 1. Open Snowflake CoWork
-- 2. Start a new chat, select SDSC_FLOOD_RISK_AGENT
-- 3. Try these prompts:
--    "What is the total damage from Hurricane Sandy?"
--    "Show me Hurricane Sandy flood damage on a map"
--    "Show me every individual flood claim on a map colored by payout amount"
--    "Which flood zones had the worst loss ratios?"

SELECT 'Agent deployed. Open CoWork and start asking questions!' AS status;
