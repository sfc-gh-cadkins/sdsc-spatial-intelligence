---
name: semantic-view-builder-optimize
description: "Optimize an existing semantic view: audit it, add calculated dimensions, and grow verified queries from real usage."
parent_skill: semantic-view-builder
---

# Optimize Semantic View

## Step 1: Gather Inputs

Ask the user:
- Semantic view name (fully qualified: `DB.SCHEMA.VIEW`)
- Warehouse to use
- Is this a first-time audit or a verified query iteration cycle?

**STOP**: Confirm before proceeding.

## Step 2: Audit

Read the current definition:

```sql
SELECT GET_DDL('SEMANTIC_VIEW', '<db>.<schema>.<view>');
```

If your environment has a semantic view audit tool (for example
`improve_semantic_view` in Cortex Code), run it. Either way, check for:

- Columns with no comment, or comments that just repeat the column name
- Integer dates and coded columns without a calculated dimension
- Categorical dimensions without synonyms or sample values
- Pre-aggregated columns (averages, rates) that could be wrongly averaged, with no correct metric
- Missing `ai_sql_generation` guidance for known traps

Act on all findings. Calculated dimensions and comment fixes come before any
verified query work.

**STOP**: Review the audit findings with the user before applying them.

## Step 3: Add Verified Queries

Find the questions people actually ask:
- If available, use a verified query suggestion tool (for example `get_verified_query_suggestions`, based on Cortex Analyst request history).
- Otherwise collect 10-20 real questions from users or from the agent's monitoring logs in Snowsight.

Prioritize:
1. High-frequency questions
2. Questions involving coded columns
3. Date-range questions (these produce the most verbose SQL)
4. Questions the agent has answered wrong

For each, write and hand-check the correct SQL, then add it to the view's
`AI_VERIFIED_QUERIES` clause.

**STOP**: The user approves which verified queries to save.

## Step 4: Validate

Re-ask each verified question through Cortex Analyst and confirm the results
match the verified SQL. Fix any mismatch before marking the work complete.

## Step 5: Iteration Cadence

Repeat this workflow weekly until answers stabilize, which typically takes 3-4 cycles.

## Output

- Semantic view with calculated dimensions applied
- Verified query library grown from real usage
- Validation results confirming accuracy
