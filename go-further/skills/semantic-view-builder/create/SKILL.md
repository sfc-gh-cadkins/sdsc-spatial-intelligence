---
name: semantic-view-builder-create
description: "Create a new semantic view from a source table."
parent_skill: semantic-view-builder
---

# Create Semantic View

## Step 1: Gather Inputs

Ask the user:
- Source table or view (fully qualified: `DB.SCHEMA.TABLE`)
- Target audience (technical, or non-technical business users)
- Primary use case (for example "flood claims by county" or "POS analytics")
- Where to create it (`DB.SCHEMA`)

**STOP**: Confirm before proceeding.

## Step 2: Inspect the Source

Run `DESCRIBE TABLE <table>` and sample a few rows (`SELECT * FROM <table> LIMIT 10`).

Identify:
- **Integer dates** (for example `yyyymmdd`): need a real DATE calculated dimension.
- **Coded columns** (status 1-4, daypart 0-3): need a `_LABEL` dimension with a CASE mapping.
- **Categorical columns**: note common values for `sample_values` and synonyms.
- **Measures** (amounts, counts, quantities): define as facts, and add metrics for rollups.
- **Pre-aggregated columns** (averages, rates): flag them. They must not be averaged again across rows; give the correct rollup as a metric instead.
- **Geography columns** (GEOGRAPHY polygons or points): expose as a dimension so map-capable clients can render them.

## Step 3: Generate the Semantic View

If your environment offers a semantic view generator (for example Snowsight's
semantic view wizard or a `create_semantic_view` tool in Cortex Code), use it on
the source table. Otherwise write the DDL directly:

```sql
CREATE OR REPLACE SEMANTIC VIEW <db>.<schema>.<view_name>
  TABLES (
    t AS <db>.<schema>.<table> PRIMARY KEY (<id_col>)
      COMMENT = '<what one row represents>'
  )
  FACTS (
    t.<measure_col> AS <measure_col> COMMENT = '<meaning and unit>'
  )
  DIMENSIONS (
    t.<category_col> AS <category_col>
      WITH SYNONYMS = ('<synonym>', '<synonym>')
      COMMENT = '<meaning; example values>'
  )
  METRICS (
    t.total_<measure> AS SUM(<measure_col>) COMMENT = '<rollup meaning>'
  )
  COMMENT = '<scope of the data, time period, and what it does not cover>';
```

## Step 4: Add Calculated Dimensions

**Integer dates (`yyyymmdd`):**
```sql
t.txn_date AS TO_DATE(CAST(<ymd_col> AS VARCHAR), 'YYYYMMDD')
  COMMENT = 'Transaction date derived from the <ymd_col> integer field'

t.day_of_week AS DAYNAME(TO_DATE(CAST(<ymd_col> AS VARCHAR), 'YYYYMMDD'))
  COMMENT = 'Day of week (Mon, Tue, Wed, ...)'
```

**Coded columns:**
```sql
t.<col>_label AS
  CASE <col>
    WHEN 0 THEN '<value_0>'
    WHEN 1 THEN '<value_1>'
  END
  COMMENT = '<col> label: <value_0> (0), <value_1> (1), ...'
```

**STOP**: Review all calculated dimensions with the user before saving.

## Step 5: Validate and Save

1. Create the view, then confirm it parses: `DESCRIBE SEMANTIC VIEW <name>`.
2. Ask Cortex Analyst three or four real questions and check the generated SQL and numbers against a hand-written query.
3. Fix any wrong answers by improving comments, synonyms, or metrics, then retest.

## Output

A semantic view with:
- Calculated dimensions for every date and coded column
- Comments and synonyms written for the target audience
- Metrics for every rollup that can't be done by simple summing
- Ready for Cortex Analyst or a Cortex Agent
