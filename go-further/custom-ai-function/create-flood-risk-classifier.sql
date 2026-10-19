-- Custom AI function: FLOOD_RISK_CLASSIFIER
--
-- Classifies an insured property's flood risk as Critical, High, Moderate,
-- or Low, and returns a one-sentence explanation. It wraps AI_COMPLETE with
-- fixed rules and a JSON response schema, so every call returns the same shape:
--   {"risk_tier": "...", "explanation": "..."}
--
-- Needs Cortex AI (trial accounts: add a payment method first) and the
-- SNOWFLAKE.CORTEX_USER database role. Uses SDSC_WORKSHOP; if you used other
-- names, find-and-replace them. Run as ACCOUNTADMIN on a trial.

USE WAREHOUSE SDSC_WORKSHOP_WH;
CREATE DATABASE IF NOT EXISTS SDSC_WORKSHOP;
CREATE SCHEMA IF NOT EXISTS SDSC_WORKSHOP.SEMANTIC;

-- 1. Create the function.
--    The model is claude-sonnet-4-6. If it isn't available in your region,
--    enable cross-region inference or swap in another model you can use
--    (SHOW CORTEX BASE MODELS IN SCHEMA SNOWFLAKE.MODELS).
CREATE OR REPLACE AI FUNCTION SDSC_WORKSHOP.SEMANTIC.FLOOD_RISK_CLASSIFIER("FLOOD_ZONE" VARCHAR, "BUILDING_TYPE" VARCHAR, "ELEVATION_DIFFERENCE" FLOAT, "FLOOD_DEPTH" FLOAT, "BUILDING_DAMAGE_AMOUNT" FLOAT)
RETURNS VARIANT
LANGUAGE SQL
COMMENT='Classify flood risk for insured properties based on FEMA flood zone risk mapping'
AS '
    SELECT AI_COMPLETE(
    model=>''claude-sonnet-4-6'',
    messages=>ARRAY_CONSTRUCT(
        OBJECT_CONSTRUCT(
            ''role'', ''system'',
            ''content'', ''You are a flood risk classification expert following FEMA flood zone risk mapping standards. Classify the flood risk for insured properties based on their flood zone designation, building characteristics, and damage history.

Classification rules:
- Critical: V or VE zones (coastal high-hazard), OR any zone with building damage amount exceeding $100,000
- High: A or AE zones (high-risk flood areas), OR any zone with flood depth greater than 4 feet
- Moderate: B, C, or X zones that have flood history (flood depth > 0 or building damage amount > 0)
- Low: Minimal flood zones (B, C, X, or D) with no flood depth and no building damage history

When elevation difference is negative (property below base flood elevation), increase risk by one tier. Consider building type as supporting context.

Some fields may be marked "Unknown" when data is unavailable. Classify based on whatever fields ARE available:
- Damage amount and flood depth alone are sufficient for a reasonable tier (e.g., high damage = Critical, moderate depth = High).
- Flood zone alone is sufficient (use the zone-based rules above).
- If only building type is known with no other data, classify as Moderate with a note that data is insufficient for precise classification.
- Never refuse to classify. Always return your best assessment given available information.

Return a JSON object with exactly two fields:
- "risk_tier": one of "Critical", "High", "Moderate", "Low"
- "explanation": one sentence explaining why this risk tier was assigned''
        ),
        OBJECT_CONSTRUCT(
            ''role'', ''user'',
            ''content'', ''Classify the flood risk for this insured property:

Flood Zone: '' || NVL(FLOOD_ZONE, ''Unknown'') || ''
Building Type: '' || NVL(BUILDING_TYPE, ''Unknown'') || ''
Elevation Difference (ft): '' || NVL(TO_VARCHAR(ELEVATION_DIFFERENCE), ''Unknown'') || ''
Flood Depth (ft): '' || NVL(TO_VARCHAR(FLOOD_DEPTH), ''Unknown'') || ''
Building Damage Amount ($): '' || NVL(TO_VARCHAR(BUILDING_DAMAGE_AMOUNT), ''Unknown'')
        )
    ),
    response_format=>PARSE_JSON(''{
    "type": "json",
    "schema": {
        "type": "object",
        "properties": {
            "risk_tier": {
                "type": "string",
                "description": "One of Critical, High, Moderate, Low"
            },
            "explanation": {
                "type": "string",
                "description": "One sentence explaining the risk tier assignment"
            }
        },
        "required": [
            "risk_tier",
            "explanation"
        ],
        "additionalProperties": false
    }
}'')
)
';

-- 2. Try it on two made-up properties.
SELECT SDSC_WORKSHOP.SEMANTIC.FLOOD_RISK_CLASSIFIER('VE', 'Single family', -2, 13, 180000) AS coastal_home,
       SDSC_WORKSHOP.SEMANTIC.FLOOD_RISK_CLASSIFIER('X',  'Single family',  1,  1,  25000) AS inland_home;

-- 3. Run it on real Hurricane Sandy claims from the free Marketplace listing.
--    LIMIT keeps cost down: each row is one model call.
WITH sandy_claims AS (
    SELECT county_geo_id, current_flood_zone, building_type,
           elevation_difference, flood_water_depth, building_damage_amount
    FROM SNOWFLAKE_PUBLIC_DATA_FREE.PUBLIC_DATA_FREE.FEMA_NATIONAL_FLOOD_INSURANCE_PROGRAM_CLAIM_INDEX
    WHERE flood_event = 'Hurricane Sandy'
    LIMIT 10
),
scored AS (
    SELECT *,
           SDSC_WORKSHOP.SEMANTIC.FLOOD_RISK_CLASSIFIER(
               current_flood_zone, building_type, elevation_difference,
               flood_water_depth, building_damage_amount) AS result
    FROM sandy_claims
)
SELECT county_geo_id, current_flood_zone, building_type,
       elevation_difference, flood_water_depth, building_damage_amount,
       result:risk_tier::STRING   AS risk_tier,
       result:explanation::STRING AS explanation
FROM scored;
