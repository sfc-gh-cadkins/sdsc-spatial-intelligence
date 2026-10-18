# Advanced demo: forecast-cone population map with the CARTO CLI

Optional, and not part of the browser-only lab. This is a single Cortex Code
(CoCo) prompt. It builds a CARTO workflow and an interactive map showing how
much tract population fell inside each Hurricane Sandy forecast cone, using the
CARTO CLI and CARTO skills.

Browser-only attendees can skip this and follow the SQL lab in
[`../../WALKTHROUGH.md`](../../WALKTHROUGH.md).

## Prerequisites

You need all of these. The prompt checks for them and stops if one is missing.

- **CoCo CLI** with the CARTO skills available (`cortex` in a terminal).
- **CARTO CLI**, authenticated to **your own** CARTO organization.
- **A CARTO connection to your Snowflake account**, with a role that can create
  tables in one writable database and schema.
- **A tract-population table in Snowflake**, with one row per census tract: a
  unique tract ID, a population count, and a point geometry (for example, a
  population-weighted or interior point). Note its source and population
  vintage. This repo doesn't ship this table; bring your own.
- Network access to `nhc.noaa.gov` for the public NHC forecast-cone and
  best-track archives.

The prompt asks you for your CARTO connection name, database and schema,
initials, and the tract table's fully qualified name. Don't paste tokens or
passwords into the chat.

## The prompt

Paste this into a new CoCo CLI session:

> Build a Hurricane Sandy forecast-cone population workflow and interactive CARTO map using the CARTO CLI and CARTO skills. Use https://github.com/sfc-gh-cadkins/sdsc-spatial-intelligence for workshop context. First check the available CLI, skills, authentication, and Snowflake connection. Ask me in one message for any missing configuration: my CARTO connection name, writable Snowflake database and schema, initials, and the fully qualified tract-population table. Do not assume access to the presenters' shared environment. The tract table must contain a unique tract ID, population, and point geometry; verify its columns, geographic coverage, and population vintage if documented. If it is missing, stop and explain the prerequisite rather than substituting claims or county totals. Download al182012_5day_010.zip, al182012_5day_012.zip, al182012_5day_014.zip, al182012_5day_020.zip, al182012_5day_023.zip, al182012_5day_026.zip, and al182012_5day_028.zip from https://www.nhc.noaa.gov/gis/forecast/archive/ and the actual track from https://www.nhc.noaa.gov/gis/best_track/al182012_best_track.zip. Select each archive's _pgn shapefile with its companions and the best-track line shapefile, then load them using carto import. Use only the 120-hour cone for each advisory. Create and run a CARTO workflow that counts each tract once per advisory when its point is strictly inside the cone and sums its full population, retaining zero-match cones. Create a private CARTO map with a seven-position slider for the selected advisories, population and tract counts, advisory and issue time, and the actual track above the cone. Keep totals independent of viewport. Prefix new tables, workflow, and map with my initials and a unique run identifier; CARTO-generated intermediate names in its configured temporary schema are allowed. I authorize creating and running these new assets, but not overwriting existing assets, changing source data, or publishing publicly. Reuse available verified setup, parallelize independent downloads, limit concurrent imports to two, and authenticate through the CLI if needed. Independently verify all seven totals and test the slider's parameter bindings. Return the workflow and map links, validation limitations, and elapsed time. Describe the result as population represented by the supplied tract points inside forecast cones, not actual hurricane impacts or an underwriting recommendation.

## What it creates

All new and private, prefixed with your initials and a run ID:

- Imported cone and best-track tables in your schema.
- One CARTO workflow that joins tract points to cones.
- One private CARTO Builder map with an advisory slider.

It doesn't overwrite existing assets, change source data, or publish anything
publicly. To clean up, delete the prefixed map, workflow, and tables.

## Read this before drawing conclusions

Forecast cones show where the storm's center was forecast to go, not where
damage happened. The result is the population represented by your tract points
inside each cone. It isn't a measure of hurricane impact, and it isn't an
underwriting recommendation. Totals depend on the tract table's vintage and on
how its points were generated.
