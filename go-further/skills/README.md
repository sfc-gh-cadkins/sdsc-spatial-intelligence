# Skills

## sdsc-setup

Recreates the Spatial Intelligence for Insurance demo environment on your own
Snowflake account: database/warehouse/schemas, a semantic view, a Cortex
Agent, a scoped viewer role, and (optionally) the CARTO MCP connector.

See [`sdsc-setup/skill.md`](sdsc-setup/skill.md) for the full walkthrough.

**Required steps:** database foundation, free Marketplace data, county-level
analytical views, semantic view, Cortex Agent, viewer role.

**Optional steps:** CARTO MCP connector registration.

### Installing in Cortex Code (CoCo)

If you are using Cortex Code, drop `sdsc-setup/skill.md` into your local
skills directory, or reference it directly and ask CoCo to walk through it
with you against your own account.

### Running it manually

Every step in `sdsc-setup/skill.md` is plain SQL (and one YAML block) you can
run yourself in Snowsight, in order. No CLI tooling or package installation
required.

## semantic-view-builder

Builds a new semantic view from a table, or improves an existing one so Cortex
Analyst and Cortex Agents answer more accurately. It covers calculated
dimensions for integer dates and coded columns, comments and synonyms, correct
rollup metrics, and a weekly loop for adding verified queries from real usage.

- [`semantic-view-builder/SKILL.md`](semantic-view-builder/SKILL.md): routes to create or optimize
- [`semantic-view-builder/create/SKILL.md`](semantic-view-builder/create/SKILL.md): new semantic view from a source table
- [`semantic-view-builder/optimize/SKILL.md`](semantic-view-builder/optimize/SKILL.md): audit and verified-query iteration

In Cortex Code, copy the `semantic-view-builder` folder into your local skills
directory and ask "create a semantic view" or "optimize my semantic view".
Without Cortex Code, every step is plain SQL you can follow in Snowsight.
