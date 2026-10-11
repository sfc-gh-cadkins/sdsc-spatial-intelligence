# Skills

## sdsc-setup

Recreates the Spatial Intelligence for Insurance demo environment on your own
Snowflake account: database/warehouse/schemas, a semantic view, a Cortex
Agent, a scoped viewer role, and (optionally) the CARTO MCP connector.

See [`sdsc-setup/skill.md`](sdsc-setup/skill.md) for the full walkthrough.

**Required steps:** database foundation, your own analytical tables, semantic
view, Cortex Agent, viewer role.

**Optional steps:** Marketplace data (Overture Maps), loading the sample
Hurricane Sandy NFIP dataset (bring your own dataset instead if you prefer),
CARTO MCP connector registration.

### Installing in Cortex Code (CoCo)

If you are using Cortex Code, drop `sdsc-setup/skill.md` into your local
skills directory, or reference it directly and ask CoCo to walk through it
with you against your own account.

### Running it manually

Every step in `sdsc-setup/skill.md` is plain SQL (and one YAML block) you can
run yourself in Snowsight, in order. No CLI tooling or package installation
required.
