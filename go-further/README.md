# Go further

Optional material for after the labs. None of it is needed for the lab.
For the step-by-step path through every workshop section, see
[`../WALKTHROUGH.md`](../WALKTHROUGH.md).

## Files

- [`semantic-view-and-agent/`](semantic-view-and-agent/README.md): the
  semantic view and Cortex Agent used in the CoWork section. It has a Cortex
  Code prompt, a one-shot SQL script, the semantic view YAML, prerequisites,
  troubleshooting, and a no-AI fallback. It builds on the views from
  [`../labs/04_build_the_pipeline.sql`](../labs/04_build_the_pipeline.sql),
  so run that first. Needs AI features, which self-service trials disable by
  default until a payment method is added.
- [`custom-ai-function/`](custom-ai-function/README.md): the
  `FLOOD_RISK_CLASSIFIER` custom AI function from the Flood Risk Hub app. One
  SQL script creates it in your own account and runs it on real Sandy claims.
  Needs AI features.
- [`carto-mcp/`](carto-mcp/README.md): connect CARTO's MCP server to a
  Cortex Agent so CoWork can make CARTO maps. Covers the OAuth client, the
  Snowflake integration, attaching it to the agent, and troubleshooting.
  Needs a CARTO account and AI features.
- [`carto-cli-forecast-cones/`](carto-cli-forecast-cones/README.md): an
  advanced CoCo CLI prompt that builds a forecast-cone population workflow
  and map in your own CARTO org. Needs the CARTO CLI, a CARTO connection, and
  your own tract-population table.
- [`skills/`](skills/): a Cortex Code skill that recreates a demo environment
  in your own account, including an optional CARTO connector.

## Data grain

Everything here works at county level. FEMA truncates public claim
coordinates to about 11 km for privacy, so nothing in this repo places an
individual claim on a map.
