# Presenter notes

Material here runs in the presenters' AI-enabled account. It is not part of the participant path.

## Files

- `ai-agent-reference.sql`: a semantic view, Cortex Agent, and the
  `FLOOD_CLAIM_NARRATOR` function as deployed in the demo account. Object names
  match `CARTO_SDSC_DEMO`. Review them before reusing anywhere else.

## Run of show (45 min + 15 Q&A)

| Min | Moment | What must land |
|---|---|---|
| 00–04 | Caleb: Sandy hook + the question | Why location matters, and what the audience will do |
| 04–08 | Types + one spatial relationship | One point, one boundary, one predicate |
| 08–11 | **Lab A** | A first small win that doesn't depend on Marketplace |
| 11–18 | Public data + insurance framing | Provenance, grain, the coordinate-precision caveat |
| 18–23 | **Lab B** | County totals, and the missing Ocean County |
| 23–28 | Caleb: CoCo explains or edits the Lab B query | Two useful actions, no more |
| 28–32 | **Lab C** | Manhattan #13 by count but #1 by mean payout |
| 32–37 | Ryan: CARTO handoff | Same county result, explored interactively |
| 37–41 | CoWork question + limitations | The answer reconciles with the Lab C table |
| 41–45 | Four-pillar close + repo | Stop adding features |

**Handoff line:** "We built the analytical result in Snowflake. Ryan will now show how CARTO turns that same result into an interactive spatial workflow other people can explore."

**CoWork question:** "For the same counties, compare claim volume with mean paid amount. Show counts, missingness, and the query. Explain what changed and why these measures don't establish future property risk."

## Still to confirm with Ryan

- Which part of the answer CARTO owns: a Builder map, a Toolbox function, or a Workflow
- Which prepared table or view he receives, and its measure, geographic key, and timestamp
- Who owns the CARTO connection and authentication
- The fallback if the CARTO connection fails live

## Readiness: not yet verified

- [ ] Full participant path run from a **fresh self-service trial**, using only the README
- [ ] Listing install name and region availability in that trial
- [ ] Lab timings with a real audience-speed run
- [ ] CoWork map rendering is a presenter-account capability. Public docs don't list map charts, so don't promise it to participants.
- [ ] Ryan's live connection and fallback screenshots
- [ ] Confirm the official session slot with the organizers
