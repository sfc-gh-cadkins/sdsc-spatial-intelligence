# Go further

Optional material for after the labs. None of it is needed for Labs A to C.
For the step-by-step path through every workshop section, see
[`../WALKTHROUGH.md`](../WALKTHROUGH.md).

## Files

- [`ai-agent-reference.sql`](ai-agent-reference.sql): the semantic view and
  Cortex Agent used in the CoWork section. It builds on the views from
  [`../labs/04_build_the_pipeline.sql`](../labs/04_build_the_pipeline.sql),
  so run that first. Needs AI features, which self-service trials disable by
  default until a payment method is added.
- [`presentations/`](presentations/): the workshop slide pages. Open
  `presentations/index.html` in a browser.
- [`skills/`](skills/): a Cortex Code skill that recreates a demo environment
  in your own account, including an optional CARTO connector.

## Data grain

Everything here works at county level. FEMA truncates public claim
coordinates to about 11 km for privacy, so nothing in this repo places an
individual claim on a map.
