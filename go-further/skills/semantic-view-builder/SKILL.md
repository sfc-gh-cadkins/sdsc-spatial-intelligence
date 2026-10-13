---
name: semantic-view-builder
description: "Create or optimize a Snowflake semantic view for Cortex Analyst. Use when: building a new semantic view from a source table, optimizing an existing semantic view, adding calculated dimensions, adding verified queries, or improving semantic view quality. Triggers: create semantic view, build semantic view, optimize semantic view, improve semantic view, add calculated dimensions, add verified queries, semantic view for analyst."
---

# Semantic View Builder

A semantic view tells Cortex Analyst (and any Cortex Agent built on it) what your
columns mean: which ones are measures, which are dimensions, how coded values
translate to labels, and which questions have known-good SQL. Better metadata
means better answers.

## Intent Detection

| Intent | Triggers | Route |
|--------|----------|-------|
| CREATE | new semantic view, build from table, create from scratch | Load `create/SKILL.md` |
| OPTIMIZE | optimize, improve, fix, audit, add verified queries, agent gives wrong answers | Load `optimize/SKILL.md` |

Detect intent from the user's message and route immediately.

## Requirements

- A Snowflake account with Cortex Analyst available in your region.
- A role that can create semantic views in the target schema and SELECT on the source tables.
- Semantic view docs: https://docs.snowflake.com/en/user-guide/views-semantic/overview
