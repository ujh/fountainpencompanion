# Merged implementation roadmap: LLM migration + pen clustering

**v2, decisions folded in 2026-09-14.** Synthesised 2026-09-12 from three ordering proposals and
three judge reports, checked against codebase maps and read-only production SQL; revised 2026-09-14
after twenty adversarial verifier passes that re-checked every claim against the repo, the gem
sources and production data; re-ordered and rewritten on 2026-09-14 after the owner decided all 39
open questions, and re-verified step by step on 2026-09-15. All production
figures are as of 2026-09-12 to 2026-09-14 unless stated otherwise; they drift daily by tens to low
hundreds, so re-count before acting on one.

43 steps, S00-S42 (one v1 step dropped, one added). The "v1 id" column in section 1 maps the
numbering of the 2026-09-14 draft (v1) to this version.

Ground rules this roadmap follows:

- One implementer, strictly sequential. Every step is one PR (or one non-code activity) that can be
  merged on its own; master auto-deploys, migrations run in the Fly release command.
- **Nothing here is an open question.** The owner decided all 39 on 2026-09-14; section 5 is the
  decision log. Where a step's behaviour follows a decision it is written as fact and cited in
  brackets, e.g. "(Q17)", so the rationale can be looked up. Engineering choices that did not need
  the owner (an index, a constant name, a flag name) are listed under "Resolved without asking"
  inside section 5.
- Decisions recorded in the plans are respected unless the DIGEST or a verifier showed they cannot
  work as written, or the owner overrode them on 2026-09-14; both kinds are in section 4.
- Under Q32 the pen agents are DigitalOcean agents from their first line of code. No step says
  "gpt-4.1" about a pen agent and there is no pen cutover step anywhere.
- Each step carries an **Implementation notes** item with the file:line anchors, prod numbers, gem
  facts and test cases a less experienced implementer would otherwise have to rediscover, and a
  **Decisions applied** item naming the decisions that shaped it.

Legend: size XS (hours) / S (about a day) / M (1-3 days) / L (3-5 days; the step says how to split
if wanted). Prod risk `medium*` means the PR changes prod behaviour or schema on merge and the
owner should be available when it merges (auto-deploy).

## 1. Ordering at a glance

Legend as v1: size XS (hours) / S (about a day) / M (1-3 days) / L (3-5 days). Prod risk `medium*`
means the PR changes prod behaviour or schema on merge (auto-deploy) and the owner should be
available. "changed by" lists the decisions that change the step's order or scope; "-" means the v1
text stands apart from renumbering and the removal of question language.

| #   | id                                 | title                                                                                                                                                                        | source phase(s)                         | size | prod risk                      | depends on                                                           | v1 id | changed by                        |
| --- | ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------- | ---- | ------------------------------ | -------------------------------------------------------------------- | ----- | --------------------------------- |
| 0   | S00-ops-prereqs                    | Fly login and secrets inventory; DO account and the one key `DO_INFERENCE_TOKEN` (dev value in `.env.local`, prod value as a Fly secret); catalog access; DB backup check    | prerequisite (neither plan)             | XS   | none                           | -                                                                    | S00   | Q3, Q32                           |
| 1   | S01-do-spike                       | DigitalOcean compatibility spike with a throwaway script; findings recorded; picks the pen agents' starting DO model                                                         | migration P0 + pen decision 6 (revised) | S    | none                           | S00                                                                  | S01   | Q32, Q33, Q5                      |
| 2   | S02-pen-retrieval-check            | Pen retrieval sanity check and `embedding_search` latency on the existing dev prod copy                                                                                      | pen P0 + seed of migration P2           | S    | none                           | -                                                                    | S02   | -                                 |
| 3   | S03-stale-docs-fix                 | Fix stale developer guidance (CLAUDE.md tool naming and raix, spec/agents/README.md)                                                                                         | neither plan (DIGEST)                   | XS   | none                           | -                                                                    | S03   | -                                 |
| 4   | S04-llm-config-chat                | `config/llm.yml` per-agent chat config with the scoped override hook; key lookup fix; OpenAI stays the default for every existing agent                                      | migration P0                            | L    | low                            | S01                                                                  | S15   | Q32, Q1, Q2, Q3, Q4               |
| 5   | S05-model-not-found-alert          | Explicit alert on the provider's "model not found" error; runbook table naming a manual replacement model per agent                                                          | migration P0 (Q33; neither plan)        | XS   | low                            | S04, S01 (item 14)                                                   | -     | Q33, Q32                          |
| 6   | S06-pen-groundwork                 | `agent_logs` on three pen models, per-agent AgentLog scopes, `with_collected_pens` (the Q8 filter), tuple helper, `(name, state)` index                                      | pen P0                                  | S    | low                            | -                                                                    | S04   | Q8                                |
| 7   | S07-csv-import-routing             | Route `ImportCollectedPen` through `SaveCollectedPen`                                                                                                                        | neither plan (DIGEST)                   | S    | low                            | -                                                                    | S39   | Q9                                |
| 8   | S08-stale-data-cleanup             | Cleanup operations + rake wrappers for the decided deletion list, orphan rows, NULL vectors and the one-off re-save of unclustered pens; run on dev copy and prod            | pen P0 (+ prod data check)              | M    | low                            | S00, S07 (S06 optional)                                              | S05   | Q8, Q9                            |
| 9   | S09-embedding-search-hygiene       | Cutoff/ef_search constants, narrowed selects, tier-3 N+1, first real-pgvector spec, public search request spec                                                               | pen P0 + migration P2 prerequisite      | S    | low                            | S02                                                                  | S06   | -                                 |
| 10  | S10-pen-tools                      | PenSimilaritySearchTool (top-K variants per model), PenFullTextSearchTool, PenWebSearchTool, pen KnownBrand (EXISTS over assigned clusters)                                  | pen P0                                  | M    | none                           | S09, S03                                                             | S07   | Q17, Q18                          |
| 11  | S11-pen-agent-decide               | PenVariantClusterer: `config/llm.yml` entry on the S01 DO model, prompt, decision tools with the create-tool duplicate check, `decide`, guards, empty-cluster marker log     | pen P1                                  | M    | none                           | S10, S06, S04                                                        | S08   | Q32, Q19, Q20, Q18                |
| 12  | S12-pen-agent-apply                | PenVariantClusterer `approve!`/`reject!`, collision refusal, cleanup, plain refuse-and-reject guard                                                                          | pen P1                                  | M    | none                           | S11                                                                  | S09   | Q20, Q22, Q23, Q21                |
| 13  | S13-pen-workers                    | RunPenClustererAgent (retry 2), TopUpPenClusteringQueue (waiting + processing by name, hand-over exclusion), RunFailedClusterJobs branch, CleanUp tagging                    | pen P1                                  | M    | low                            | S11, S06, S12                                                        | S10   | Q4, Q23, Q24, Q19                 |
| 14  | S14-pen-admin                      | Admin review controller, shared partial + presenter (latest 500), dashboard count, guidance logs, delete-history fix (also applied to the ink page)                          | pen P1                                  | M    | low                            | S12, S13                                                             | S11   | Q22, Q25, Q24                     |
| 15  | S15-pen-drip-enable                | Set `PEN_CLUSTERING_QUEUE_DEPTH=10`, first top-up; the first prod DO tool-calling traffic; hand review for about two weeks; the owner sets the Q27 bar at the end (non-code) | pen P1                                  | XS   | low                            | S14, S13, S05, S00                                                   | S13   | Q32, Q26, Q28, Q27                |
| 16  | S16-pen-react-marker               | Badge plus index filters for pending-agent-log clusters and handed-over clusters in the pens-micro-clusters React app                                                        | pen P1                                  | S    | low                            | S06, S13, S14; after S15 (Q26)                                       | S12   | Q26, Q23, Q22                     |
| 17  | S17-bench-db                       | Bench database tooling (second DB in the same Postgres container via `DATABASE_NAME`, full copy, isolation, .dockerignore); kick off the first dump                          | migration P1                            | M    | low                            | S08                                                                  | S14   | Q6, Q7                            |
| 18  | S18-llm-config-embeddings          | Embeddings config, model-aware cache key, `fetch_many`, explicit-entry client, search constants wired to config, dev-branch removal, model-not-found matcher                 | migration P0                            | S    | low                            | S04, S09, S05                                                        | S16   | Q1, Q3, Q33                       |
| 19  | S19-ink-decide-entry-point         | Side-effect-free `decide(agent_log:)` on InkClusterer/concern; memoisation fix at ink_clusterer.rb:174                                                                       | migration P1 prerequisite               | S    | low                            | -                                                                    | S18   | -                                 |
| 20  | S20-harness-core-ink               | Harness skeleton: InkClusterer case exporter (decided label rules), leave-one-out runner, record/replay, report, hand-maintained price table                                 | migration P1                            | L    | none                           | S17, S04, S18, S19                                                   | S19   | Q10, Q2, Q5                       |
| 21  | S21-harness-pen-cases              | Pen L1 case exporter (over-sampled singletons, re-derivation inside the transaction), hide step, hard-negative label rule                                                    | pen P2 + migration P1                   | M    | none                           | S20, S11                                                             | S20   | Q12, Q13, Q17, Q8                 |
| 22  | S22-bench-round-0                  | Round 0: gpt-4.1 for InkClusterer, the S01 DO model for pen L1, on current embeddings; compare with the drip; bench refresh #1 (non-code)                                    | pen P2 + migration P3 baseline          | S    | none                           | S21, S15 (two weeks of drip)                                         | S21   | Q32, Q5, Q6                       |
| 23  | S23-embeddings-bench               | `bench_embeddings`, four DO candidates, recall@k and cutoff sweep for inks and pens; pick                                                                                    | migration P2                            | M    | none                           | S18, S21, S01                                                        | S22   | Q12                               |
| 24  | S24-embedding-v2-backfill          | `embedding_v2` columns, two-entry embeddings config, dual-write (YAML flip PR), self-chaining backfill; run the prod backfill                                                | migration P2 steps 1-2                  | M    | medium*                        | S23, S00                                                             | S23   | Q1, Q3, Q4, Q9, Q31               |
| 25  | S25-shadow-code                    | Shadow-mode code for InkClusterer and ReviewApprover, sub-agents on the candidate (not enabled)                                                                              | migration P4                            | M    | low                            | S19, S04 (S20 soft)                                                  | S24   | Q14, Q2                           |
| 26  | S26-hnsw-index-v2                  | HNSW cosine index on `embedding_v2` for both tables: built by hand from a detached session, then a recording migration                                                       | migration P2 step 3                     | S    | medium*                        | S24                                                                  | S25   | Q30, Q31                          |
| 27  | S27-embedding-read-flip            | Flip `read` (a PR) with recalibrated cutoffs; drip paused for the flip day; watch for a week                                                                                 | migration P2 step 4                     | XS   | medium*                        | S26                                                                  | S26   | Q29, Q1                           |
| 28  | S28-harness-checkers-review-export | Checker `decide` + bench, ReviewApprover cases (latest run, human-confirmed, consistent), export mode and rubrics for unlabelled agents                                      | migration P1                            | L    | none                           | S20                                                                  | S27   | Q11, Q14, Q15                     |
| 29  | S29-pen-model-clusterer-agent      | PenModelClusterer (L2) agent on the S01 DO model, tools with the create-tool duplicate check, `decide`, L2 case exporter; inert                                              | pen P3 (agent half)                     | M    | none                           | S04, S20, S10, S06, S11, S21                                         | S28   | Q32, Q20, Q12, Q8                 |
| 30  | S30-chat-bench-round               | Chat bench round(s): OpenAI baselines for the ink agents, the S01 model as the pen baseline, DO candidates; pick per agent; bench refresh #2                                 | migration P3 + pen P2 model pick        | M    | none                           | S27, S28, S29, S21                                                   | S29   | Q32, Q5, Q6, Q14, Q15, Q16        |
| 31  | S31-chat-cutover-wave-1            | Config-flip PRs for the low-risk ink agents (summarizers, SpamClassifier, PenAndInkSuggester, then ReviewFinder, InkBrandClusterer); multi-PR/ops activity                   | migration P5                            | S    | medium*                        | S30, S05                                                             | S30   | Q32, Q33, Q1                      |
| 32  | S32-shadow-run                     | Enable shadow mode for InkClusterer and ReviewApprover for about two weeks (non-code)                                                                                        | migration P4                            | XS   | low                            | S25, S30 (S31 soft)                                                  | S31   | Q14                               |
| 33  | S33-pen-directive-tuning           | Pen model config change if S30 picked one; tune the PenVariantClusterer directive against the bench (minor rounds); raise the queue depth once the Q27 bar is met            | pen P2                                  | M    | low                            | S30, S22, S15 (the bar)                                              | S32   | Q32, Q27, Q6, Q10                 |
| 34  | S34-embedding-dual-write-off       | Turn dual-write off (YAML default), `ignored_columns` for the old vector, specs to 1024 dims                                                                                 | migration P2 step 5 (first half)        | S    | medium*                        | S27 (a week elapsed), S30                                            | S33   | Q1, Q31                           |
| 35  | S35-drop-old-embedding-column      | Drop the old HNSW indexes and `embedding` columns after a backup point check; the column stays `embedding_v2`                                                                | migration P2 step 5 (second half)       | S    | medium*                        | S34                                                                  | S34   | Q31, Q30                          |
| 36  | S36-pen-model-clusterer-wiring     | L2 approve/reject (collision refusal), trigger with guards behind `PEN_CLUSTERING_L2_ENABLED`, admin page + badge/filter marker, RunFailedClusterJobs, full cascade          | pen P3 (wiring half)                    | L    | low                            | S29, S14, S13, S12                                                   | S35   | Q21, Q20, Q22, Q26, Q32           |
| 37  | S37-chat-cutover-final             | Flip InkClusterer and ReviewApprover after shadow results, CheckInkClustering::* on the bench result                                                                         | migration P5                            | S    | medium*                        | S32 (two weeks), S31                                                 | S36   | Q32, Q1                           |
| 38  | S38-pen-checkers                   | CheckPenClustering::{Assign,Create,Ignore,Human} behind `PEN_CLUSTERING_CHECKERS_ENABLED`, follow-up dispatch, auto-approval, admin percentages                              | pen P4                                  | L    | low at merge, medium at enable | S33 (Q27 bar met), S28, S30 (S31 informational)                      | S38   | Q32, Q27, Q34, Q24, Q22, Q19, Q35 |
| 39  | S39-retire-openai-keys             | Remove `OPEN_AI_TOKEN` and `OPEN_AI_EMBEDDINGS` from Fly secrets, `.env`, `ci.yml` and the config aliases                                                                    | migration P5                            | XS   | low                            | S37 (watch week elapsed), S34, S00                                   | S37   | Q3                                |
| 40  | S40-pen-realtime-trigger           | `Pens::UpdateMicroCluster` enqueues the L1 agent with the 30 s debounce and a run-time cap check                                                                             | pen P5                                  | S    | low                            | S38, S07                                                             | S40   | Q36, Q35                          |
| 41  | S41-pen-backlog-drain              | Drain the L1 backlog in priority order on the DO model (small code + months of running); unknown-brand singletons last                                                       | pen P5                                  | M    | medium                         | S38, S30 (S31 informational; S40 ordered before; S42 before stage 3) | S41   | Q32, Q23, Q37, Q38, Q35, Q18      |
| 42  | S42-pen-brand-clusterer            | PenBrandClusterer (L3) as fallback for `Pens::AssignBrand`, L1 shape (decide, wait, approve applies, reject re-queues to the manual brand page) with a review page           | pen P5                                  | M    | low                            | S36, S06 (S04, S14 transitive)                                       | S42   | Q39, Q20                          |

Calendar waits and what fills them: the two-week hand-review drip (S15) overlaps the S16-S21 build
(marker S, bench DB M, embeddings config S, ink decide S, harness core L, pen cases M = 8-14 working
days against 10 working days of drip), so round 0 (S22) waits on the implementer or starts on time,
never on the owner; the drip keeps accumulating labels, and at its end the owner sets the Q27 bar that
gates S33's depth raise and S38. The hours-long first dump (S17) overlaps S18-S19; the hours-long prod
backfill (S24) overlaps S25; the one-week watch after the read flip (S27) overlaps S28-S29; the
two-week shadow run (S32) is filled by S33-S36 (M + S + S + L = 6-10 working days, so 0-4 idle days,
filled by the S39 docs/runbook preparation and by scaffolding S38's specs, or accepted); S37's watch
week is filled by S38 (L, 3-5 days; if the Q27 bar is not yet met when that week starts, build S42
there instead and slide S38 after S39); S39 follows the watch week; S41's months of running overlap
S42. The owner's own time is the bottleneck for S22 (grading round 0 against the drip), S30
(export-mode grading in Claude Code), S32 (reading the weekly shadow reports), S37 (clearing the
post-hoc review queue so the week-1 numbers have an n) and for setting the Q27 bar after S15.

The v1 "Note on the bench chain" (S14 blocked by Q8) is deleted: Q8 is decided and S08 precedes S17.

## 2. Why this order

### The spine

The two plans touch at four points: the per-agent LLM config with an injection point, the bench DB and
leave-one-out harness (including the pen cases that migration P2/P3 also use), the embedding search
(cutoff, ef_search, column) and the swap of embeddings underneath it, and the chat model the pen
agents run on. Under Q32 the last point is no longer a hand-off from the migration to the pen plan at
the end: the pen agents are DigitalOcean agents from their first PR, which makes the config layer the
first shared foundation instead of the fifth. The order is therefore: probe the two biggest unknowns,
build the config layer once, build the pen P0/P1 path on top of it, start the drip (which doubles as
the first prod DO tool-calling evidence), then build every other shared foundation exactly once and
run the migration in its decided order with every long wait filled by independent code.

1. **Probe first (S01-S03).** The one-day DO spike answers whether RubyLLM 1.16's forced tool choice,
   tool-call replay, system-prompt role, image URLs and 1024-dim embeddings work on DO at all, and,
   new in v2, it picks the pen agents' starting DO model from two or three candidates (Q32) and
   records the provider's exact "model not found" response (needed by S05). The pen retrieval check
   (S02) runs on the existing 12 GB dev prod copy, so the hours-long bench dump is not on the critical
   path to the first pen decision. S03 fixes the templates the tool PR copies from. The DIGEST shows
   the plan's "api_base + assume_model_exists is enough" is incomplete (`provider:` is required, the
   system prompt goes out as role `developer`, tool schemas carry `strict`/`additionalProperties`,
   images go as remote URLs, and `build_chat` at app/agents/concerns/ruby_llm_agent.rb:86 passes no
   `provider:`), so the config layer is designed after the spike, not before.
2. **Config layer before any pen agent (S04-S05).** Q32 overrides pen decision 6: there is no
   `MODEL_ID = "gpt-4.1"` for pens and no later pen cutover. The pen agent (S11) is born as an entry
   in `config/llm.yml` pointing at the DO model S01 picked, with `DO_INFERENCE_TOKEN` (Q3), so the
   layer (Q1 format, Q2 scoped override) must exist first. OpenAI stays the default for every ink
   agent until its own flip, so S04 changes no prod behaviour. The model-not-found alert (S05, Q33) is
   its own XS PR right after, because the first DO agent in prod is the drip (S15), not an ink flip.
   Nothing pen-side is a prerequisite of S04 or S05; S04 depends on S01 only.
3. **Pen P0/P1 as nine small PRs (S06-S14), CSV routing first (S07).** Groundwork, import routing,
   cleanup, search hygiene, tools, agent decide half, agent apply half, workers, admin. S07 moves to the
   front of the cleanup (Q9) so the single one-off re-save inside S08 is the last re-save ever needed
   and the first dump (S17) and the backfill (S24) both see complete tables. The agent path is inert in
   prod (depth 0) until S15; S08, S06/S14 and S09 touch prod and carry "low", not "none".
4. **The drip on DO (S15), then the React marker (S16).** Two weeks of hand review accumulate real
   per-action approval rates and rejection notes while the harness is built; those rejections become
   the bench's hard-negative subset (pen decision 7). Under Q32 the drip is also the first real DO
   tool-calling traffic in production: forced tool choice, `DecisionNotReachedError` rate, transcript
   replay by `RunFailedClusterJobs` (DO ids on DO), 429 behaviour and the S05 alert path are all
   observed here, weeks before the first ink flip. The marker ships one PR after the drip (Q26) as a
   badge plus filters that make the hand-over fallback workable; nobody has assigned at L1 since
   January 2026, so the one-PR delay costs nothing. At the end of the two weeks the owner sets the Q27
   bar.
5. **Shared foundations once (S17-S21).** Bench DB tooling (second database in the same container,
   Q6; full copy, Q7), embeddings config with `fetch_many` (S18, kept in the migration block, see the
   cross-plan list), the side-effect-free ink `decide`, the harness core with ink cases (Q10), then pen
   cases (Q12, Q13). The chat config already exists, so the runner is built once against the real
   injection point.
6. **Validate the bench before changing anything (S22).** Round 0 runs InkClusterer on gpt-4.1 and pen
   L1 on the same DO model the drip runs, on the current embeddings, and compares the pen numbers with
   the drip per action and per stratum (multi-pen cells are the drip's counterpart; singleton cells
   have none). Because prod and bench run the same pen model (Q32), a gap can only be population or
   label rules, never the model.
7. **Embeddings before chat models (S23-S27), as the migration plan decides.** Bench the four
   candidates, add the nullable column and dual-write (YAML flip PR, Q1), backfill for hours while the
   shadow code is written, build the index by hand from a detached session (Q30), flip reads with the
   drip paused for the flip day (Q29), watch a week.
8. **Finish the harness and the L2 agent during the watch week (S28-S29), then one paid chat round
   (S30)** covering InkClusterer, the checkers, ReviewApprover, pen L1 and pen L2 (both benched against
   the S01 starting model as their baseline), plus export-mode grading for the unlabelled agents
   (Q11, Q14, Q15, Q16 as decided).
9. **Cutover in waves (S31, S32, S37) for the ink agents only, with the shadow filled by pen tuning,
   the old-column retirement and the L2 wiring (S33-S36), the final-cutover watch week filled by the
   pen checkers (S38), then the key retirement (S39).** There is no pen cutover in any wave (Q32); a
   different pen model picked in S30 is a config PR at the start of S33 (L1) and S36 (L2). The pen
   checkers no longer wait for the ink cutover: the cost preference that placed them after it in v1
   is void because the whole pen stack is on DO from S15; their gate is the Q27 bar (S33) plus the
   checker `decide` pattern (S28) and the model pick (S30). OpenAI keys are retired only after the
   last reader of the old embedding column is gone (S39 after S34) and S37's watch week has passed.
10. **Volume multipliers last (S40-S42):** real-time trigger with the run-time cap check (Q36),
    backlog drain in stages with the unknown-brand singletons last (Q38), L3 in the L1 shape (Q39)
    live before the drain's stage 3.

### Cross-plan dependencies and overlaps, and how each is resolved

- **Config layer (migration P0) vs pen decision 6 — reversed by Q32.** v1 built the pen agent on a
  constant and converted it later; v2 builds the config layer first (S04) and the pen agent is a
  config entry from S11 on. The spike (S01) picks the starting model; S30 may change it (a config PR in
  S33/S36 with a boundary marked in the drip statistics). The pen agent's spec stubs the same literal
  `https://api.openai.com/v1/chat/completions` as every other agent spec because the `test:` section of
  `config/llm.yml` resolves every class to the test default endpoint; DO entries live under
  `production:`/`development:` only.
- **Embeddings config (S18) stays in the migration block; it does not move with the chat config.**
  The pen tools call `EmbeddingsClient` through `Pens::Model.embedding_search` (pens/model.rb:33-34),
  which stays on OpenAI `text-embedding-3-small` until the read flip (S27); the drip needs none of the
  model-aware cache key, `fetch_many` or the explicit-entry client; its first consumers are the harness
  core (S20: the key path without the `Rails.env.development?` branch), the embeddings bench (S23) and
  the backfill (S24). Moving it before the drip would add a PR to the drip's critical path for nothing.
  The one consequence of the split is a dev-key gotcha: S04 renames `OPEN_AI_DEV_TOKEN` to
  `OPEN_AI_TOKEN` in `.env.local`, but `EmbeddingsClient#access_token` (app/lib/embeddings_client.rb:29)
  still reads `OPEN_AI_DEV_TOKEN` in development until S18, so `.env.local` carries both names between
  S04 and S18 (S04's DoD says so).
- **The DO prod key is needed before the drip, not before the backfill.** v1 created the prod key in
  the backfill step because that was the first prod DO traffic; under Q32 the drip (S15) is. S00 creates
  the one key name `DO_INFERENCE_TOKEN` (Q3) with a dev value in `.env.local` and sets the prod value as
  a Fly secret before S11 merges (the pen entry references the name; keys are read at call time, so a
  missing secret fails at the first run, not at boot).
- **The model-not-found alert (Q33) protects the drip first.** S05 lands before S15 so the first DO
  agent in prod has the alert; S31's ink flips inherit it. S18 wires the same matcher into
  `EmbeddingsClient`.
- **Bench harness (migration P1) vs pen P2 "build the pen half if the harness is not there".** The
  generic runner lands first (S20); pen cases only add an exporter and a hide step (S21). S11 structures
  the pen agent as `perform = guards -> decide -> waiting_for_approval!` from day one, so the bench and
  the shadow worker call `decide` without later re-plumbing.
- **Pen P0 retrieval sanity check vs migration P2 pen retrieval bench.** Same leave-one-out recall@k
  question; S02 writes the logic once under `lib/bench/` (docs/llm-migration-plan.md:190), S23 runs it
  per candidate model with the Q12 hide step.
- **Pen P0 "measure `embedding_search` latency on prod-sized data".** Prod `pg_stat_statements` is
  unreadable by the read-only role; S02 measures on the dev copy (0.5-2 s per call; pgvector 0.8.2
  locally vs 0.7.4 in prod).
- **The six `0.6` cutoffs, two `hnsw.ef_search` literals and the hard-coded column.** Constants in S09,
  config keys in S18, per-column entries (`legacy`/`current`/`read`/`dual_write`) in S24, sweep in S23,
  flip in S27. The public `PenModelsController#index` is covered automatically and gets its first
  request spec in S09.
- **Backfill needs a batch client and a column-aware `FetchEmbedding`.** `fetch_many` and the
  explicit-entry client arrive in S18; the column parameter with the `embedding_v2` migration in S24.
  Because S07 routes imports before S08 re-saves the 1,407 unclustered pens (1,260 of them without an
  embedding row) and builds the 2 missing ink micro cluster rows, the backfill enumerates complete
  tables; no later re-save exists (Q9).
- **Side-effect-free invocation.** One `decide(agent_log:)` path (S11 for pens, S19 for inks, S28 for
  the checkers, S25 for ReviewApprover via a shadow subclass) shared by the runner (S20), the pen bench
  (S21) and the shadow worker (S25); tool writes are covered by the per-case rollback or by stopping
  after `ask!`.
- **Cost attribution is bench-only (Q5).** No usage fields, no per-model admin graph. The harness
  prices tokens from a hand-maintained table filled from S01's catalog, keyed by the response `model`
  string; S30 applies the acceptance bar from it.
- **Shared admin partial (S14)** is reused by L2 (S36), the checkers' "correct auto review" percentages
  (S38) and L3 (S42). The stats presenter built in S14 (latest 500 manually processed logs, Q25) is what
  S38 later fills.
- **Sidekiq thread budget (Q35: accept the single worker, watch latency).** `RunPenClustererAgent` gets
  its own throttle slot (S13); with `SIDEKIQ_CONCURRENCY=5` (fly.toml:33) the three throttled worker
  classes can hold four of five threads once checkers and the trigger exist. Watched from S15; revisited
  when the drain starts (S41).
- **Chat bench after the read flip (migration rule) and after the L2 agent exists (S29),** so one paid
  round covers every agent; pen prompt tuning (S33) runs after the pick so the directive is tuned once.
- **Old-column retirement (S34-S35) after the watch week and after a chat round on the new
  embeddings; key retirement (S39) after dual-write is off (S34):** dual-write keeps embedding the old
  column through OpenAI's `text-embedding-3-small`.
- **L2 split in two.** The agent half (S29) is inert and is what the chat bench needs; the wiring half
  (S36) carries the trigger guards and the full cross-level cascade (Q21).
- **Summarizers first in wave 1 (S31).** GoogleSearchSummarizer is the `search_web` sub-agent of
  InkClusterer, CheckInkClustering::* and both pen agents; Youtube/WebPage summarizers are sub-agents
  of ReviewFinder and ReviewApprover. In bench and shadow the sub-agents run on the same candidate as
  the agent under test (Q14); in prod the drip's `search_web` runs on OpenAI gpt-4.1-mini until S31.
- **In-flight logs at cutover.** A `processing` transcript containing tool-call ids is resumed and
  replayed by `RunFailedClusterJobs` and Sidekiq retries. For the pen agents this replay is DO-on-DO
  from S15 on (same provider, no cross-provider concern). Cross-provider replay (OpenAI ids on DO and,
  for a flip-back, DO ids on OpenAI) matters only for the ink flips; S01 item (3) verifies both
  directions and each flip PR merges in a quiet hour.
- **Ink-side stale embeddings** are cleaned in S08 with the pen rows, so the ink retrieval baseline (S23)
  is measured on a complete label set.
- **CleanUp's 3-hour auto-rejections** are tagged in S13 (`extra_data.auto_rejection = "orphaned"`) and
  excluded from every approval-rate figure; the empty-cluster marker log (Q19, S11) reuses the same
  exclusion.
- **Two baselines per agent are run on purpose:** ink gpt-4.1 in S22 (old embeddings) and S30 (new);
  pen L1 on the S01 DO model in S22 and S30. About $10 of duplicated spend buys a harness validated
  against real drip labels before the retrieval layer changes.

### Where the order deviates from the phase order inside the plans, and why

- **Migration P0 (config) lands before pen P0/P1 (Q32).** This is the reverse of v1's deviation. Pen
  decision 6 is overridden: the pen agents are born on DO. The spike (the risky part of P0) still runs
  first.
- **Migration P1 is three PRs, with pen cases in the middle (S20, S21, S28).** Unchanged.
- **Pen P2 is split.** Bench cases and round 0 before migration P2; directive tuning after migration P3
  picks the model (S33). Unchanged.
- **Pen P3 (L2) is split around the chat bench** (S29 before, S36 after) with its own flag
  `PEN_CLUSTERING_L2_ENABLED`. Unchanged.
- **Migration P2 step 5 (drop old column) is delayed past the chat round** and split into two PRs.
  Unchanged.
- **Migration P5 key retirement is its own step after dual-write is off.** Unchanged.
- **The React marker ships after the drip is enabled (Q26),** as badge plus filters; the plan's
  "double work" purpose is dropped (Q22: humans never work the React app and the agent queue at the
  same time; the app is the hand-over fallback).
- **Pen P4 (checkers) is no longer placed after the migration cutover.** v1 placed S38 after the final
  ink flip as a cost preference; Q32 makes the pen checkers DO agents from birth, so that preference is
  void. S38 now fills S37's watch week and is gated only by the Q27 bar (owner-set after S15, measured
  by S33), the checker `decide` pattern (S28) and the model pick (S30).
- **CSV import routing (S07) is unconditional and precedes the cleanup (Q9).** v1 parked it as a
  conditional late step; it now guarantees that S08's one-off re-save is the last one.
- **L3 uses the L1 shape (Q39),** overriding the pen plan's "applies immediately and logs
  waiting_for_approval like the ink version". No undo code exists.
- **Dropped:** the conditional usage-fields step (Q5) and the `embedding_v2` rename (Q31). The retry
  budget is deferred (Q4): today's behaviour stays everywhere except `RunPenClustererAgent`'s `retry: 2`.
- **Two plan bullets covered in a different step than the plan implies** (top-up after an empty/errored
  run in S13; dashboard counts per level in S14/S36/S42). Unchanged.

### What changed vs v1, and why (summary for the reviewers)

1. v1 S15 (chat config) → S04, before every pen step; the pen agent is a config entry on a DO model
   from birth; S01 additionally picks that model. Reason: Q32.
2. New S05 (model-not-found alert), before the drip. Reason: Q33 plus Q32 (the first DO agent in prod
   is the drip).
3. v1 S39 (CSV import routing) → S07, unconditional, before the cleanup; S08's task (7) is the single
   one-off re-save. Reason: Q9.
4. v1 S12 (React marker) → S16, after the drip; scope = badge plus two filters. Reason: Q26, Q23, Q22.
5. v1 S17 dropped. Reason: Q5. v1 "S34b" confirmed non-existent. Reason: Q31.
6. v1 S38 (pen checkers) moves from after the key retirement to between the final ink cutover (S37) and
   the key retirement (S39), filling S37's watch week (whose v1 filler, S39, moved to the front). The
   S38 → final-cutover edge is deleted. Reason: Q32 voids the cost gate; Q27 is the real gate.
7. Edges deleted: drip → marker (Q26); final cutover → L2 wiring (Q32); checkers → final cutover (Q32);
   drain → final cutover (Q32); round 0 → usage fields (Q5). Edges added: pen agent decide → config
   (S11 → S04); drip → alert (S15 → S05); embeddings config → alert matcher (S18 → S05, soft); cleanup →
   import routing (S08 → S07); marker → workers/admin (S16 → S13, S14).
8. S18 (embeddings config) keeps its v1 position relative to the bench DB; justification in the
   cross-plan list.
9. No pen cutover anywhere: S31 and S37 are ink-side only; a changed pen model pick is a config PR in
   S33/S36.
10. Every "blocked by" disappears; every decision is written as fact. Both Q27 yardsticks are recorded
    in S15 for the owner's later choice.

## 3. Steps

### S00-ops-prereqs — Fly login, secrets inventory, DO account and keys, catalog access, DB backup check

- **Goal.** Zero-code preparation that every later "set the Fly secret" step and the spike assume.
  Log the Fly CLI in (installed, v0.4.102, currently not logged in per the DIGEST) and record the
  names of the prod secrets (names only, never values) and the worker machine count/VM size. Create
  the DigitalOcean inference account, one dev key now, and confirm read access to the model catalog
  and its pricing page. Confirm the DO managed Postgres backup / point-in-time-recovery setting and
  its retention window so S35 (drop-old-embedding-column) can rely on it. Confirm
  `PRODUCTION_READONLY_DATABASE_URL` is present in `.env.local` and the OrbStack disk has room for a
  14 GB bench copy plus the 16-18 GB of candidate vectors S23 (embeddings-bench) writes into the
  bench database (79 GB free on 2026-09-12).
  This step also creates the DigitalOcean inference key's **production** value now, as a Fly secret,
  not later: under Q32 the pen agents are DigitalOcean agents from their first line of code, and the
  first prod DigitalOcean traffic is the drip (S15), not the embeddings backfill — the prod key must
  exist before that traffic, not before a later step.
- **Depends on.** Nothing.
- **Why here.** Cheapest possible start; the spike (S01) cannot run without a DO dev key; the first
  prod cleanup (S08), the drip (S15) and the key retirement (S39) all need the Fly login; the DO
  prod key itself is created in this step, before any of them.
- **Does not include.** Any code change. The repository is public (`gh repo view` shows
  `visibility: PUBLIC`), so secret names stay in the owner's private notes; only the machine count
  and VM size may be written into a new "Ops facts" paragraph added under "Current state" in
  `docs/llm-migration-plan.md`.
- **Definition of done.**
  - `flyctl auth whoami` works; secret names recorded in the owner's private notes, machine count
    and VM size written into the new "Ops facts" paragraph under "Current state" in
    `docs/llm-migration-plan.md`.
  - The DO key has exactly one name everywhere: `DO_INFERENCE_TOKEN` (Q3). The dev value is in
    `.env.local` as `DO_INFERENCE_TOKEN=...`. The prod value is set as a Fly secret:
    `flyctl secrets set DO_INFERENCE_TOKEN=<prod-key-value> -a fountainpencompanion`. Setting a
    secret restarts the 6 web machines (`fly.toml:46` `min_machines_running = 6`) and every machine
    in the `worker` process group (count unverified until `flyctl machine list` runs in this step;
    `fly.toml:33` sets `SIDEKIQ_CONCURRENCY = "5"` on it — record the count here), so run it with
    `--stage` and release at a quiet hour, or run it directly at a quiet hour. `--stage` only
    writes the secret into the app config; it is applied by the next `flyctl deploy` (CI's master
    deploy) or by an explicit `flyctl secrets deploy -a fountainpencompanion`. The step is done only
    when `flyctl secrets list -a fountainpencompanion` shows a `DO_INFERENCE_TOKEN` digest AND a
    deploy has happened since staging it — otherwise the drip (S15) hits a missing key at call
    time. It must land before S15 (the drip's first real prod DigitalOcean call). S11 can merge
    without it: a `config/llm.yml` entry naming the env var and a lazily read `ENV.fetch(..., nil)`
    (S04) cannot fail at merge or boot time — if the secret is missing, the first drip run fails at
    call time.
  - Backup/PITR status and retention window of the prod database recorded (private notes).
- **Implementation notes.**
  - `flyctl auth login`, then `flyctl secrets list -a fountainpencompanion` (names and digests
    only) and `flyctl status -a fountainpencompanion` / `flyctl machine list` for the worker count
    (`fly.toml:46` sets web `min_machines_running = 6`; `fly.toml:36-76` defines the `worker`
    process group with `SIDEKIQ_CONCURRENCY = "5"` at `fly.toml:33`, but the number of worker
    MACHINES is not in fly.toml and is what this command establishes).
  - The DO backup/PITR setting is read in the DO control panel (Databases -> cluster -> Backups);
    the read-only SQL role cannot see it.
  - Disk: `docker system df` on the host; the dev DB is already a 12 GB stale prod copy.
  - Do not create a second, differently-named DO key for prod vs dev — one name (`DO_INFERENCE_TOKEN`)
    is used in both `.env.local` (dev value) and Fly secrets (prod value); config code (S04 on)
    reads the same env var name in every environment, only the underlying secret store differs.
- **Decisions applied.** Q3 (single key name `DO_INFERENCE_TOKEN`, dev value in `.env.local`, prod
  value as a Fly secret, created here rather than later); Q32 (the prod key is created early because
  the drip, not the backfill, is the first prod DigitalOcean traffic).

### S01-do-spike — DigitalOcean compatibility spike with a throwaway script; findings recorded in the plan; picks the pen agents' starting DO model

- **Goal.** Learn whether RubyLLM 1.16 works against `https://inference.do-ai.run/v1` before any
  config code is designed, and pick the pen agents' STARTING DIGITALOCEAN CHAT MODEL. Under Q32 the
  pen agents run on DigitalOcean from their first line of code — there is no `gpt-4.1`/constant
  starting point and no later pen cutover — so this spike is also the model selection: run
  checklist items (2) forced tool choice, (3) replay of a transcript against the same provider,
  (4) strict tool schema and (13) reasoning blocks against two or three P3 chat candidates (one
  Claude model, one or two open models). The owner's gate is items (2) forced tool choice and (3)
  transcript replay (Q32: "whichever of two or three candidates handles forced tool choice and
  transcript replay cleanly"); among the candidates that clear that gate, pick the cheapest, using
  (4) and (13) — no reasoning text leaking into `.content` — as implementer tiebreaks ("Resolved
  without asking"), not as owner-set disqualifiers. Vision is not required for the pen agents (only
  YoutubeSummarizer, ReviewApprover and ReviewFinder need it, and all three stay ink-side). Record the pick — catalog id,
  the exact response `model` string, price in/out per M tokens — in `docs/pen-clustering-plan.md`'s
  decisions (decision 6 now reads "born on the DO model picked by the spike") and in this roadmap's
  S11 (`pen-agent-decide`) text, which is the step that turns the pick into a `config/llm.yml` entry.
  A ~40-line `rails runner` script (never committed) builds `RubyLLM.context` with `openai_api_base`,
  the DO key and `openai_use_system_role = true`, calls
  `chat(model:, provider: :openai, assume_model_exists: true)` (the DIGEST confirms
  `assume_model_exists` raises without `provider:`), and exercises a real forced-tool-choice agent
  (InkClusterer on a dev micro cluster, or SpamClassifier; GoogleSearchSummarizer uses plain `ask`
  and would not test the `ask!` contract) with `ruby_llm_context` **and** `build_chat` overridden
  on the agent instance. Both are private; override them with `define_singleton_method`, because
  `build_chat` at app/agents/concerns/ruby_llm_agent.rb:86 hard-codes
  `ruby_llm_context.chat(model: model_id)` without `provider:`, so `Models.find` raises
  `RubyLLM::ModelNotFoundError` for any DO id before an HTTP request is made (ruby_llm-1.16.0
  lib/ruby_llm/chat.rb:12-21). This is exactly the line S04 must change. Do **not** call
  `perform`: it returns early for any assigned or ignored cluster (`already_resolved?`,
  ink_clusterer.rb:279-292; prod has 0 unassigned micro clusters with inks, so the dev copy has
  almost none), and after `ask!` it calls `waiting_for_approval!` and `schedule_follow_up!`, which
  enqueues a real `CheckInkClustering::*` job into the shared dev Redis that the dev `sidekiq`
  container would run against OpenAI. Instead: `require "sidekiq/testing"; Sidekiq::Testing.fake!`
  at the top of the script, then inside `ActiveRecord::Base.transaction do ... raise
ActiveRecord::Rollback end` pick an assigned cluster with inks, `update_columns(macro_cluster_id:
nil, ignored: false)`, call `agent.send(:ask!, agent.send(:user_prompt))` and read
  `agent.agent_log.extra_data`. The same applies to SpamClassifier, whose tools `update` the user
  (spam_classifier.rb:17,34). The only PR is a docs-only "Spike findings" section in
  `docs/llm-migration-plan.md` (plus the pen-model pick recorded in `docs/pen-clustering-plan.md`
  and quoted into S11 as described above).
- **Checklist the script must answer.** (1) system prompt accepted as role `developer` vs
  `system`; (2) `tool_choice: required` honoured, `finish_reason` `tool_calls`, and whether the
  pinned "4 requests then `DecisionNotReachedError`" contract holds; (3) tool-call ids returned and
  accepted on replay of a transcript in the app's stored format, including one real prod-shaped
  transcript with OpenAI ids (this is what `RunFailedClusterJobs` and Sidekiq retries will replay
  against DO after a flip), and the reverse direction (a DO-issued transcript replayed against
  OpenAI, which is what a flip-back does); (4) `strict: true` / `additionalProperties: false`
  inside tool parameters accepted; (5) parallel tool calls (compatibility only: prod transcripts
  never contained one); (6) a remote image URL fetched by a vision-capable model (the thumbnail that
  YoutubeSummarizer, ReviewApprover at review_approver.rb:126 and ReviewFinder at
  review_finder.rb:108 attach; the decision "keep the thumbnail" depends on it, otherwise base64
  upload is forced); (7) `/v1/embeddings` for the four 1024-dim candidates with Array input and
  without `dimensions:`, and whether `data` comes back in input order (batch of three distinct
  strings compared with single calls); (8) whether any prompt-cache fields appear in usage;
  (9) capability checks for assumed models (`with_tools`, vision) do not raise or warn; (10) every
  named chat and embedding candidate exists in the catalog with its exact id, price and vision
  flag: the P3 list (Claude Haiku 4.5, DeepSeek V4 Pro, Kimi K2.6, Qwen3.8-Max, GLM-5.3, Claude
  Sonnet 5) and the P2 list (BGE-M3, E5-Large-v2, Qwen3-Embedding-0.6B, GTE-large-en-v1.5), plus
  the exact `model` string DO returns in chat and embedding responses (this, not the catalog id,
  is what `usage["model"]` stores and what the hand-maintained price table the harness (S20) uses
  must be keyed on — there is no in-app usage-cost change); (11) rate
  limits / concurrency headers and how a 429 interacts with RubyLLM's built-in 3x retry; (12) the
  completion response carries a non-empty `model` field (ruby_llm_agent.rb:130 stores
  `message.model_id`; blank means the harness's cost attribution (S20) breaks, since there is no
  in-app usage-cost change); (13) for the open-model
  candidates, whether `reasoning_content`/`<think>` blocks appear, whether RubyLLM strips them from
  `.content` (openai/chat.rb:180-181, 226-229) and whether a transcript containing them replays
  (openai/chat.rb:174 echoes `reasoning_content`); (14) the exact HTTP status and response body DO
  returns for a non-existent model id, for both a chat call and a `/v1/embeddings` call — S05
  (`model-not-found-alert`) matches its alert on this exact text, because ruby_llm-1.16.0 maps only
  400/401/402/403/429/500/502-504/529 to named error classes
  (lib/ruby_llm/error_middleware.rb:34-68; the final `else` is at :65 and the bare
  `raise Error.new(...)` fallback at :66) and any other status comes back as a bare
  `RubyLLM::Error`, while providers/openai/chat.rb:54-82 raises `RubyLLM::Error` whenever
  `data.error.message` is present even on an HTTP 200 — so the exact status/body pairing DO uses for
  an unknown model is not guessable from the gem source and must be observed directly (call chat and
  embeddings with a deliberately misspelled model id and print the raw response). Try two or three
  catalog models (one Claude, one open model) for items (2)-(4) and (13) to make the model pick.
- **Depends on.** S00 (DO dev key).
- **Why here.** Largest blast radius per hour spent: any failure in (2), (3) or (6) changes the
  design of S04 and the `ask!` contract both ink and pen agents rely on. Doing it before the config
  layer means the concern is changed once. It is also the only place the pen agents' starting model
  can be picked, because Q32 removes the separate "start pens on gpt-4.1, migrate later" path.
- **Does not include.** Any app code, any config layer, any prod call.
- **Definition of done.**
  - Findings table (item, result, consequence) merged into `docs/llm-migration-plan.md`; run
    `docker-compose exec -T app yarn prettier-fix` before pushing (CI's `prettier --check .` covers
    `docs/*.md`).
  - Catalog table (model id, response `model` string, price in/out per M tokens, vision yes/no)
    recorded; this feeds the hand-maintained, bench-only price table the harness builds in S20 —
    there is no in-app usage-cost change (Q5).
  - Any forced follow-up (base64 images, system-role flag, tool-schema stripping, retry cap) listed
    as an input to S04.
  - The pen agents' starting DO model is picked and recorded: catalog id, response `model` string,
    price in/out, and the one-line reason (cheapest candidate passing the Q32 gate, items (2) and
    (3), with (4) and (13) as tiebreaks) — written into `docs/pen-clustering-plan.md` decision 6 and
    into S11's text as the `config/llm.yml` model for `PenVariantClusterer`.
  - The pen plan's "Cost reference" table is re-priced with the picked model's DO price in/out
    recorded here — the four scope rows (inflow, backlog ≥2 pens, singletons with known brand,
    everything) replace their gpt-4.1-class and Haiku-4.5-class reference columns with the picked
    model's real per-run cost.
  - Item (14)'s exact status/body pairing (chat and embeddings) is recorded verbatim (not
    paraphrased) so S05 can match on it literally.
- **Implementation notes.**
  - The scratchpad is not mounted into the `app` container (docker-compose.yml:28-30 mounts only
    `.:/app` and `gem_cache`), so run the script on stdin: `docker-compose exec -T app bundle exec
rails runner - < spike.rb`, or place it under the gitignored `tmp/` (.gitignore:12) and run
    `rails runner tmp/spike.rb`.
  - Neither `DO_MODEL` nor `DO_INFERENCE_TOKEN` exists in the container by default: `.env` declares
    only the `GOOGLE_*`/`HCAPTCHA_*`/`OPEN_AI_*`/`SERPER_API_KEY` placeholders and `.env.local`
    carries `HCAPTCHA_*`, `OPEN_AI_DEV_TOKEN`, `GOOGLE_*`, `OPEN_ROUTER_DEV_TOKEN`,
    `SERPER_API_KEY` and `PRODUCTION_READONLY_DATABASE_URL` — `ENV.fetch` with no default raises
    `KeyError`, which would abort the run before any DO call. Pass the candidate id per run rather
    than storing it: `docker-compose exec -T -e DO_MODEL=<catalog-id> app bundle exec rails runner -
< spike.rb` (or hard-code the id in the throwaway script). After S00 adds `DO_INFERENCE_TOKEN`
    to `.env.local`, recreate the container (`docker-compose up -d app`) — `env_file`
    (docker-compose.yml:19-23) is read at container start, so an already-running container does not
    see the new variable.
  - Skeleton (verified against ruby_llm-1.16.0 and ruby_llm_agent.rb:85-96):
    `require "sidekiq/testing"; Sidekiq::Testing.fake!; ctx = RubyLLM.context { |c| c.openai_api_key = ENV.fetch("DO_INFERENCE_TOKEN"); c.openai_api_base = "https://inference.do-ai.run/v1"; c.openai_use_system_role = true }; mc = MicroCluster.where.not(macro_cluster_id: nil).joins(:collected_inks).first; agent = InkClusterer.new(mc.id); agent.define_singleton_method(:ruby_llm_context) { ctx }; agent.define_singleton_method(:build_chat) { c = ctx.chat(model: ENV.fetch("DO_MODEL"), provider: :openai, assume_model_exists: true); c.with_instructions(send(:system_directive)); send(:tools).each { |t| c.with_tool(t) }; send(:restore_transcript, c); send(:register_callbacks, c); c }; ActiveRecord::Base.transaction { mc.update_columns(macro_cluster_id: nil, ignored: false); agent.send(:ask!, agent.send(:user_prompt)); pp agent.agent_log.extra_data, agent.agent_log.usage; raise ActiveRecord::Rollback }`.
    Use the `DO_INFERENCE_TOKEN` name from S00 (dev value in `.env.local`), not a differently-named
    variable. `ink_similarity_search` still calls OpenAI embeddings with `OPEN_AI_DEV_TOKEN` and
    `search_web` calls Serper plus GoogleSearchSummarizer on OpenAI; both are fine for the spike but
    are not DO traffic.
  - Item (3) replay source: the dev DB holds 44,087 prod agent_logs, so a real OpenAI-id transcript
    is `AgentLog.where(name: "InkClusterer").where("jsonb_array_length(transcript) > 8").order(id: :desc).first`;
    build `InkClusterer.new(mc_id, agent_log_id: log.id)` with the singleton overrides, call
    `agent.send(:chat)` (runs `restore_transcript`, ruby_llm_agent.rb:173-188) and then
    `agent.send(:chat).ask("Summarise your decision")` inside a rolled-back transaction; check that
    DO accepts the `call_...` ids in `tool_calls`/`tool_call_id` (openai/tools.rb:54-73
    re-serialises them). For the reverse direction, feed a DO-produced transcript to a context
    pointed at OpenAI.
  - Item (6): `ctx.chat(model: "<vision-id>", provider: :openai, assume_model_exists: true).ask("Describe this thumbnail", with: "https://i.ytimg.com/vi/<video-id>/hqdefault.jpg")`;
    RubyLLM sends the URL verbatim (openai/media.rb:52-59). Only needed for the ink-side vision
    candidates, not for the pen model pick.
  - Item (7): `ctx.embed(["Lamy Safari Petrol", "Pilot Custom 74"], model: "<do-id>", provider: :openai, assume_model_exists: true).vectors.map(&:length)`
    must return `[1024, 1024]`; also record `response.model` and `response.input_tokens`. Do not
    pass `dimensions:`.
  - Items (8)/(11): `response = agent.send(:chat).messages.last; response.raw.body.dig("usage", "prompt_tokens_details")`
    and `response.raw.headers.select { |k, _| k =~ /ratelimit|retry-after/i }`; to see raw 429s set
    `c.max_retries = 0` in the context (connection.rb:105-114 retries POST 3x by default), then
    repeat with the default to confirm the retry masks them.
  - Item (14): call with a deliberately wrong model id, e.g.
    `ctx.chat(model: "does-not-exist", provider: :openai, assume_model_exists: true).ask("hi")`
    rescued in a `begin/rescue RubyLLM::Error => e; pp e.class, e.message, e.response&.status, e.response&.body; end`
    block, and the equivalent for `ctx.embed(["x"], model: "does-not-exist", provider: :openai, assume_model_exists: true)`;
    record both raw bodies verbatim in the findings table — do not paraphrase the message text, S05
    matches on it literally.
  - Item (13), model pick: run the same forced-tool-choice InkClusterer/SpamClassifier exercise
    against each P3 candidate under test and inspect `agent.agent_log.transcript` and the raw
    `message.content` for leaked `<think>`/`reasoning_content` text; a candidate that leaks
    reasoning into `.content` loses the tiebreak against an equally compliant candidate that does
    not (an implementer tiebreak, not an owner-set disqualifier — the Q32 gate is items (2) and (3)).
  - Gem facts to carry into S04: `Chat.new` raises ArgumentError when `assume_model_exists` is set
    without `provider:` (chat.rb:13-15); `openai_api_base` and `openai_use_system_role` are provider
    config options (providers/openai.rb:17-18, 41-44); `request_timeout` default 300 and
    `max_retries` default 3 (configuration.rb:55-56); the system prompt goes out as role
    `developer` unless `openai_use_system_role` (`format_role` at providers/openai/chat.rb:150-157,
    the role ternary itself at :153). Docker must be
    up to read the gem: `docker-compose exec -T app bundle show ruby_llm`.
  - Size stays S, but running the model-pick comparison across two or three candidates for items
    (2), (3), (4) and (13) may push the work into a second day; that is expected and is not a scope
    change.
- **Decisions applied.** Q32 (the spike also picks the pen agents' starting DigitalOcean chat model,
  because pen agents are DO agents from birth with no later cutover); Q33 (checklist item (14):
  record the exact provider error for an unknown model id, verbatim, for S05 to match on); Q5 (no
  in-app usage-cost fields; the catalog/price table recorded here feeds only the bench-only
  hand-maintained price table the harness builds in S20 — there is no in-app pricing map anywhere
  else in the roadmap).

### S02-pen-retrieval-check — Pen retrieval sanity check and `embedding_search` latency on the existing dev prod copy

- **Goal.** Answer pen decision 7's first question, "does `Pens::Model.embedding_search` return the
  correct model and variant in its top 20 for leave-one-out cases", before any tool or agent code
  exists. The sampling/hide/metric logic lives in `lib/bench/pen_retrieval_check.rb` (the location
  the migration plan fixes at docs/llm-migration-plan.md:190, P1 "Runner (`lib/bench/`, rake task,
  not RSpec)"; `lib/` is not autoloaded, so the rake
  task `bench:pen_retrieval` in `lib/tasks/bench.rake` does
  `require Rails.root.join("lib/bench/pen_retrieval_check")`), with its spec in `spec/lib/bench/`.
  It runs against the dev DB, which is already a 12 GB stale prod copy (check
  `Pens::MicroCluster.count` is in the six figures before trusting any number: prod is 122,148, and
  the dev copy is an older snapshot — about 196,977 `pen_embeddings` against prod's 210,534, so
  expect roughly 113-118k. Anything under ~10k means a fresh `db:setup`, not the prod copy, and will
  silently yield a meaningless result set). It samples ~200 human-assigned `Pens::MicroCluster` rows
  stratified by singleton/multi-pen and known/unknown brand, restricted to clusters with at least
  one collected pen whose `pen_embeddings.embedding` is NOT NULL (this excludes the empty assigned
  clusters and the pens without embedding rows: prod 453 / 1,260, and the 5 variants with no micro
  clusters at all — a subset of the 25 empty variants Q8 deletes in S08; the dev copy is older, so
  re-count both numbers locally on the same definitions and record the dev figures with the table; the empty variants that still carry embeddings stay in the candidate pool as small
  noise, and the check is repeated on the cleaned bench DB in S22). For stratification only,
  "known" = definition C of prod-data-check.md §11 (`simplified_brand` in the Simplifier-simplified
  `pens_brands.name ∪ pens_models.brand`, the plan's own definition); the tool's own check is the
  Q18 definition (S10); stratification here keeps definition C.
  Per case, inside a rolled-back transaction: NULL `pens_model_variant_id`, NULL the variant's own
  `pen_embeddings.embedding` when the variant holds only this cluster, build the query from the
  cluster's most common pen name, call `embedding_search`, and report recall@1/5/20 both as
  "top 20 by distance" (what the agent will see) and "everything under 0.6". Metrics: model recall@k
  over all cases (model id = `data.owner.pen_model.id`; there is no `.model` accessor); variant
  recall@k over assign cases only (lonely-variant cases are "create" and report model recall only,
  because their variant is hidden); a variant counts as retrieved if its id is in
  `data.model_variants` **or** its model was hit directly (tier 1, `data.owner.is_a?(Pens::Model)`,
  for which `model_variants == []` per app/models/pens/model.rb:83-93), because the S10 tool loads
  `model.model_variants` for tier-1 hits. Report the assign/create split. Time each call.
- **Depends on.** Nothing (dev DB and the existing OpenAI dev key; ~200 embedding calls).
- **Why here.** Cheapest high-uncertainty probe; no chat tokens. Decides whether S09/S10 wrap the
  search as is or must fix retrieval first. Its logic is reused in S23.
- **Does not include.** Candidate embedding models, the bench DB, any prompt.
- **Definition of done.**
  - Recall table and per-call latency (expected 0.5-2 s; up to 2,400 rows transferred) added to
    `docs/pen-clustering-plan.md`, with the leakage caveat (variant names, tier 2, and for models
    with a single variant also model names, tier 1, were derived from the held-out pens by
    `Pens::UpdateModelVariant`/`Pens::UpdateModel`; both inflate recall) and the pgvector
    0.8.2-vs-0.7.4 note. Q12's re-derivation of the held-out variant's (and single-variant model's)
    name and embedding is deliberately NOT done here — this is a cheap pre-tool probe, so its recall
    numbers are inflated and are not directly comparable with S21/S23, which add the re-derivation
    inside the same rolled-back transaction. Run `docker-compose exec -T app yarn prettier-fix` before pushing (CI
    checks `docs/*.md`, `lib/**/*.rb` and `lib/tasks/*.rake`).
  - Class and rake task committed, Prettier-clean, with a spec for the sampling/hide step.
  - Explicit verdict written down against the threshold under this roadmap's "Resolved without
    asking" list (section 5; the S02 threshold entry is the one whose v1 text read "retrieval work
    needed in S06" and must read S09 in v2): "wrap as
    is" if model recall@20 >= 0.9 over assign cases and variant recall@20 >= 0.8 over assign cases
    (top-20-by-distance view); otherwise "retrieval work needed in S09" with the failing cell named.
- **Implementation notes.**
  - Sampling cells (prod, 2026-09-12): assign/multi 10,038, assign/singleton 787, create/multi
    4,260, create/singleton 205 over the 15,290 assigned non-ignored clusters with pens
    (prod-data-check.md §14); expected action =
    `Pens::MicroCluster.where(pens_model_variant_id: v.id).count > 1 ? :assign : :create`. Sample
    ~50 per cell (the 205-cell will be thin).
  - Hide step, callback-safe and safe without `Sidekiq::Testing.fake!`:
    `mc.update_columns(pens_model_variant_id: nil)` (`Pens::MicroCluster` has no callbacks) and, for
    lonely variants, `PenEmbedding.where(owner_type: "Pens::ModelVariant", owner_id: v.id).update_all(embedding: nil)`
    (`PenEmbedding#after_save` enqueues `FetchEmbedding` only when `content` changed,
    app/models/pen_embedding.rb:16-20, and `content` is never touched). Query text = the cluster's
    most common `CollectedPen#pen_name` (collected_pen.rb:105-108, the string used as embedding
    content). Wrap each case in `ActiveRecord::Base.transaction { ...; raise ActiveRecord::Rollback }`;
    `Pens::Model.embedding_search` runs on the same connection so it sees the NULLs.
  - Result shape (app/models/pens/model.rb:73-96): array of OpenStruct sorted by `.distance`;
    `Pens::Model#pen_model` returns self (:114-116); `data.model_variants` is `[]` for tier-1 hits;
    "top 20" = `results.first(20)`, "under 0.6" = the whole array (the 0.6 filter is already applied
    per tier in Ruby, :42, :52, :71). Time with `Benchmark.realtime`; expect 0.5-2 s.
  - Spec: stub `allow(EmbeddingsClient).to receive(:new).and_return(double(fetch: Array.new(1536, 0.0)))`
    or `allow(Pens::Model).to receive(:embedding_search).and_return([...])` (pattern
    spec/agents/tools/ink_similarity_search_tool_spec.rb:41); build rows with factories
    `pens_brand -> pens_model -> pens_model_micro_cluster -> pens_model_variant -> pens_micro_cluster -> collected_pen`
    (set `pens_micro_cluster:` explicitly; `create(:collected_pen)` does not run L0) as in
    spec/workers/pens/update_model_spec.rb; assert the hide step NULLs the variant embedding only
    for lonely variants and the sampler never returns a cluster with zero pens. Omit
    `WebMock.reset!`.
  - Environment: the dev `postgres` container must be up and the dev copy must have the two HNSW
    indexes (`SELECT indexname FROM pg_indexes WHERE indexdef LIKE '%hnsw%'`), otherwise latency
    numbers are meaningless; `SET hnsw.ef_search = 1000` is issued by `embedding_search` itself
    (:33) and persists for the session.
- **Decisions applied.** None baked in directly — this step is unchanged from v1 apart from
  renumbered cross-references. It references Q18 (pen KnownBrand definition), which S10 implements;
  its stratification keeps the plan's own definition C instead.

### S03-stale-docs-fix — Fix stale developer guidance

- **Goal.** A weaker implementer copying from the docs would write wrong code: CLAUDE.md says every
  tool must override `def name`, but `config/initializers/ruby_llm.rb:8-22` demodulizes tool names
  and every existing tool relies on it (only anonymous classes must override); CLAUDE.md:167 still
  says "Some older agents still use raix and are being migrated" although `grep raix Gemfile
Gemfile.lock` is empty and the migration plan records "No raix left"; `spec/agents/README.md`
  still describes raix (:598) and `Faraday::ServerError` (:220, :537) while specs use RubyLLM and
  `RubyLLM::ServerError` (13 occurrences in spec/ across 12 files;
  spec/agents/check_ink_clustering/human_spec.rb has two. `Faraday::ServerError` appears only in
  spec/operations/safe_http_spec.rb). Fix all three, keep the CLAUDE.md agent_log pattern text
  (lines 215-232, still accurate), and record the spec conventions the pen work will use in
  spec/agents/README.md.
- **Depends on.** Nothing.
- **Why here.** Before the first tool PR (S10-pen-tools) so the templates are right (S10 depends on
  it).
- **Does not include.** Code changes. Not in the PR: updating the owner's local memory note
  `feedback_code_style.md` (outside the repo; CI cannot test it) to say `def name` is optional,
  required only for anonymous classes (where `self.class.name` is nil and the initializer patch
  raises NoMethodError, see spec/agents/concerns/ruby_llm_agent_spec.rb:40) or when a different name
  is wanted (app/agents/tools/ink_web_search_tool.rb:5 `search_web`).
- **Definition of done.** CLAUDE.md corrected (the `def name` comment at :188, the "Always override
  `def name`" bullet at :210, the :167 raix sentence); spec/agents/README.md corrected (raix at
  :598, `Faraday::ServerError` at :220 and :537) and extended with a new
  `## Conventions for new agent specs` section holding the six bullets below; Prettier-clean.
- **Implementation notes.**
  - Tool-naming rule to write into CLAUDE.md: the initializer derives the tool name as the
    demodulized, snake_cased class name minus a trailing `_tool` (`Tools::PenSimilaritySearchTool ->
pen_similarity_search`, `PenVariantClusterer::AssignToVariant -> assign_to_variant`); override
    `def name` only for anonymous classes or to pick a different name. Two tools with the same
    demodulized class name in one chat overwrite each other (ruby_llm-1.16.0 chat.rb:61), and
    InkClusterer's `BaseTool` uses `name` as the recorded action string (app/agents/ink_clusterer.rb:24),
    so renaming a decision tool changes `extra_data["action"]`.
  - Spec conventions to record (all verified in spec/): the WebMock stub URL is the literal
    `https://api.openai.com/v1/chat/completions` with
    `choices[0].message.tool_calls[0].function = {name, arguments: JSON string}` and
    `finish_reason: "tool_calls"`; 500 -> `RubyLLM::ServerError`, malformed JSON ->
    `Faraday::ParsingError`; jobs asserted with `Worker.jobs.size` / `.last["args"]`, never by
    mocking `perform_async`; do not copy the `before(:each) { WebMock.reset! }` that several agent
    specs still carry; `create(:collected_pen)` does not run L0 clustering, so set
    `pens_micro_cluster:` explicitly; doubles for `Pens::Model.embedding_search` must be OpenStructs
    with `distance`, `owner` (`owner.pen_model`), `model_variants` (no `.model`; app/models/pens/model.rb:73-95),
    unlike the ink side, which uses RSpec `double("SearchResult", cluster:, distance:)` at
    spec/agents/tools/ink_similarity_search_tool_spec.rb:36-38 with the
    `allow(MacroCluster).to receive(:embedding_search)` stub at :40-44.
    Append these six bullets to spec/agents/README.md as a new `## Conventions for new agent specs`
    section — that file, not CLAUDE.md, is where they live.
  - Concretely: in CLAUDE.md's "Tool structure" section, edit the inline comment at CLAUDE.md:188
    from `def name = "my_tool" # Required — auto-generated name includes module prefix for inner
classes` to `def name = "my_tool" # Optional — only for anonymous classes, or to choose a
different name` (that comment IS the false claim: `config/initializers/ruby_llm.rb:11`
    demodulizes, and 25 of the 26 tool classes under app/ define no `name` at all — only
    app/agents/tools/ink_web_search_tool.rb:5, and only to pick a different name), and replace the
    bullet at CLAUDE.md:210 ("Always override `def name` — the auto-generated name includes module
    prefixes for inner classes") with the rule above. Then delete the line 167 sentence "Some older agents still use raix and are being
    migrated — do not use raix for new agents", replacing it with nothing (raix is fully gone; there
    is no migration in progress to mention). In spec/agents/README.md, delete the raix reference at
    line 598 and change `Faraday::ServerError` to `RubyLLM::ServerError` at lines 220 and 537 (grep
    the file for both strings after editing to confirm zero hits).
  - Run `docker-compose exec -T app yarn prettier-fix` (or the repo's Prettier invocation for
    Markdown, since CLAUDE.md/spec/agents/README.md are Markdown) before committing; this is a docs
    PR with no Ruby/JS changed, so `bundle exec rspec` and `yarn test` are unaffected but should still
    be run once as the final step per CLAUDE.md's own instruction.
- **Decisions applied.** None of the 39 numbered decisions bear on this step directly; it is a v1
  DIGEST finding, renumbered only (S07 → S10 in "Why here").

### S04-llm-config-chat — Per-agent chat LLM config with an injection point; key lookup fix

- **Goal.** A central config keyed by full class name with a `default` block (Q1): a `config/llm.yml`
  file read via `Rails.application.config_for(:llm)` — the repo's first `config_for` file, so quote
  any key containing `::` in YAML, and use `shared:`/`test:` per-environment sections. Gotcha:
  `config_for` deep-symbolizes EVERY key and wraps only the TOP level in
  `ActiveSupport::OrderedOptions` (railties-8.1.3.1 `lib/rails/application.rb:290-315`), so
  `config["InkClusterer"]` works but the entry it returns is a plain Hash with SYMBOL keys —
  `entry[:model]`, never `entry["model"]` or `entry.model`. `LlmConfig.for` must therefore WRAP the
  entry (`ActiveSupport::OrderedOptions.new.update(hash)`, or a Struct) before returning it, which
  is what makes `entry.api_key_env` / `LlmConfig.for("InkClusterer").model` below legal. A per-class
  entry is deep-merged ON TOP of `default` (`default.merge(entry)`), so a seed entry needs only
  `model:`; `default` supplies `provider`, `api_base`, `api_key_env`, `assume_model_exists` and the
  provider options. Each entry carries `provider` (`openai` for
  BOTH real OpenAI and DigitalOcean entries — `assume_model_exists` requires it), `model`, `api_base`,
  `api_key_env` (an ENV VAR NAME, never a literal value), `assume_model_exists`, and the provider
  options the spike (S01) settled (`openai_use_system_role` set per-entry on the DO default block —
  never in `config/initializers/ruby_llm.rb`, so the OpenAI-default test suite keeps sending role
  `developer` with no stub changes — plus `request_timeout` and `max_retries`). The four
  `CheckInkClustering::*` subclasses share ONE entry named `CheckInkClustering`. `PenAndInkSuggester`'s
  patron tier is a SECOND plain entry, `PenAndInkSuggester.premium`, and the agent picks the entry
  name at runtime (Q1). The nine existing `MODEL_ID` constants become this file's `default`-per-class
  entries (OpenAI, today's model ids — no behaviour change on merge).
  - Mechanism: `RubyLlmAgent#llm_config_key` is a new private method that defaults to
    `self.class.name`; `CheckInkClustering::Base` overrides it to return the literal string
    `"CheckInkClustering"`; `PenAndInkSuggester` overrides it to return `"PenAndInkSuggester.premium"`
    when `premium?` and `"PenAndInkSuggester"` otherwise — this REPLACES today's
    `PenAndInkSuggester#model_id` at pen_and_ink_suggester.rb:78-80, which currently does
    `premium? ? "gpt-4.1" : "gpt-4.1-mini"` directly. S38's pen checkers will later override
    `llm_config_key` to `"CheckPenClustering"` the same way; this step does not create that class, only
    the mechanism it will use.
  - `RubyLlmAgent#model_id` and `#ruby_llm_context` stay PRIVATE methods on the concern (no agent
    subclass defines them any more except through `llm_config_key`); they resolve through a new
    `LlmConfig` lookup: `LlmConfig.for(llm_config_key)` returns `default` deep-merged with the entry
    for that key, and `default` alone when the key has no entry OR when `self.class.name` is `nil`
    (anonymous classes, e.g. the ones built inline at spec/agents/concerns/ruby_llm_agent_spec.rb:4-14
    and :16-... via `Class.new do include RubyLlmAgent ... end`). `LlmConfig` lives at
    `app/lib/llm_config.rb` (the same autoloaded directory as `EmbeddingsClient`), its spec at
    `spec/lib/llm_config_spec.rb`; `llm_config_key` is a private method on `RubyLlmAgent` and is
    exercised from `spec/agents/concerns/ruby_llm_agent_spec.rb`.
  - `build_chat` (ruby_llm_agent.rb:86) is rewritten to pass `provider:` and `assume_model_exists:`
    from the resolved entry into `ruby_llm_context`/`chat(model:)`, in addition to `model:`. The YAML
    key names are not the RubyLLM option names: `ruby_llm_context` becomes
    `RubyLLM.context { |c| c.openai_api_key = access_token; c.openai_api_base = entry[:api_base];
c.openai_use_system_role = entry[:openai_use_system_role] unless entry[:openai_use_system_role].nil?;
c.request_timeout = entry[:request_timeout] if entry[:request_timeout];
c.max_retries = entry[:max_retries] if entry[:max_retries] }` — the YAML key `api_base` maps to
    the provider option `openai_api_base` (ruby_llm-1.16.0 providers/openai.rb:38-44 registers
    `openai_api_base` and `openai_use_system_role`; configuration.rb:55-56 declares `request_timeout`
    and `max_retries`). `RubyLLM::Configuration` defines explicit setters only, so `config.api_base =`
    raises NoMethodError; today's code (ruby_llm_agent.rb:95) sets only `config.openai_api_key`.
  - The injection point (Q2) is a scoped, thread-safe override: `LlmConfig.with_override("InkClusterer"
=> { model:, provider:, api_base:, api_key_env: }) { ... }`, stored per-thread/fiber in
    `ActiveSupport::IsolatedExecutionState` (safe under concurrent Sidekiq jobs because the state is
    per-thread AND `with_override` restores the previous value in an `ensure` block; Sidekiq reuses
    processor threads across jobs, so the `ensure` — not thread ownership — is what prevents
    leakage). It is consulted by `model_id`,
    `ruby_llm_context` and `build_chat`, applies ONLY to the named class (a sub-agent spawned inside a
    tool — e.g. `GoogleSearchSummarizer` from app/agents/tools/ink_web_search_tool.rb:17 — keeps its
    OWN config unless the caller names it separately; the bench's Q14 policy of running sub-agents on
    the same candidate model does this by naming both classes explicitly), and must be active before
    the FIRST `chat` call (both `@chat ||=` at ruby_llm_agent.rb:13 and `@ruby_llm_context ||=` at :95
    memoise, so the override has to be set up before either is referenced — i.e. before `ask`/`ask!`
    is first called on that instance). ONE rule decides what an override applies to: the override map
    is keyed by `self.class.name` (the agent CLASS), not by `llm_config_key`. Resolution is
    `entry = LlmConfig.for(llm_config_key)` and then
    `entry.merge(override_for(self.class.name) || {})`, so an override keyed to
    `"PenAndInkSuggester"` applies to BOTH of its entries (the plain one and `.premium`).
    `LlmConfig.with_override(hash) { ... }` is block-only and restores the prior value in an
    `ensure`; there is no `clear_override!`, and specs wrap the example body in the block.
  - Key env var lookup (Q3): keep `OPEN_AI_TOKEN` and `OPEN_AI_EMBEDDINGS` exactly as today; add ONE
    new name, `DO_INFERENCE_TOKEN` (the name S00 already created as a Fly secret and put in
    `.env.local`). DELETE the derived `OPEN_AI_<CLASS>_TOKEN` scheme entirely: remove
    `#agent_token_env_var` (ruby_llm_agent.rb:106-108) and the `Rails.env.development?` branch inside
    `#access_token` (ruby_llm_agent.rb:98-104). The two misnamed env vars,
    `OPEN_AI_PEN_AND_INK_SUGGESTION` and `OPEN_AI_SPAM_CLASSIFIER`, DISAPPEAR — no agent ever reads
    them again. `access_token` becomes `ENV.fetch(entry.api_key_env, nil)` where `entry.api_key_env` is
    whatever the resolved config entry names (`OPEN_AI_TOKEN` for every agent's `default` block until
    that agent's own cutover; `DO_INFERENCE_TOKEN` only for entries S01/S11 add that point at DO).
    Nothing needs to be set on Fly for the OpenAI names (they already exist); `DO_INFERENCE_TOKEN` on
    Fly is S00's job, already done before this PR merges. In `.env.local`: rename `OPEN_AI_DEV_TOKEN`
    to `OPEN_AI_TOKEN` — BUT also keep a copy under the OLD name `OPEN_AI_DEV_TOKEN` until S18 lands,
    because `EmbeddingsClient#access_token` (app/lib/embeddings_client.rb:29) is a SEPARATE class not
    touched by this step and still reads `OPEN_AI_DEV_TOKEN` in development until S18 rewrites it. So
    after this PR, `.env.local` has BOTH `OPEN_AI_TOKEN=<key>` and `OPEN_AI_DEV_TOKEN=<same key>` for a
    while; delete `OPEN_AI_DEV_TOKEN` from `.env.local` only in S18's PR, never in this one.
  - Retry budget (Q4, DEFERRED): this step makes NO retry-budget change at all. Do not touch
    `max_retries` beyond whatever ships as a Ruby default in the config schema (the config format
    allows a `max_retries` key per entry per the spike, but leave every entry unset / at the gem's
    default 3 for now); do not add `sidekiq_options retry:` to `RunAgent` or `RunInkClustererAgent`; do
    not touch `config/honeybadger.yml`. `RunPenClustererAgent` is the ONE decided exception and ships
    its `retry: 2` in S13-pen-workers, not here.
  - Test environment: the `test:` section of `config/llm.yml` resolves EVERY class — pen agents
    included — to `https://api.openai.com/v1` with TODAY's per-agent model ids, so the literal
    `api.openai.com/v1` stubs keep working unchanged: 173 occurrences across 16 spec files, of which
    172 are `/v1/chat/completions` across 15 files (85 `stub_request`, 49 `have_requested`, the rest
    inline in helpers) plus the single `/v1/embeddings` stub in `spec/workers/fetch_embedding_spec.rb`
    (counted 2026-09-15; re-count before merging). This is why S11's `PenVariantClusterer` spec (which does not exist until S11) will stub
    the same literal URL as every other agent spec: DO entries live only under `production:` and
    `development:` (or under `shared:` with an explicit `test:` override back to the OpenAI test
    default). Point the two request-body model assertions that hard-code a literal model string
    (spec/agents/ink_clusterer_spec.rb:194 asserts `body["model"]).to eq("gpt-4.1")`;
    spec/agents/spam_classifier_spec.rb:240 asserts `eq("gpt-4.1-mini")`) at the new config accessor
    (e.g. `LlmConfig.for("InkClusterer").model`) instead of the literal string, so a future config edit
    doesn't silently desync the spec from the entry. Leave the seven `usage["model"]` assertions alone
    (pen_and_ink_suggester_spec.rb:455, web_page_summarizer_spec.rb:238,
    ink_brand_clusterer_spec.rb:499, review_finder_spec.rb:848,
    google_search_summarizer_spec.rb:295, spam_classifier_spec.rb:915,
    review_approver_spec.rb:1193): they check the STUBBED RESPONSE's `model` field, which
    ruby_llm_agent.rb:130 stores as `message.model_id`, not the requested model — unrelated to this
    change).
  - `PenAndInkSuggester#model_id` (pen_and_ink_suggester.rb:78-80) is deleted; its private `model_id`
    method disappears entirely now that `llm_config_key` plus the config lookup supplies it.
- **Depends on.** S01-do-spike (spike facts: `provider:` requirement, `openai_use_system_role`,
  `request_timeout`, image delivery). Nothing pen-side is a prerequisite of this step or of S05 — the
  pen agent (S11-pen-agent-decide) is the first CONSUMER of this file, not a dependency of it.
- **Why here.** This is the first migration code, informed by the spike. Under Q32 the pen agent
  (S11) is BORN as an entry in `config/llm.yml` pointing at the DigitalOcean model S01 picks — there
  is no `MODEL_ID = "..."` constant on `PenVariantClusterer` ever, and no later "pen cutover" PR — so
  this config layer must exist before S06-pen-groundwork's dependents reach S11. It is also the
  prerequisite for the bench runner (S20-harness-core-ink), the OpenAI baseline rerun
  (S22-bench-round-0), shadow mode (S25-shadow-code) and every later chat-model cutover PR. Ships with
  OpenAI as the default for every existing (ink-side) agent: merging this PR changes NO prod behaviour
  for any agent that already exists.
- **Does not include.** Embeddings config (that is S18-llm-config-embeddings, and it stays in the
  migration block rather than moving here — see the cross-plan note below); any DigitalOcean default
  for an existing ink agent (their entries keep pointing at OpenAI until their own flip PR); any
  rewrite of WebMock stub URLs beyond the two model-string assertions named above. No per-agent
  cross-model fallback exists — the migration plan already decided against it
  (docs/llm-migration-plan.md:91) and this step does not add one.
- **Definition of done.**
  - Specs for: config resolution (class with no entry falls back to `default`; a per-class entry wins
    over `default`; `CheckInkClustering::Assign` resolves via the shared `"CheckInkClustering"` key;
    `PenAndInkSuggester` resolves to `.premium` when `premium?` and to the plain entry otherwise);
    context construction (api_base/provider/`openai_use_system_role`/timeout/retries all come from the
    resolved entry); the injection point (`with_override` applies only inside the block, only to the
    named class, and is gone afterward — including a "does not leak to a sub-agent spawned inside a
    tool call unless that sub-agent's own class is named" case); an anonymous class
    (`Class.new { include RubyLlmAgent }`) resolves to `default`. The concern spec's `ask!` contract
    (ruby_llm_agent_spec.rb:357-372: exactly 4 requests then `DecisionNotReachedError`) is UNCHANGED —
    do not touch that behaviour.
  - Full suite green with ZERO WebMock URL-stub changes anywhere in spec/ (only the two model-string
    assertions move to the config accessor, per above).
  - spec/agents/README.md updated in the same PR: line 239's `expect(body["model"]).to eq("gpt-4.1")`
    example is rewritten to assert against the config accessor, and lines 599-601 (the per-agent model
    ids "InkClusterer uses gpt-4.1 model", "SpamClassifier uses gpt-4.1-mini", "CheckInkClustering
    agents use gpt-4.1") are rewritten to say the model comes from the class's `config/llm.yml` entry.
  - CI env block (`.github/workflows/ci.yml:16-19`) updated: delete LINE 18
    (`OPEN_AI_PEN_AND_INK_SUGGESTION: test`) and LINE 19 (`OPEN_AI_SPAM_CLASSIFIER: test`); keep line
    16 (`OPEN_AI_TOKEN: test`) and line 17 (`OPEN_AI_EMBEDDINGS: test`). Do NOT edit line 15, which is
    `DATABASE_URL` — deleting "lines 15-18" would drop the database URL and leave
    `OPEN_AI_SPAM_CLASSIFIER` behind, breaking the rspec job. No new CI
    env var is needed for `DO_INFERENCE_TOKEN` because the `test:` config section never reads it.
    `.env` placeholders (`.env:5-8`) get the same edit: delete the two misnamed lines, keep
    `OPEN_AI_TOKEN=xxx` and `OPEN_AI_EMBEDDINGS=xxx`.
  - In the dev container, an agent run (e.g. `RunAgent.perform_async("SpamClassifier", some_id)`
    against a real or WebMock-stubbed endpoint) and a `FetchEmbedding` call both succeed using only
    `.env.local` keys (which at this point holds both `OPEN_AI_TOKEN` and, temporarily,
    `OPEN_AI_DEV_TOKEN`, plus `DO_INFERENCE_TOKEN` from S00).
  - CLAUDE.md's "AI Agents (RubyLLM)" section is updated: the "Agent structure" bullet list no longer
    says an agent must implement `model_id` (private) — replace that bullet with: the agent gets its
    model/provider/api_base from a `config/llm.yml` entry keyed by `self.class.name` by default; to
    give a class a SHARED entry (several classes resolving to one config block) or a computed entry
    name (a tier), override the private `llm_config_key` method instead of `model_id`. Add one short
    paragraph: "To add a new agent's model: add an entry to `config/llm.yml` under `default:`/
    `production:`/`development:` keyed by the class name (quote the key if it contains `::`); the
    `test:` section should resolve it back to a fixed OpenAI model so specs keep stubbing
    `https://api.openai.com/v1/chat/completions`."
  - Runbook note added to docs/llm-migration-plan.md (or this roadmap): to flip one agent, edit its
    `config/llm.yml` entry in a PR and merge; to roll back, `git revert` that PR and merge (CI + deploy
    take minutes; this is the whole rollback — there is no separate secret-edit path because entries
    reference env var NAMES, not values). S24-embedding-v2-backfill, S27-embedding-read-flip,
    S31-chat-cutover-wave-1 and S37-chat-cutover-final all reuse this exact rollback mechanism.
- **Implementation notes.**
  - Copy-from list (all in app/agents/concerns/ruby_llm_agent.rb unless noted): `#model_id` :73-75,
    `#build_chat` :85-92, `#ruby_llm_context` :94-96, `#access_token` :98-104 (DELETE the
    `Rails.env.development?` branch), `#agent_token_env_var` :106-108 (DELETE entirely). Reference for
    the ERB-in-YAML pattern already used in this repo: `config/database.yml`.
  - Seed list for `config/llm.yml`'s per-class `default` entries — the nine existing `MODEL_ID`
    constants, unchanged model ids, all provider `openai`, all pointing at `OPEN_AI_TOKEN`:
    `google_search_summarizer.rb:14` (`gpt-4.1-mini`), `ink_brand_clusterer.rb:49` (`gpt-4.1`),
    `spam_classifier.rb:40` (`gpt-4.1-mini`), `youtube_summarizer.rb:4` (`gpt-4.1-mini`),
    `review_approver.rb:77` (`gpt-4.1-mini`), `web_page_summarizer.rb:4` (`gpt-4.1-mini`),
    `check_ink_clustering/base.rb:4` (`gpt-4.1`, shared by all `CheckInkClustering::*` subclasses under
    the one key `"CheckInkClustering"`), `review_finder.rb:68` (`gpt-4.1`), `ink_clusterer.rb:123`
    (`gpt-4.1`), plus `PenAndInkSuggester` as TWO entries — `PenAndInkSuggester` (`gpt-4.1-mini`) and
    `PenAndInkSuggester.premium` (`gpt-4.1`) — replacing the `premium? ? "gpt-4.1" : "gpt-4.1-mini"`
    branch at pen_and_ink_suggester.rb:78-80. Each `MODEL_ID` constant is then deleted from its class
    (the config supplies it now); this step does NOT seed `PenVariantClusterer` — that entry is added
    by S11-pen-agent-decide, which depends on this step.
  - Env plumbing checklist: `.env:5-8` (delete `OPEN_AI_PEN_AND_INK_SUGGESTION`,
    `OPEN_AI_SPAM_CLASSIFIER`; keep `OPEN_AI_TOKEN`, `OPEN_AI_EMBEDDINGS`),
    `.github/workflows/ci.yml:16-19` (delete lines 18 and 19 of the rspec job's `env:` block, keep
    16 and 17),
    `.env.local` (gitignored — rename `OPEN_AI_DEV_TOKEN` to `OPEN_AI_TOKEN`, keep a temporary alias
    `OPEN_AI_DEV_TOKEN` for `EmbeddingsClient` until S18, add nothing new here since `DO_INFERENCE_TOKEN`
    is already there from S00), Fly secrets (no change — `OPEN_AI_TOKEN`/`OPEN_AI_EMBEDDINGS` already
    exist as Fly secrets under those names; `DO_INFERENCE_TOKEN` was already set by S00).
  - Test cases to write (RSpec, likely `spec/lib/llm_config_spec.rb` or
    `spec/agents/concerns/ruby_llm_agent_spec.rb`, matching wherever `LlmConfig` and `llm_config_key`
    live): default resolution for a class with no entry; a per-class entry wins over `default`;
    `CheckInkClustering::Assign.new(...).send(:llm_config_key)` returns `"CheckInkClustering"`; tier
    lookup for `PenAndInkSuggester` (`premium?` true → `.premium` entry's model; false → base entry's
    model); an override set via `LlmConfig.with_override("InkClusterer" => {...}) { ... }` is active
    only inside the block and reset immediately after (assert the class's `model_id` before, inside,
    and after the block); an override for class A does NOT affect class B — build the case around
    `InkWebSearchTool` calling `GoogleSearchSummarizer` inside a tool call and assert the summarizer's
    own config is untouched by an `InkClusterer` override;
    `with_override("PenAndInkSuggester" => { model: "x" })` changes the model for a premium user AND
    for a non-premium user alike (the override is keyed by class, not by entry name); an entry that
    sets only `model:` still resolves `api_key_env` from `default`; the override is cleared even when
    the block raises (`expect { LlmConfig.with_override(...) { raise "boom" } }.to raise_error` then
    assert the model is back); an anonymous class
    (`Class.new { include RubyLlmAgent }`) resolves to `default`; the built `RubyLLM::Context` carries
    `api_base`/`openai_use_system_role`/`request_timeout`/`max_retries` from the resolved entry (assert
    via whatever RubyLLM exposes on the context, or via the outgoing HTTP request's base URL and
    headers in a WebMock case).
  - Anonymous test-class cleanup in spec/agents/concerns/ruby_llm_agent_spec.rb: delete
    `def agent_token_env_var = "OPEN_AI_TOKEN"` at :32 and :81 (the method no longer exists), and
    delete `def model_id = "gpt-4.1-mini"` at :29 and :78 so those classes actually exercise the
    `default` entry — which means the test-environment `default` model must be `gpt-4.1-mini` for the
    existing expectations in that file to hold.
  - No retry-budget files are touched in this step (Q4 deferred) — do not open
    app/workers/run_agent.rb, app/workers/run_ink_clusterer_agent.rb (class `RunInkClustererAgent`;
    there is no `run_ink_clustering_agent.rb`), or config/honeybadger.yml as part of this PR.
- **Decisions applied.** Q1 (YAML file, per-agent entries with shared `default`, one shared
  `CheckInkClustering` entry, `PenAndInkSuggester.premium` second entry, secrets by env var name), Q2
  (scoped thread-safe override via `ActiveSupport::IsolatedExecutionState`, reset in specs), Q3 (keep
  `OPEN_AI_TOKEN`/`OPEN_AI_EMBEDDINGS`, add `DO_INFERENCE_TOKEN`, drop the two misnamed vars), Q4
  (deferred — no retry-budget change here), Q32 (config layer built before any pen step; pen agent is
  born as a config entry in S11, not a `MODEL_ID` constant; OpenAI stays the default for every
  existing ink agent).

### S05-model-not-found-alert — Explicit alert on the provider's "model not found" error; runbook table naming a manual replacement model per agent

- **Goal.** One small PR. Every `config/llm.yml` entry can point at a model id that stops existing
  (typo, provider deprecates a model, wrong id copied from the catalog). When that happens today the
  agent just raises whatever `ruby_llm` raises and disappears into Sidekiq retries with no operator
  visibility until someone notices the review queue stalled. This step adds an EXPLICIT, immediate
  alert the moment that specific error is seen, independent of Honeybadger's normal Sidekiq-retry
  threshold, plus a runbook that tells whoever gets paged which model to switch an agent to by hand.
  - Matcher: add `LlmErrors.model_not_found?(error)` (a new file, e.g. `app/lib/llm_errors.rb`) that
    recognises the provider's "model not found" response. There are TWO shapes to match. (a) The
    LOCAL one: ruby_llm-1.16.0 `lib/ruby_llm/error.rb:25` defines
    `class ModelNotFoundError < StandardError` — NOT a subclass of `RubyLLM::Error` — raised at
    `lib/ruby_llm/models.rb:561` during registry resolution. `Chat#initialize` (chat.rb:12-20) calls
    `with_model(model_id, provider:, assume_exists: assume_model_exists)`, so an entry whose
    `assume_model_exists` is false or absent raises `RubyLLM::ModelNotFoundError` for a typo'd model
    id locally, BEFORE any HTTP call, inside `build_chat` — i.e. at `chat.add_message`
    (ruby_llm_agent.rb:20/30), outside any rescue that only wraps `chat.complete`.
    `LlmErrors.model_not_found?` returns true for that class unconditionally (no message match
    needed — the class means exactly this). (b) The REMOTE one, which has no distinct class:
    `lib/ruby_llm/error_middleware.rb:34-68` (`RubyLLM::ErrorMiddleware.parse_error`)
    maps HTTP status to a handful of subclasses of `RubyLLM::Error`
    (`BadRequestError`/`UnauthorizedError`/`PaymentRequiredError`/`ForbiddenError`/`RateLimitError`/
    `ServerError`/`ServiceUnavailableError`/`OverloadedError`/`ContextLengthExceededError`), and ANY
    OTHER status falls through to the final `else` branch (:65) and its
    `raise Error.new(...)` fallback (:66) raises a BARE `RubyLLM::Error` with
    no distinguishing subclass. Separately, `lib/ruby_llm/providers/openai/chat.rb:54`
    (`parse_completion_response`) raises `RubyLLM::Error.new(response, data.dig('error','message'))`
    whenever the response BODY carries `data["error"]["message"]`, REGARDLESS of HTTP status — so a
    provider that returns HTTP 200 with an error payload (S01 item (14) records whether DigitalOcean's
    inference API returns this shape; use whatever it recorded) also surfaces as a bare
    `RubyLLM::Error`. Because no exception CLASS identifies the remote case, the matcher must check
    the exception's base class is `RubyLLM::Error` (accept
    subclasses too, in case the provider ever returns it as a 400 `BadRequestError`) AND that
    `error.message.to_s` matches the exact text S01 item (14) recorded for DO's chat endpoint (and
    separately for `/v1/embeddings`, used by S18). Write the matcher as a simple regex/string match
    against that recorded text, not a status-code check, since the status the provider actually uses
    for this case was recorded (and may not be a clean 404).
  - Hook: wrap the WHOLE body of `RubyLlmAgent#ask` and `#ask!`
    (app/agents/concerns/ruby_llm_agent.rb:19-54) in
    `rescue RubyLLM::Error, RubyLLM::ModelNotFoundError => e` — the body, not just `chat.complete`,
    because the local `ModelNotFoundError` is raised by the first `chat` reference (`chat.add_message`
    at :20/:30) inside `build_chat`, and because `ask!` has TWO `chat.complete` call sites
    (ruby_llm_agent.rb:33 and :45) that both need cover. When
    `LlmErrors.model_not_found?(e)` is true, call
    `Honeybadger.notify(e, error_class: "LlmModelNotFound", context: { agent: self.class.name, entry:
llm_config_key, model: model_id, provider: LlmConfig.for(llm_config_key).provider, api_base:
LlmConfig.for(llm_config_key).api_base })` — resolved through the SAME path `build_chat` used, so
    the alert names the entry that actually misfired
    and then `raise` (re-raise the original error unchanged — this step adds visibility, it does not
    change control flow or retry behaviour). When the matcher returns false, re-raise without
    notifying (normal Honeybadger/Sidekiq handling still applies via whatever wraps the worker).
  - Why the explicit `Honeybadger.notify` matters: `config/honeybadger.yml:42-43` sets
    `sidekiq.attempt_threshold: 3`, meaning Honeybadger's automatic Sidekiq integration would not
    normally report until the THIRD failed attempt. A model-not-found error will fail identically on
    every retry (it's a config problem, not a transient one), so waiting for attempt 3 just delays
    visibility for no benefit; the explicit `notify` call here fires on the FIRST failure, bypassing
    that threshold. This step does not touch Sidekiq retry counts themselves (Q4 is deferred — see
    S04); it only adds the earlier, explicit notification.
  - `EmbeddingsClient` (app/lib/embeddings_client.rb) gets the SAME matcher wired in when it is
    rewritten in S18-llm-config-embeddings — do not touch `EmbeddingsClient` in this step; this step
    only wires the concern used by chat agents.
  - Runbook: add a new "Runbook" heading to docs/llm-migration-plan.md with a table: config entry name
    → current model → manual replacement model (picked from the S01 catalog: the runner-up candidate
    that also passed the spike's four checklist items) → how to flip (edit the entry in
    `config/llm.yml`, open a PR, merge — same mechanism S04's runbook note describes; rollback is
    `git revert` + merge). Q33 wants a line PER AGENT, so seed one row for every `config/llm.yml`
    entry now, not a collapsed placeholder: `PenVariantClusterer` gets S01's picked starting model →
    the runner-up candidate from the same spike; each OpenAI entry gets its current model → today's
    OpenAI alternative (`gpt-4.1` entries → `gpt-4.1-mini`, `gpt-4.1-mini` entries → `gpt-4o-mini`),
    which is a real manual replacement an operator can flip to while OpenAI is still the default.
    S30-chat-bench-round replaces the OpenAI rows' replacement column with the per-agent DO
    candidates before S31 (the first ink flip).
- **Depends on.** S04-llm-config-chat (the hook lives inside the config-aware concern this step
  modifies — `ask`/`ask!` must already be reading `llm_config_key`/`model_id` from the config layer
  before this PR can reference them in the notify context), S01-do-spike item (14) (the exact recorded
  HTTP status and response body text the matcher checks against — for both the chat endpoint and
  `/v1/embeddings`).
- **Why here.** Q33 wants this alert in place before the first flip to DigitalOcean. Under Q32 the
  FIRST DigitalOcean agent to run in production is not an ink-agent flip at all — it is the pen drip
  (S15-pen-drip-enable) — so this step must land before S15, not merely before S31/S37 (the ink
  cutover waves). It is placed right after S04 because it needs the config-aware concern to exist, and
  right before the pen groundwork/tools/agent steps (S06-S13) that lead up to S15.
- **Does not include.** Any Sidekiq retry-count change (Q4 deferred; see S04). Any change to
  `EmbeddingsClient` (that wiring is S18's). A UI/admin surface for these alerts — Honeybadger's own
  dashboard is the only surface.
- **Definition of done.**
  - `app/lib/llm_errors.rb` (or equivalent) with `LlmErrors.model_not_found?(error)`, unit-tested
    directly against a constructed `RubyLLM::Error` (and a `RubyLLM::Error` subclass, e.g.
    `RubyLLM::BadRequestError`) carrying the recorded message text, and against one that doesn't
    match.
  - `RubyLlmAgent#ask`/`#ask!` wrapped as described; a concern spec
    (`spec/agents/concerns/ruby_llm_agent_spec.rb`) with these cases, using WebMock against
    `https://api.openai.com/v1/chat/completions` (the test-environment endpoint every agent resolves
    to, per S04):
    1. Stub a response with the EXACT status and body S01 item (14) recorded for the "model not
       found" case → `expect(Honeybadger).to receive(:notify).with(kind_of(RubyLLM::Error),
hash_including(error_class: "LlmModelNotFound"))` and
       `expect { agent_with_tools.ask("hi") }.to raise_error(RubyLLM::Error)`. The subjects in this
       file are the anonymous classes built at :4-14 and :16-... and are driven with `ask`/`ask!`
       (`agent_with_tools.ask(...)` at :449, :472, :497, :518, :539; `ask!` at :367) — there is no
       `perform` anywhere in this spec, so do not write one.
       1b. The same case driven through `ask!`, since `ask!` has its own two `chat.complete` sites
       (ruby_llm_agent.rb:33 and :45) and both must be inside the rescue.
       1c. An entry with `assume_model_exists: false` and a nonexistent model id → notifies with
       `error_class: "LlmModelNotFound"` and re-raises `RubyLLM::ModelNotFoundError`, with NO HTTP
       request made (assert with WebMock `have_not_been_made`).
    2. Stub a plain 500 (`RubyLLM::ServerError`) → `expect(Honeybadger).not_to receive(:notify)` (this
       error class/message does not match the recorded text) and the error still propagates normally.
    3. Stub a 200 response whose body carries `data["error"]["message"]` equal to the recorded text
       (covers the "DO returns 200 with an error payload" shape from `chat.rb:54`) → same
       `Honeybadger.notify` expectation as case 1, asserted as
       `expect { agent_with_tools.ask("hi") }.to raise_error(RubyLLM::Error)`.
       Note on test setup: `config/honeybadger.yml`'s `development_environments: [test, development,
cucumber]` means `Honeybadger.notify` is normally a no-op in the test environment (no API key, no
       real reporting) — the `expect(Honeybadger).to receive(:notify)`/`not_to receive` assertions ARE the
       whole check; there is nothing further to configure, and per the codebase convention do not add
       `WebMock.reset!` anywhere in this spec.
  - Runbook table merged into docs/llm-migration-plan.md with one seeded row per `config/llm.yml`
    entry, as described above.
  - Full suite green.
- **Implementation notes.**
  - The exact matcher text comes from S01 item (14)'s recorded findings — do not guess or invent
    plausible-looking text; if S01's findings are not yet available when this step is implemented,
    treat that as a blocker and go re-run/read S01's output rather than shipping a matcher against a
    guessed string.
  - Because `RubyLLM::Error` is the base class every mapped subclass inherits from, `error.is_a?(RubyLLM::Error)`
    is true for ALL of them; the matcher's DISCRIMINATING check is the message-text match, not the
    class check alone — a `RateLimitError` or `ServerError` must NOT match just because it's a
    `RubyLLM::Error`.
  - Keep the rescue inside the concern: `rescue RubyLLM::Error, RubyLLM::ModelNotFoundError => e`
    around the bodies of `ask`/`ask!` (covering the first `chat` reference and both `chat.complete`
    sites), not a blanket top-level rescue elsewhere in the concern or in
    `RunAgent`/`RunInkClustererAgent` — those workers should keep seeing the same exception classes
    they see today so their own error handling (if any) is unaffected.
  - `llm_config_key` (added in S04) is the right thing to put in the Honeybadger `context:` hash
    (not `self.class.name` alone) so a `CheckInkClustering::Assign` failure and a `PenAndInkSuggester`
    premium-tier failure are both traceable to the exact config entry that misfired.
- **Decisions applied.** Q33 (explicit alert on the provider's model-not-found error, independent of
  the Sidekiq attempt threshold, plus a runbook naming a manual replacement model per agent), Q32
  (this alert must protect the drip, the first DO agent in prod, not merely the later ink flips), Q5
  (no cost/usage change here — out of scope for this step regardless).

### S06-pen-groundwork — `agent_logs` on three pen models, per-agent AgentLog scopes, `with_collected_pens` (the Q8 filter), tuple helper, `(name, state)` index

- **Goal.** Additive model work that every pen agent spec needs
  (`RubyLlmAgent#find_or_create_agent_log` calls `owner.agent_logs`,
  app/agents/concerns/ruby_llm_agent.rb:56-59). Add
  `has_many :agent_logs, as: :owner, dependent: :destroy` to `Pens::MicroCluster`,
  `Pens::ModelMicroCluster` and `Pens::Model` (the L3 owner the pen plan omits); copy the line from
  app/models/micro_cluster.rb:6. Replace the raw-SQL `AgentLog.with_collected_inks` (hard-coded to
  owner_type `MicroCluster`, app/models/agent_log.rb:20-25) with per-agent scopes:
  `AgentLog.owner_with_collected_inks` (the existing one, renamed), `owner_with_collected_pens`
  (owner_type `Pens::MicroCluster`, EXISTS `collected_pens.pens_micro_cluster_id`) and
  `owner_with_model_variants` (owner_type `Pens::ModelMicroCluster`, EXISTS
  `pens_model_variants.pens_model_micro_cluster_id`, FK db/structure.sql:2352), plus
  `AgentLog.pen_variant_clusterer` next to `ink_clusterer` (agent_log.rb:14). Add
  `Pens::MicroCluster.with_collected_pens` so "unassigned and has pens" (96,711-96,830 rows on prod,
  not the 106,044-106,197 the bare `unassigned.without_ignored` returns) is one reusable scope, and
  `Pens::ModelMicroCluster.with_model_variants` as its L2 twin. These scopes ARE the decided
  filter (Q8): the 453 empty ASSIGNED pen micro clusters and the 349 empty ASSIGNED model micro
  clusters stay in the database as human spelling rules (`Pens::AssignMicroCluster#find_or_create_cluster`
  reuses any existing cluster with the same simplified brand/model/color, app/workers/pens/assign_micro_cluster.rb:16-26;
  `Pens::AssignModelMicroCluster#perform`'s `find_or_create_by!` does the same at L2, assign_model_micro_cluster.rb:7),
  and every queue, dashboard, bench and cleanup query goes through these scopes instead of seeing
  them. Consumers: S13 (top-up priority query), S14 (review queue and dashboard count), S21 and S29
  (bench case exporters), S08 (the cleanup selects the inverse with `NOT EXISTS`). Add a prompt-data
  helper on `Pens::MicroCluster` returning distinct (brand, model, color, material, trim_color,
  filling_system) tuples with counts from its collected pens (no nib), modelled on
  `Pens::ModelVariant#all_names` (app/models/pens/model_variant.rb:43-52). The cap is a REQUIRED
  keyword argument on the helper, never a default: the single public constant
  `PenVariantClusterer::PROMPT_TUPLE_CAP = 40` (S11) is the only place the number 40 lives, and every
  caller passes it in. Add a concurrent `(name, state)` index on `agent_logs`: prod has
  53,810-54,065 `waiting-for-approval` rows (every non-clusterer agent parks its logs there for
  good), only `(owner_type, owner_id)` and `(state)` indexes exist (db/structure.sql:1736,1743), and
  `EXPLAIN ANALYZE SELECT count(*) FROM agent_logs WHERE name='PenVariantClusterer' AND state IN ('waiting-for-approval','processing')`
  on prod takes 1.8 s cold / 85 ms warm (Index Scan on `state`, ~54k rows removed by filter). The
  count runs after every review and on every dashboard load from S13/S14 on.
- **Depends on.** Nothing.
- **Why here.** Hard prerequisite for S11, S13, S16, S29 and S42 (`owner.agent_logs`) and for the
  queue/bench scopes; S08 and S10 do not need it (S08 may use the new scope for its before/after
  counts). The index is cheapest before any pen log exists (today there are 0 `agent_logs` rows
  with an owner_type starting `Pens::`, verified on the prod replica 2026-09-14).
- **Does not include.** Any behaviour change; the tuple helper's use in a prompt (S11); the inverse
  `NOT EXISTS` scopes (`without_collected_pens` etc.) that the cleanup adds (S08); the L2
  `AgentLog.pen_model_clusterer` scope (S29).
- **Definition of done.**
  - Rename the two callers of `with_collected_inks` (app/models/admin_stats.rb:19,
    app/controllers/admins/agents/ink_clusterer_controller.rb:76); `grep -rn with_collected_inks app spec lib`
    finds nothing else today. The existing behaviour specs
    spec/requests/admins/agents/ink_clusterer_controller_spec.rb:20-45 ("hides logs whose micro
    cluster has no collected inks") and spec/models/admin_stats_spec.rb:4-25 stay green unchanged
    (neither names the scope).
  - New spec/models/agent_log_spec.rb (none exists today) covering the four scopes; new examples in
    spec/models/pens/micro_cluster_spec.rb (scope, tuple helper, association),
    spec/models/pens/model_micro_cluster_spec.rb and spec/models/pens/model_spec.rb (scope,
    association); spec/models/admin_stats_spec.rb gains the two pen-count examples below.
  - `AdminStats#pens_micro_clusters_to_assign_count` (admin_stats.rb:35-45) and
    `#pens_model_micro_clusters_to_assign_count` (admin_stats.rb:23-33) use the new scopes; the
    dashboard numbers do not change (the joins+group+count.count they replace already excluded
    empties).
  - Migration merged; `db/structure.sql` regenerated from the container's pg_dump 17.x
    (`docker-compose exec app bundle exec rails db:migrate` rewrites it), never from the host's
    Postgres.app 18.1; the diff contains exactly one new `CREATE INDEX index_agent_logs_on_name_and_state ON public.agent_logs USING btree (name, state);`
    line and one new `schema_migrations` version. Full suite green, no new warnings, `yarn lint`
    clean (Prettier formats `.rb` via @prettier/plugin-ruby).
- **Implementation notes.**
  - Files to modify: app/models/agent_log.rb, app/models/pens/micro_cluster.rb,
    app/models/pens/model_micro_cluster.rb, app/models/pens/model.rb, app/models/admin_stats.rb,
    app/controllers/admins/agents/ink_clusterer_controller.rb, spec/factories/agent_logs.rb (add
    `trait :pen_variant_clusterer do name { "PenVariantClusterer" } end` next to `:ink_clusterer`,
    agent_logs.rb:31-33). Files to create: db/migrate/<timestamp>_add_name_state_index_to_agent_logs.rb,
    spec/models/agent_log_spec.rb.
  - Scopes as EXISTS subqueries, not joins, so `.count` and `.or` keep working on the relation (the
    controller does `.where(state: [...]).or(AgentLog.ink_clusterer.agent_processed).<scope>` at
    ink_clusterer_controller.rb:71-78; `.or` raises "Relation passed to #or must be structurally
    compatible" as soon as one side carries a join). Exact code for agent_log.rb, replacing lines
    16-25:

    ```ruby
    scope :pen_variant_clusterer, -> { where(name: "PenVariantClusterer") }

    # Only logs whose owner still has members. Empty owners are hidden everywhere in
    # the app (empty assigned pen clusters are kept on purpose as spelling rules), so
    # their logs must not reach any queue or count. One scope per owner type.
    scope :owner_with_collected_inks,
          -> do
            where(
              "agent_logs.owner_type = 'MicroCluster' AND EXISTS (SELECT 1 FROM collected_inks WHERE collected_inks.micro_cluster_id = agent_logs.owner_id)"
            )
          end
    scope :owner_with_collected_pens,
          -> do
            where(
              "agent_logs.owner_type = 'Pens::MicroCluster' AND EXISTS (SELECT 1 FROM collected_pens WHERE collected_pens.pens_micro_cluster_id = agent_logs.owner_id)"
            )
          end
    scope :owner_with_model_variants,
          -> do
            where(
              "agent_logs.owner_type = 'Pens::ModelMicroCluster' AND EXISTS (SELECT 1 FROM pens_model_variants WHERE pens_model_variants.pens_model_micro_cluster_id = agent_logs.owner_id)"
            )
          end
    ```

    `owner_type` is stored as the full class name `'Pens::MicroCluster'` (polymorphic
    `belongs_to :owner`, agent_log.rb:2; no STI in the pen models).

  - `Pens::MicroCluster` (app/models/pens/micro_cluster.rb, 14 lines) gains:

    ```ruby
    has_many :agent_logs, as: :owner, dependent: :destroy

    scope :with_collected_pens,
          -> do
            where(
              "EXISTS (SELECT 1 FROM collected_pens WHERE collected_pens.pens_micro_cluster_id = pens_micro_clusters.id)"
            )
          end

    TUPLE_COLUMNS = %w[brand model color material trim_color filling_system].freeze

    # Distinct spellings of the pens in this cluster with their counts, most common
    # first. `nib` is deliberately left out (it is a nib size, not a pen attribute).
    # Rows respond to #brand ... #filling_system and #collected_pens_count.
    def collected_pen_tuples(limit:)
      columns = TUPLE_COLUMNS.map { |c| "collected_pens.#{c}" }.join(", ")
      collected_pens
        .group(columns)
        .select("count(*) AS collected_pens_count, #{columns}")
        .order("collected_pens_count DESC, #{columns}")
        .limit(limit)
    end

    # Number of distinct tuples, for the prompt's "and N more" line (S11).
    def collected_pen_tuple_count
      columns = TUPLE_COLUMNS.map { |c| "collected_pens.#{c}" }.join(", ")
      collected_pens.distinct.count("(#{columns})")
    end
    ```

    `collected_pens` is the direct association (micro_cluster.rb:2), so no join is needed; `nib`
    exists on `collected_pens` (db/structure.sql:288) and must stay out. Implementer default: the
    secondary `ORDER BY` on the columns makes the row order deterministic for specs and prompts;
    `collected_pen_tuple_count` uses `COUNT(DISTINCT (row))`, which Postgres accepts. `limit:` has no
    default on purpose (see the goal): the cap is `PenVariantClusterer::PROMPT_TUPLE_CAP` and lives in
    exactly one place.

  - `Pens::ModelMicroCluster` (model_micro_cluster.rb, 15 lines) gains
    `has_many :agent_logs, as: :owner, dependent: :destroy` and
    `scope :with_model_variants, -> { where("EXISTS (SELECT 1 FROM pens_model_variants WHERE pens_model_variants.pens_model_micro_cluster_id = pens_model_micro_clusters.id)") }`.
    `Pens::Model` (model.rb) gains the `has_many :agent_logs` line after `has_one :pen_embedding`
    (model.rb:11).
  - AdminStats: `pens_micro_clusters_to_assign_count` becomes
    `Pens::MicroCluster.unassigned.without_ignored.with_collected_pens.count`;
    `pens_model_micro_clusters_to_assign_count` becomes
    `Pens::ModelMicroCluster.unassigned.without_ignored.with_model_variants.count`. Leave
    `pens_micro_clusters_prio_to_assign_count` and `relevant_pens_micro_clusters_count`
    (admin_stats.rb:47-67) alone: they need `HAVING count(*) > ?`, which EXISTS cannot express.
  - Index migration (copy the shape of db/migrate/20260625120200_add_index_to_users_patreon_user_id.rb):

    ```ruby
    class AddNameStateIndexToAgentLogs < ActiveRecord::Migration[8.1]
      disable_ddl_transaction!

      def change
        add_index :agent_logs, %i[name state], algorithm: :concurrently
      end
    end
    ```

    strong_migrations 2.8.0 (config/initializers/strong_migrations.rb) refuses `add_index` on an
    existing table without `algorithm: :concurrently`, and Rails refuses `CONCURRENTLY` inside a
    transaction, so both lines are required; do not wrap in `safety_assured`. The table is 66 MB of
    heap (the 1 GB total is transcript TOAST, which an index on two short columns never reads), so
    the build takes seconds inside the Fly release command (`release_command = 'bundle exec rake db:migrate db:seed'`,
    fly.toml:16). Rollback if a concurrent build is interrupted: it leaves an INVALID index; check
    `SELECT indisvalid FROM pg_index WHERE indexrelid = 'index_agent_logs_on_name_and_state'::regclass`,
    `DROP INDEX CONCURRENTLY` it, and rerun `db:migrate`.

  - Specs to write (all `require "rails_helper"`, FactoryBot, transactional fixtures):
    - spec/models/agent_log_spec.rb — `describe ".owner_with_collected_inks"`: a log on a
      `create(:micro_cluster)` with `cluster.collected_inks = [create(:collected_ink)]` is included;
      a log on an empty `create(:micro_cluster)` is excluded; a log on a `create(:pens_micro_cluster)`
      with pens is excluded (wrong owner_type). `describe ".owner_with_collected_pens"`: included for
      `create(:pens_micro_cluster, collected_pens: [create(:collected_pen)])`, excluded for an empty
      pen cluster, excluded for an ink `MicroCluster` owner. `describe ".owner_with_model_variants"`:
      included for `mmc = create(:pens_model_micro_cluster); create(:pens_model_variant, model_micro_cluster: mmc)`,
      excluded for an empty mmc. `describe ".pen_variant_clusterer"`: filters by name. One
      composability example: `AgentLog.pen_variant_clusterer.waiting_for_approval.or(AgentLog.pen_variant_clusterer.agent_processed).owner_with_collected_pens.count`
      returns the right number and does not raise (this is the exact shape S14's controller uses).
      Build logs with `AgentLog.create!(name: "PenVariantClusterer", owner: cluster, transcript: [], state: AgentLog::WAITING_FOR_APPROVAL)`
      as spec/models/admin_stats_spec.rb:11-22 does, or `create(:agent_log, :pen_variant_clusterer, :waiting_for_approval, owner: cluster)`.
    - spec/models/pens/micro_cluster_spec.rb — `describe ".with_collected_pens"` (with pens
      included; empty excluded; an assigned cluster with pens included, since the scope is about
      pens, not assignment). `describe "#collected_pen_tuples"`: two pens with identical
      brand/model/color/material/trim_color/filling_system but different `nib` ("M" and "F") plus
      one pen with a different color give two rows, the first with `collected_pens_count == 2`;
      `collected_pen_tuples(limit: 1).to_a.size == 1`; `collected_pen_tuple_count == 2`.
      `describe "agent_logs"`: `log = create(:agent_log, owner: cluster); expect { cluster.destroy }.to change(AgentLog, :count).by(-1)`
      (the cluster must have no pens, or `destroy` raises `ActiveRecord::InvalidForeignKey`, FK
      db/structure.sql:2384 — that is the S08 safety net, not a bug).
    - spec/models/pens/model_micro_cluster_spec.rb and spec/models/pens/model_spec.rb — the same
      association example for `Pens::ModelMicroCluster` and `Pens::Model` (`Pens::Model#destroy`
      already nullifies its mmcs and destroys its embedding, model.rb:4-11, so it needs nothing
      else). `describe ".with_model_variants"` on the mmc spec.
    - spec/models/admin_stats_spec.rb — `#pens_micro_clusters_to_assign_count`: one unassigned
      cluster with a pen, one unassigned empty, one ignored with a pen, one assigned with a pen →
      `eq(1)`. `#pens_model_micro_clusters_to_assign_count`: one unassigned mmc with a variant, one
      unassigned empty, one assigned with a variant → `eq(1)`.
  - Factories exist for the whole pen hierarchy (spec/factories/pens/*.rb, spec/factories/collected_pen.rb);
    `create(:collected_pen)` does NOT enqueue `Pens::AssignMicroCluster` or create a `PenEmbedding`,
    so attach pens explicitly with `collected_pens: [...]` or `pens_micro_cluster:`.
  - Manual verification in dev (the dev DB is a stale prod copy): in `docker-compose exec app bundle exec rails console`
    run `Pens::MicroCluster.unassigned.without_ignored.count` (about 96,6xx) versus
    `Pens::MicroCluster.unassigned.without_ignored.with_collected_pens.count` (about 7,1xx lower)
    and `AdminStats.new.pens_micro_clusters_to_assign_count` (equal to the second number); after
    `db:migrate`, `EXPLAIN ANALYZE SELECT count(*) FROM agent_logs WHERE name='PenVariantClusterer' AND state IN ('waiting-for-approval','processing')`
    in `rails dbconsole` shows an Index Only Scan on `index_agent_logs_on_name_and_state`.
  - Prod risk low: the PR changes no behaviour; the release command adds one index in seconds; the
    dashboard counts are computed differently but are the same numbers.
- **Decisions applied.** Q8 (assigned empties are kept and filtered by these scopes); "Resolved
  without asking": the concurrent `(name, state)` index, and the prompt-size cap for the pen agent's
  tuple list being a single public constant (`PROMPT_TUPLE_CAP = 40` plus "and N more"), which is why
  this helper takes the cap as a required argument rather than defaulting it.

### S07-csv-import-routing — Route `ImportCollectedPen` through `SaveCollectedPen`

- **Goal.** `ImportCollectedPen` currently does `pen.update!(params(row))`
  (app/workers/import_collected_pen.rb:12), so CSV-imported pens get no micro cluster and no
  embedding until the disabled `RefreshPens` (config/sidekiq_schedule.yml:18-21, `enabled: false`)
  is run by hand. Prod on 2026-09-14: 1,407 pens without a micro cluster, 0.7% of 202,878; by
  month 2026-09 114, 2026-07 20, 2026-06 3, 2026-05 299, 2026-04 499, 2026-03 10, 2026-02 151, so
  imports are ongoing; the only caller is `Admins::UsersController#pen_import`
  (app/controllers/admins/users_controller.rb:59-68, `ImportCollectedPen.perform_async(@user.id, row)`
  at :64). Replace line 12 with

  ```ruby
  SaveCollectedPen.new(pen, params(row)).perform || raise(ActiveRecord::RecordInvalid, pen)
  ```

  `SaveCollectedPen#perform` (app/operations/save_collected_pen.rb:7-14) saves the
  `find_or_initialize_by` record (`update` on a new record inserts it, exactly as
  `CollectedPensController#create` does with `current_user.collected_pens.build(...)`,
  app/controllers/collected_pens_controller.rb:37-39), enqueues `Pens::AssignMicroCluster` (:11)
  and builds or updates the `PenEmbedding` row with `content: pen.pen_name` (:20-26; the
  `after_save` at app/models/pen_embedding.rb:12-20 enqueues `FetchEmbedding` when the content
  changed). It uses `update` and `return false unless updated` (:8-9), so without the raise a
  malformed row (brand / model length 1..100, app/models/collected_pen.rb:17-20) would turn from a
  loud Sidekiq retry + Honeybadger report (`sidekiq.attempt_threshold: 3`, config/honeybadger.yml)
  into a silent drop; the raise keeps today's failure behaviour. This change is unconditional (Q9).
  The one-off re-save of the pens already imported without a cluster is S08's task (7), not this
  step's.

- **Depends on.** Nothing.
- **Why here.** Before S08, so that after S08's one-off re-save the count of collected pens without
  a micro cluster is zero and stays zero; before S17 (first bench dump) and S24 (embedding backfill)
  so both see complete tables and no later re-save is ever needed (Q9). S40 still depends on this
  step: once the real-time trigger exists, a bulk re-save would enqueue one agent run per touched
  unassigned cluster, so the last bulk re-save (S08) must have happened long before.
- **Does not include.** The one-off re-save (S08 task 7). Any other import behaviour change
  (`ImportCurrentlyInked`, app/workers/import_currently_inked.rb, only creates `currently_inkeds`
  via `find_by` on existing pens and is untouched). Running the argument-less `RefreshPens`: never
  do that — app/workers/refresh_pens.rb:7-13 batches **all** ~202k pens through `SaveCollectedPen`,
  i.e. ~400k `default`-queue jobs plus the variant-update cascade for the ~99k pens in assigned
  clusters (`Pens::UpdateModelVariant -> AssignModelMicroCluster -> UpdateModelMicroCluster -> UpdateModel -> AssignBrand`),
  hours of worker time on 5 threads (fly.toml:33 `SIDEKIQ_CONCURRENCY=5`) with strict queue
  priority, and `Pens::AssignMicroCluster` re-picks the lowest-id matching cluster so pens can move
  clusters. `RefreshPens.perform_async(ids)` with explicit id batches (refresh_pens.rb:11) is the
  allowed form and is what S08 uses.
- **Definition of done.**
  - app/workers/import_collected_pen.rb:12 replaced as above; nothing else in the file changes
    (`clean_data!`, `collected_pen`, `params` stay; `params(row)` still carries `created_at` when
    `date_added` parses, :34-41).
  - spec/workers/import_collected_pen_spec.rb (today 5 examples: imports a pen, created_at from
    date_added, malformed date, blank date, re-import with blank date) extended with the examples
    listed under Implementation notes; all green; full suite green with no new warnings.
  - PR description states the prod behaviour change: every imported pen now enqueues
    `Pens::AssignMicroCluster` (default queue) and gets a `PenEmbedding` row whose `FetchEmbedding`
    job runs on the `low` queue (fetch_embedding.rb:5-6, throttle 4) — one embedding call per
    imported pen, fractions of a cent per import.
- **Implementation notes.**
  - The worker keeps `save_pen` public (the spec calls `described_class.new.perform`). New body:

    ```ruby
    def save_pen(user_id, row)
      clean_data!(row)
      pen = collected_pen(user_id, row)
      SaveCollectedPen.new(pen, params(row)).perform || raise(ActiveRecord::RecordInvalid, pen)
    end
    ```

    `raise(ActiveRecord::RecordInvalid, pen)` calls `ActiveRecord::RecordInvalid.new(pen)`, whose
    message lists `pen.errors` — the same exception class and message `update!` raised before, so
    Sidekiq retries and Honeybadger grouping are unchanged.

  - Tests use Sidekiq fake mode (`Sidekiq.testing!(:fake)`, spec/rails_helper.rb:8; jobs cleared
    before each example, :24) and assert on `Worker.jobs`, never on `receive(:perform_async)`
    (spec/agents/README.md:189-209). Add to spec/workers/import_collected_pen_spec.rb:
    - "enqueues micro cluster assignment": after `perform(user.id, row)`,
      `pen = user.collected_pens.first; expect(Pens::AssignMicroCluster.jobs.map { |j| j["args"] }).to eq([[pen.id]])`.
    - "creates the embedding row with the pen name":
      `expect(pen.pen_embedding.content).to eq(pen.pen_name)` and
      `expect(FetchEmbedding.jobs.map { |j| j["args"] }).to eq([["PenEmbedding", pen.pen_embedding.id]])`
      (the factory row has brand "Wing Sung", model "618", color "black", so `pen_name` is
      `"Wing Sung 618 black"` — `pen_name` joins brand, model, color, material, trim_color,
      filling_system and skips blanks, collected_pen.rb:105-108; nib is not part of it).
    - "still applies created_at from date_added through the params hash": keep the existing
      example; it now goes through `SaveCollectedPen` (`update(created_at: ...)`), and must stay
      green unchanged.
    - "re-imports an existing pen without duplicating it and enqueues assignment again": perform
      twice with the same row; `expect(user.collected_pens.count).to eq(1)`;
      `expect(Pens::AssignMicroCluster.jobs.size).to eq(2)`; `expect(PenEmbedding.count).to eq(1)`;
      `FetchEmbedding.jobs.size` is 1 (content unchanged the second time, so `after_save` does not
      re-enqueue).
    - "raises on an invalid row and enqueues nothing":
      `expect { described_class.new.perform(user.id, row("model" => "")) }.to raise_error(ActiveRecord::RecordInvalid)`;
      `expect(Pens::AssignMicroCluster.jobs).to be_empty`; `expect(PenEmbedding.count).to eq(0)`;
      `expect(user.collected_pens.count).to eq(0)`. (`model` length must be 1..100,
      collected_pen.rb:19; `clean_data!` strips, so `"   "` also fails.)
    - "goes through SaveCollectedPen": pattern from spec/workers/refresh_pens_spec.rb:13-17,
      `described_class.new.perform(user.id, row("material" => "plastic"))` with
      `expect(SaveCollectedPen).to receive(:new).with(kind_of(CollectedPen), hash_including("material" => "plastic")).and_call_original`
      — the spec's own `row` helper (spec/workers/import_collected_pen_spec.rb:6-8) builds only
      brand/model/nib/color and `ImportCollectedPen#params` (import_collected_pen.rb:34-41) slices
      only keys present in the row, so a bare `row` would never match `material`; alternatively
      assert `hash_including("archived_on" => nil)`, the one key `params` always adds. Optional; the
      job assertions above already prove the routing.
  - Manual verification in dev: `docker-compose up`, log in as an admin, open
    `/admins/users/<id>`, upload a two-line CSV written BY HAND and COMMA-separated, header
    `brand,model,nib,color,material,trim_color,filling_system,price,comment,archived,date_added` —
    these are the exact keys `ImportCollectedPen` reads (import_collected_pen.rb:15-41), and
    `Admins::UsersController#pen_import` parses with the default comma separator
    (admins/users_controller.rb:59-69, `CSV.parse(content, headers: true)` at :62). Do NOT export a
    file and re-upload it: `CollectedPen.to_csv` (collected_pen.rb:30-51) writes
    `CSV.generate(col_sep: ";")` with title-case headers containing spaces
    (`Brand;Model;Nib;Color;Material;Trim Color;Filling System;...`), so its output is not
    re-importable and would parse as a single column. Then in the console: the pen has `pens_micro_cluster_id` set
    (after the dev sidekiq container ran `Pens::AssignMicroCluster`) and `pen.pen_embedding.embedding`
    is non-nil a moment later (the dev container's `FetchEmbedding` calls OpenAI with the dev key).
  - Rollback: `git revert` of the one-line change; pens imported in between keep their clusters
    and embeddings (nothing to undo).
  - Prod risk low: imports are rare admin actions (a few hundred rows a month); each row now costs
    three extra `default`/`low` jobs and one embedding call.
- **Decisions applied.** Q9.

### S08-stale-data-cleanup — Cleanup operations and rake wrappers for the decided deletion list, orphan rows, NULL vectors and the one-off re-save of unclustered pens; run on dev copy and prod

- **Goal.** Delete the unassigned empties, remove orphan embedding rows, re-embed NULL vectors,
  create the missing embedding rows and re-save the collected pens that have no micro cluster (Q8
  option (c), Q9). KEPT, on purpose: the 453 empty **assigned** pen micro clusters and the empty
  **assigned** model micro clusters — 349 on 2026-09-12, 351 when re-counted on 2026-09-15 — minus
  the 7 whose model is destroyed by task 4 and which task 3 then sweeps (see task 4; the cascade is
  unavoidable, because `Pens::Model has_many :model_micro_clusters, dependent: :nullify` leaves them
  unassigned and variant-less). So 344 of today's 351 survive this step (human spelling rules: `Pens::AssignMicroCluster#find_or_create_cluster`
  reuses any existing `Pens::MicroCluster` whose simplified brand/model/color match, lowest id,
  app/workers/pens/assign_micro_cluster.rb:16-26, and `Pens::UpdateMicroCluster` then enqueues
  `UpdateModelVariant` for its variant; `Pens::AssignModelMicroCluster#perform`'s `find_or_create_by!`
  (:7) lets a new variant skip L2 the same way), filtered everywhere by the S06 scopes; and the 5
  empty **ignored** pen micro clusters (not in the decided deletion list). The decided task list,
  with the prod counts re-run on the read-only replica on 2026-09-14 (the dev copy is older: 7,109
  vs 9,370 empties, 190 vs 307 NULL pen vectors; re-count on prod before running):
  1. Empty **unassigned**, not ignored pen micro clusters: **9,370** (9,333 on 2026-09-12).
  2. `Pens::ModelVariant` rows with no collected pens through their micro clusters: **25** (the 5
     with no micro clusters at all are among them; the other 20 hold exactly 20 of the 453 empty
     assigned micro clusters, which become unassigned empties when the variant is destroyed —
     `dependent: :nullify`, app/models/pens/model_variant.rb:2-5 — and are then deleted by task 1;
     so 433 assigned empties remain after this step, not 453).
  3. Empty **unassigned**, not ignored model micro clusters (no variants): **69** (the 351 empty
     assigned ones are kept, less the 7 task 4 orphans this same task then sweeps; all 6 ignored
     model micro clusters HAVE variants, so none of them is empty and none is in scope — unlike the
     pen side, there are no empty ignored model micro clusters at all).
  4. `Pens::Model` rows with no collected pens through mmc -> variant -> micro cluster: **14**
     today. Q8 names **7** — the models that have no variants at all before any cleanup runs. That
     count is pre-task-2: applying the project's standard "no collected pens" definition AFTER task 2
     has destroyed the 25 empty variants makes the set 14, because 7 further models' only variant was
     one of those 25. The 14 prod ids are 437, 705, 904, 931, 965, 996, 1053, 1189, 1331, 1373, 1534,
     1564, 1657 and 1786; re-run the task-4 SQL below and expect the same set. Consequence recorded
     up front: 7 of the 14 own an mmc that is one of the empty ASSIGNED model micro clusters Q8 keeps;
     destroying the model nullifies that mmc and task 3 then deletes it, which is why the kept count
     falls from 351 to 344. By the time task 4 runs all 14 are variant-less. No
     model has zero mmcs today (0), so "models with no model micro clusters" would delete nothing;
     "no collected pens" is the definition every other level uses (`Pens::UpdateModel` itself
     returns early on `model.collected_pens.empty?`, update_model.rb:7). Each of the 14 has one
     mmc; `Pens::Model#destroy` nullifies it (model.rb:4-7) and destroys the model's `pen_embedding`
     (:11); task 3 then deletes the now-unassigned empty mmc. Their public pages
     (`/pens/models/<id>-<slug>`) disappear; they were hollow (no pens, no variants after task 2).
  5. Orphan embedding rows: `pen_embeddings` **219** (all `CollectedPen`); `ink_embeddings` **607**
     (606 `CollectedInk` + 1 `MacroCluster`). Owner types present: `CollectedPen`,
     `Pens::ModelVariant`, `Pens::Model` / `CollectedInk`, `MicroCluster`, `MacroCluster`.
  6. Re-enqueue `FetchEmbedding` for NULL vectors: `pen_embeddings` **307** (301 CollectedPen, 5
     Pens::ModelVariant, 1 Pens::Model; created 2025-02-06 to today), `ink_embeddings` **1,189**
     (1,000 CollectedInk, 158 MicroCluster, 31 MacroCluster). None has blank content and all but
     ~20 are older than a day, so a plain re-enqueue is the right fix; re-enqueueing a row whose
     own job is still in flight costs one duplicate embedding call (`FetchEmbedding#perform` is an
     idempotent `update!(embedding:)`, fetch_embedding.rb:12).
  7. Re-save the **1,407** collected pens without a micro cluster (the 1,260 pens without an
     embedding row are exactly these; an embedding row alone would not make them visible, because
     tier 3 of `Pens::Model.embedding_search` INNER JOINs collected_pen -> pens_micro_cluster ->
     model_variant -> model_micro_cluster -> model, app/models/pens/model.rb:53-66) via
     `RefreshPens.perform_async(ids)` in batches of 100 (each runs `SaveCollectedPen.new(pen, {}).perform`,
     refresh_pens.rb:11, which enqueues `Pens::AssignMicroCluster` and creates the embedding row,
     save_collected_pen.rb:10-13,20-26). S07 already routes imports through `SaveCollectedPen`, so
     this is the last bulk re-save ever needed (Q9). Plus the missing ink rows: build the
     `ink_embeddings` row for the **2** ink micro clusters that have inks but no row, the way
     app/workers/assign_micro_cluster.rb:48-51 does (`content: cluster.simplified_name`; the other 2
     rowless micro clusters are empty shells and are skipped — `SaveCollectedInk` only creates
     CollectedInk embeddings, save_collected_ink.rb:22-28), and for the **4** collected inks that
     have no row (`content: collected_ink.short_name`, save_collected_ink.rb:23).
     Each cleanup is an operation class under `app/operations` with a spec; the rake tasks are
     one-line wrappers, one per cleanup, so the owner can run a subset, plus one umbrella task that
     runs them in the right order. Run on the dev copy too, so later local work sees clean data.
- **Depends on.** S00 (Fly login for the prod run); S07 (merged and deployed before task 7 runs,
  so no new unclustered pens arrive after the re-save); S06 optional (the before/after counts can
  use `Pens::MicroCluster.with_collected_pens`; the cleanup itself selects the inverse with
  `NOT EXISTS`).
- **Why here.** Before S17's first bench dump so the ink and pen retrieval baselines are measured on
  a complete label set, before S24's backfill so it enumerates complete tables (Q9), and so the
  dashboard counts mean what they say. After S07 so no new unclustered pens appear. Cheap now (well
  under $0.05 of embeddings), expensive to redo later.
- **Does not include.** Deleting any assigned empty micro cluster or model micro cluster (kept, Q8,
  except the 7 that task 4's model deletions orphan — see task 4), the 5 empty ignored pen micro
  clusters, or any of the 6 ignored model micro clusters (all 6 have variants, so none is empty); the routing change
  (S07); any behaviour change; the argument-less `RefreshPens` (see S07 for why never).
- **Definition of done.**
  - Each operation has a spec proving (a) it deletes/enqueues exactly the stale rows, (b) non-empty
    rows are untouched, (c) idempotence (a second `perform` returns 0 and changes nothing), and, for
    the pen micro cluster one, (d) the safety net: a direct `destroy` of a cluster with pens raises
    `ActiveRecord::InvalidForeignKey` (FK db/structure.sql:2384), so a wrong scope can never delete
    pens.
  - Rake wrappers exist for every operation (`bundle exec rake -T clusters embeddings` lists them
    with a `desc`), Prettier-clean (lint-staged formats `.rake`, package.json:115).
  - Tasks run on prod in the order below with before/after counts pasted into the pen plan's
    "Current state" section (and the PR description); the same on the dev copy. Verified after the
    prod run: `CollectedPen.where(pens_micro_cluster_id: nil).count` is 0 once the `RefreshPens`
    and `Pens::AssignMicroCluster` jobs have drained (minutes), and
    `PenEmbedding.where(embedding: nil).count` / `InkEmbedding.where(embedding: nil).count` are
    near 0 an hour later (the `low` queue drains ~1,500 + 1,407 `FetchEmbedding` jobs at throttle 4).
  - Rollback note in the PR: nothing irreversible of value is deleted. Unassigned empties, orphans
    and missing rows recreate themselves as pens arrive; the 25 variants and 14 models are dumped
    first (`SELECT * FROM pens_model_variants WHERE id IN (...)`, `SELECT * FROM pens_models WHERE id IN (...)`,
    39 rows, pasted into the PR) so they could be re-created by hand if ever wanted.
- **Implementation notes.**
  - Run order (each task is idempotent; the order only matters so that ONE pass is enough):
    task 2 (variants) -> task 1 (pen micro clusters, catches the 20 nullified by task 2) -> task 4
    (models) -> task 3 (model micro clusters, catches the 14 nullified by task 4) -> task 5
    (orphans) -> task 6 (NULL vectors) -> task 7 (re-save + missing ink rows). The umbrella task
    `clusters:cleanup_stale` invokes them in this order.
  - Inverse scopes (add to the models, next to the S06 positive scopes; `NOT EXISTS`, never the
    existing task's `includes(:collected_pens)` plus Ruby size check, so each task is one query and
    idempotent):
    - `Pens::MicroCluster.without_collected_pens` =
      `where("NOT EXISTS (SELECT 1 FROM collected_pens WHERE collected_pens.pens_micro_cluster_id = pens_micro_clusters.id)")`
    - `Pens::ModelVariant.without_collected_pens` =
      `where("NOT EXISTS (SELECT 1 FROM pens_micro_clusters mc JOIN collected_pens cp ON cp.pens_micro_cluster_id = mc.id WHERE mc.pens_model_variant_id = pens_model_variants.id)")`
    - `Pens::ModelMicroCluster.without_model_variants` =
      `where("NOT EXISTS (SELECT 1 FROM pens_model_variants WHERE pens_model_variants.pens_model_micro_cluster_id = pens_model_micro_clusters.id)")`
    - `Pens::Model.without_collected_pens` =
      `where("NOT EXISTS (SELECT 1 FROM pens_model_micro_clusters mmc JOIN pens_model_variants v ON v.pens_model_micro_cluster_id = mmc.id JOIN pens_micro_clusters mc ON mc.pens_model_variant_id = v.id JOIN collected_pens cp ON cp.pens_micro_cluster_id = mc.id WHERE mmc.pens_model_id = pens_models.id)")`
  - Operation classes (app/operations, style of app/operations/pens/create_brand_cluster.rb:
    `initialize` sets `attr_accessor`s, `perform` does the work; each `perform` returns the number
    of rows it touched so the rake wrapper can print it):
    - `Pens::RemoveEmptyModelVariants` (task 2): `Pens::ModelVariant.without_collected_pens.find_each(&:destroy!)`,
      counting. `destroy!` (not `delete_all`) so `dependent: :nullify` on micro clusters and
      `dependent: :destroy` on `pen_embedding` run (model_variant.rb:2-7).
    - `Pens::RemoveEmptyMicroClusters` (task 1):
      `Pens::MicroCluster.unassigned.without_ignored.without_collected_pens.find_each(&:destroy!)`.
      `Pens::MicroCluster has_many :collected_pens` has no `dependent:` (micro_cluster.rb:2), so a
      cluster with pens raises `InvalidForeignKey` on destroy — the safety net. After S06 the
      destroy also cascades `agent_logs` (none exist for pens today).
    - `Pens::RemoveEmptyModels` (task 4): `Pens::Model.without_collected_pens.find_each(&:destroy!)`
      (nullifies mmcs, destroys the embedding, model.rb:4-11).
    - `Pens::RemoveEmptyModelMicroClusters` (task 3):
      `Pens::ModelMicroCluster.unassigned.without_ignored.without_model_variants.find_each(&:destroy!)`
      (`dependent: :nullify` on variants, model_micro_cluster.rb:2-5, is a no-op here by construction).
    - `Embeddings::RemoveOrphans` (task 5), `initialize(embedding_class)`; a constant maps the
      class to its owner tables so no data-driven `constantize` is needed:
      `OWNERS = { "PenEmbedding" => { "CollectedPen" => "collected_pens", "Pens::ModelVariant" => "pens_model_variants", "Pens::Model" => "pens_models" }, "InkEmbedding" => { "CollectedInk" => "collected_inks", "MicroCluster" => "micro_clusters", "MacroCluster" => "macro_clusters" } }`.
      For each owner type: `embedding_class.where(owner_type: type).where("NOT EXISTS (SELECT 1 FROM #{table} o WHERE o.id = #{embedding_class.table_name}.owner_id)").delete_all`
      (`delete_all`: embedding rows have no dependents and no callbacks worth running; 826 rows).
      Also count rows whose `owner_type` is not in the map and raise if any exist (none today).
    - `Embeddings::ReenqueueNullVectors` (task 6), `initialize(embedding_class)`:
      `ids = embedding_class.where(embedding: nil).pluck(:id); FetchEmbedding.perform_bulk(ids.map { |id| [embedding_class.name, id] })`
      (Sidekiq 8.1.7 has `perform_bulk`; it respects `sidekiq_options queue: "low"` and the throttle
      is applied at execution, fetch_embedding.rb:5-6). Return `ids.size`.
    - `Pens::ReclusterUnclusteredPens` (task 7a):
      `CollectedPen.where(pens_micro_cluster_id: nil).in_batches(of: 100) { |batch| RefreshPens.perform_async(batch.pluck(:id)) }`
      — the exact shape of refresh_pens.rb:9 with a `where`; return the pen count.
    - `CreateMissingInkEmbeddings` (task 7b, top level — ink models are not namespaced):
      `MicroCluster.where("EXISTS (SELECT 1 FROM collected_inks WHERE collected_inks.micro_cluster_id = micro_clusters.id) AND NOT EXISTS (SELECT 1 FROM ink_embeddings WHERE ink_embeddings.owner_type = 'MicroCluster' AND ink_embeddings.owner_id = micro_clusters.id)").find_each { |c| c.build_ink_embedding.update!(content: c.simplified_name) }`
      and `CollectedInk.where("NOT EXISTS (SELECT 1 FROM ink_embeddings WHERE ink_embeddings.owner_type = 'CollectedInk' AND ink_embeddings.owner_id = collected_inks.id)").find_each { |i| i.build_ink_embedding.update!(content: i.short_name) }`.
      Creating the row enqueues `FetchEmbedding` through the `after_save` (ink_embedding.rb:9-17).
      The 4 rowless collected inks are included: Q8 decides "fix missing rows", so this runs
      unconditionally — there is no implementer or owner branch here.
  - Rake wrappers: lib/tasks/clusters.rake (replace the body of the existing
    `clusters:remove_empty_pens_micro_clusters`, :1-8, with `puts Pens::RemoveEmptyMicroClusters.new.perform`
    and keep its name) plus `remove_empty_pens_model_variants`, `remove_empty_pens_models`,
    `remove_empty_pens_model_micro_clusters`, `recluster_unclustered_pens`, and `cleanup_stale`
    (invokes the others in the run order above via `Rake::Task["clusters:x"].invoke`); new
    lib/tasks/embeddings.rake with `embeddings:remove_orphans` (both classes),
    `embeddings:reenqueue_null_vectors` (both classes) and `embeddings:create_missing_ink_rows`.
    Every task gets a `desc` (lib/tasks/cache.rake is the template; `task name: :environment do`).
    Do not define helper methods at rake-file scope (fetch_all_youtube.rake does; it pollutes
    `Object`) — all logic lives in the operation classes.
  - No rake-task spec exists in the repo (`grep -rn 'Rake::Task' spec` is empty); spec the
    operation classes under spec/operations/pens/_\_spec.rb, spec/operations/embeddings/__spec.rb and
    spec/operations/create_missing_ink_embeddings_spec.rb. If a task must be tested directly:
    `Rails.application.load_tasks` once, then `Rake::Task["clusters:x"].reenable; Rake::Task["clusters:x"].invoke`.
  - Concrete spec cases (factories: spec/factories/pens/*.rb, collected_pen.rb, pen_embeddings.rb,
    micro_clusters.rb, collected_ink.rb; hierarchy-building pattern spec/workers/pens/update_model_spec.rb:4-26):
    - RemoveEmptyMicroClusters: unassigned empty cluster is destroyed; unassigned cluster with a
      pen is kept; ignored empty (`ignored: true`) is kept; assigned empty
      (`model_variant: create(:pens_model_variant)`) is kept; second run returns 0; safety net
      `expect { create(:pens_micro_cluster, collected_pens: [create(:collected_pen)]).destroy }.to raise_error(ActiveRecord::InvalidForeignKey)`.
    - RemoveEmptyModelVariants: a variant whose only micro cluster is empty is destroyed and that
      micro cluster's `pens_model_variant_id` becomes nil and its `pen_embedding` row is gone
      (`create(:pen_embedding, owner: variant, content: "x")` first; note this enqueues a
      `FetchEmbedding` job — call `Sidekiq::Worker.clear_all` or ignore the jobs array); a variant
      with a pen through a micro cluster is kept; a variant with no micro clusters at all is
      destroyed; idempotent.
    - RemoveEmptyModelMicroClusters: unassigned mmc without variants destroyed; unassigned with a
      variant kept; assigned without variants kept; ignored kept; idempotent.
    - RemoveEmptyModels: a model whose mmc has a variant with a pen is kept; a model whose only mmc
      has no variants is destroyed and the mmc's `pens_model_id` is nil afterwards and its embedding
      row is gone; a model whose only variant has no pens is destroyed; idempotent.
    - Embeddings::RemoveOrphans (for `PenEmbedding` and `InkEmbedding`): build a row then delete
      its owner with `owner.delete` (bypasses `dependent: :destroy`, which is how prod orphans
      arose) → row removed; a row with a live owner stays; returns the count; a row with an unknown
      `owner_type` raises `Embeddings::RemoveOrphans::UnknownOwnerType` (define that error class on the
      operation and raise it from the "count rows whose owner_type is not in the map" check above).
      Build the row with `PenEmbedding.insert!({ owner_type: "Nope", owner_id: 1, content: "x" })` —
      `insert!` bypasses the polymorphic `belongs_to`, and `content`, `owner_type`, `owner_id`,
      `created_at` and `updated_at` are all NOT NULL (db/structure.sql:788-796), with Rails 8 filling
      the timestamps via `record_timestamps`. Then
      `expect { described_class.new(PenEmbedding).perform }.to raise_error(Embeddings::RemoveOrphans::UnknownOwnerType)`.
      Clear Sidekiq jobs after setup; creating rows enqueues jobs.
    - Embeddings::ReenqueueNullVectors: two NULL rows and one row with `embedding: Array.new(1536, 0.0)`;
      after `Sidekiq::Worker.clear_all` and `perform`, `FetchEmbedding.jobs.map { |j| j["args"] }`
      contains exactly `["PenEmbedding", id1]` and `["PenEmbedding", id2]`; returns 2.
    - Pens::ReclusterUnclusteredPens: `create_list(:collected_pen, 150)` unclustered plus one with
      `pens_micro_cluster: create(:pens_micro_cluster)`; `expect { perform }.to change(RefreshPens.jobs, :length).by(2)`,
      first job 100 ids, second 50, neither includes the clustered pen (mirror
      spec/workers/refresh_pens_spec.rb:4-11); returns 150.
    - CreateMissingInkEmbeddings: micro cluster with an ink and no row → row created with
      `content == cluster.simplified_name` and one `FetchEmbedding` job; empty micro cluster
      without row → nothing; micro cluster with a row → untouched; collected ink without row → row
      with `content == ink.short_name`; idempotent.
  - Before/after count SQL for the PR description (run on the read-only URL, see the "How to query
    prod safely" recipe: `URL=$(tail -1 .env.local | cut -d= -f2-)`, pipe SQL prefixed with
    `SET statement_timeout='60s';` into `psql "$URL" -A -F $'\t' -q`; never print `$URL`), and on
    the dev copy:

    ```sql
    -- task 1 / kept assigned / kept ignored
    SELECT count(*) FILTER (WHERE pens_model_variant_id IS NULL AND NOT ignored) AS empty_unassigned,
           count(*) FILTER (WHERE pens_model_variant_id IS NOT NULL) AS empty_assigned,
           count(*) FILTER (WHERE ignored) AS empty_ignored
    FROM pens_micro_clusters mc WHERE NOT EXISTS (SELECT 1 FROM collected_pens cp WHERE cp.pens_micro_cluster_id = mc.id);
    -- task 2
    SELECT count(*) FROM pens_model_variants v WHERE NOT EXISTS (SELECT 1 FROM pens_micro_clusters mc JOIN collected_pens cp ON cp.pens_micro_cluster_id = mc.id WHERE mc.pens_model_variant_id = v.id);
    -- task 3 (rows: unassigned/assigned x ignored)
    SELECT (pens_model_id IS NOT NULL) AS assigned, ignored, count(*) FROM pens_model_micro_clusters m WHERE NOT EXISTS (SELECT 1 FROM pens_model_variants v WHERE v.pens_model_micro_cluster_id = m.id) GROUP BY 1, 2;
    -- task 4
    SELECT count(*) FROM pens_models m WHERE NOT EXISTS (SELECT 1 FROM pens_model_micro_clusters mm JOIN pens_model_variants v ON v.pens_model_micro_cluster_id = mm.id JOIN pens_micro_clusters mc ON mc.pens_model_variant_id = v.id JOIN collected_pens cp ON cp.pens_micro_cluster_id = mc.id WHERE mm.pens_model_id = m.id);
    -- task 5
    SELECT count(*) FROM pen_embeddings e WHERE e.owner_type = 'CollectedPen' AND NOT EXISTS (SELECT 1 FROM collected_pens x WHERE x.id = e.owner_id);
    SELECT owner_type, count(*) FROM ink_embeddings e WHERE (e.owner_type = 'CollectedInk' AND NOT EXISTS (SELECT 1 FROM collected_inks x WHERE x.id = e.owner_id)) OR (e.owner_type = 'MacroCluster' AND NOT EXISTS (SELECT 1 FROM macro_clusters x WHERE x.id = e.owner_id)) OR (e.owner_type = 'MicroCluster' AND NOT EXISTS (SELECT 1 FROM micro_clusters x WHERE x.id = e.owner_id)) GROUP BY 1;
    -- task 6
    SELECT owner_type, count(*) FROM pen_embeddings WHERE embedding IS NULL GROUP BY 1;
    SELECT owner_type, count(*) FROM ink_embeddings WHERE embedding IS NULL GROUP BY 1;
    -- task 7
    SELECT count(*) FILTER (WHERE pens_micro_cluster_id IS NULL) AS no_mc,
           count(*) FILTER (WHERE pens_micro_cluster_id IS NULL AND NOT EXISTS (SELECT 1 FROM pen_embeddings e WHERE e.owner_type = 'CollectedPen' AND e.owner_id = cp.id)) AS no_mc_no_row
    FROM collected_pens cp;
    SELECT count(*) FILTER (WHERE EXISTS (SELECT 1 FROM collected_inks ci WHERE ci.micro_cluster_id = mc.id)) AS with_inks_no_row FROM micro_clusters mc WHERE NOT EXISTS (SELECT 1 FROM ink_embeddings e WHERE e.owner_type = 'MicroCluster' AND e.owner_id = mc.id);
    SELECT count(*) FROM collected_inks ci WHERE NOT EXISTS (SELECT 1 FROM ink_embeddings e WHERE e.owner_type = 'CollectedInk' AND e.owner_id = ci.id);
    ```

    Expected on 2026-09-14: 9,370 / 453 / 5; 25; 69 (f,f) and 349-351 (t,f — 349 on 2026-09-12, 351
    on 2026-09-15); 14; 219; 606 + 1; 307; 1,189; 1,407 / 1,260; 2; 4. Expected after one full pass:
    0 / 433 / 5; 0; 0 (f,f) and 344 (t,f) — the 7 empty assigned model micro clusters whose model
    task 4 destroys are swept by task 3; 0; 0; 0; falling to ~0 within the hour; 0 / 0 once the jobs
    drain; 0; 0.

  - Prod run mechanics: prefer `fly console -a fountainpencompanion` (fly.toml:8 `console_command`
    starts a Rails console on an ephemeral machine with the app image and secrets, so it has
    `DATABASE_URL` and `REDIS_SIDEKIQ_URL` and does not steal a worker's CPU) and call the
    operations directly in the run order, printing each return value:
    `Pens::RemoveEmptyModelVariants.new.perform; Pens::RemoveEmptyMicroClusters.new.perform; Pens::RemoveEmptyModels.new.perform; Pens::RemoveEmptyModelMicroClusters.new.perform; Embeddings::RemoveOrphans.new(PenEmbedding).perform; Embeddings::RemoveOrphans.new(InkEmbedding).perform; Embeddings::ReenqueueNullVectors.new(PenEmbedding).perform; Embeddings::ReenqueueNullVectors.new(InkEmbedding).perform; Pens::ReclusterUnclusteredPens.new.perform; CreateMissingInkEmbeddings.new.perform`
    — or `Rails.application.load_tasks; Rake::Task["clusters:cleanup_stale"].invoke` in the same
    console. Alternative: `fly ssh console -a fountainpencompanion --select` onto a machine, then
    `cd /app && bundle exec rake clusters:cleanup_stale` (Dockerfile:15 `WORKDIR /app`). Run at a
    quiet hour; the deletes themselves take well under a minute (9,370 + 25 + 14 + 69 destroys).
  - Destroy semantics recap: `Pens::MicroCluster has_many :collected_pens` without `dependent:`
    (pens/micro_cluster.rb:2, FK 2384 raises on pens); `Pens::ModelVariant#destroy` nullifies its
    micro clusters and destroys its `pen_embedding` (model_variant.rb:2-7; FK
    db/structure.sql:2424 on `pens_micro_clusters.pens_model_variant_id` is satisfied by the
    nullify); `Pens::ModelMicroCluster#destroy` nullifies its variants (model_micro_cluster.rb:2-5,
    FK 2352); `Pens::Model#destroy` nullifies its mmcs (FK 2264) and destroys its embedding. After
    S06, all three also cascade-destroy `agent_logs` (none exist yet for pens).
    `Pens::UpdateModelVariant` returns early when `collected_pens` is empty (update_model_variant.rb:7),
    which is why the 25 variants kept stale names.
  - Sidekiq load of task 6 + 7: ~1,500 `FetchEmbedding` jobs (queue `low`, throttle 4) plus 15
    `RefreshPens` jobs (queue `default`, throttle 3, refresh_pens.rb:3-5) that fan out into 1,407
    `Pens::AssignMicroCluster` + 1,407 `Pens::UpdateMicroCluster` (default queue) and 1,407 more
    `FetchEmbedding` jobs: an hour or two of low-priority work, ~$0.01 of embeddings. Queues are
    strict priority `mailers > agents > default > low > reviews` (config/sidekiq.yml), so the `low`
    queue drains last. Enqueue rather than calling `EmbeddingsClient` inline so the console
    session is not held open. Side effects: some of the 1,407 pens land in existing assigned
    clusters (spelling rules) and trigger the normal variant-update cascade; the rest appear as
    ~1,400 new or joined pen micro clusters in the L1 backlog.
  - Dev-copy run: `docker-compose exec -T app bundle exec rake clusters:cleanup_stale`. The app
    container shares Redis with the dev `sidekiq` container, so the cleanup enqueues real
    `FetchEmbedding` jobs against the dev OpenAI key (`OPEN_AI_DEV_TOKEN` in `.env.local` until S18
    lands; ~3,000 embeddings, acceptable); or run the tasks except `embeddings:reenqueue_null_vectors`
    and `clusters:recluster_unclustered_pens` to skip the re-embed locally.
  - Prod risk low: no schema change; the PR deploys inert code; the data change happens when the
    owner runs the tasks. Rollback is the 39-row dump above; everything else regenerates.
- **Decisions applied.** Q8 (deletion list (c); assigned empties kept and filtered), Q9 (the
  single one-off re-save via `RefreshPens.perform_async(ids)` after S07).

### S09-embedding-search-hygiene — Cutoff/ef_search constants, narrowed selects, tier-3 N+1, first real-pgvector spec, public search request spec

- **Goal.** Behaviour-identical hygiene on the lines both the LLM migration and the pen clustering
  work will touch next. This is pure refactor: the public search results must be byte-identical
  before and after.
  1. **Replace six literal `0.6` cutoffs and two `SET hnsw.ef_search` literals with named
     constants.** Cutoffs live at `app/models/macro_cluster.rb:126,136,147` (ink) and
     `app/models/pens/model.rb:42,52,71` (pens) — each one a `.reject { |e| e.neighbor_distance > 0.6 }`
     call. Add `SIMILARITY_CUTOFF = 0.6` as a class constant on `MacroCluster` and on `Pens::Model`,
     and use it in all six `.reject` calls instead of the literal. Add `HNSW_EF_SEARCH = 200` on
     `MacroCluster` (used at macro_cluster.rb:108, `connection.execute("SET hnsw.ef_search = 200")`)
     and `HNSW_EF_SEARCH = 1000` on `Pens::Model` (used at pens/model.rb:33). Interpolate the
     constant into the `SET` string, e.g. `connection.execute("SET hnsw.ef_search = #{HNSW_EF_SEARCH}")`.
     These constants are wired to `config/llm.yml`-style config in a later step (S18); here they are
     still hard Ruby constants — do not add any config lookup in this PR.
  2. **Narrow the three tier queries in each search so the 1536-float vector column is never
     transferred.** The gem in use is `neighbor` 1.2.0 (`Gemfile.lock:309`). Its
     `nearest_neighbors` (`lib/neighbor/model.rb:139-140` in the gem) selects every column on the
     relation UNLESS the relation already has `select_values` set, in which case it keeps your
     existing select list and appends `... AS neighbor_distance`. So, in each of the six tier
     queries, insert `.select(:id, :owner_type, :owner_id)` **immediately before** the
     `.nearest_neighbors(...)` call in the chain:
     - `app/models/macro_cluster.rb` tiers at lines 120-125 (`macro_cluster_embeddings`), 128-133
       (`micro_cluster_embeddings`), 138-144 (`collected_ink_embeddings`); the `nearest_neighbors`
       calls themselves are at lines 123, 132, 143.
     - `app/models/pens/model.rb` tiers at lines 36-38 (`model_embeddings`), 44-48
       (`model_variant_embeddings`), 54-67 (`collected_pens_embeddings`); the `nearest_neighbors`
       calls themselves are at lines 38, 48, 67.
       Do **not** call `.reselect` after `.nearest_neighbors` — that throws away the gem-built
       `neighbor_distance` alias, and the subsequent `.order(:neighbor_distance)` (pens/model.rb:40,
       50, 69; macro_cluster.rb:124, 134, 145) would raise `ActiveRecord::StatementInvalid` (unknown
       column). Do not hand-write the `<->` distance SQL yourself. `.includes(:owner, ...)` on each
       query still works after narrowing, because `owner_type`/`owner_id` are among the selected
       columns (polymorphic `belongs_to` needs both). Nothing downstream reads `embedding.embedding`
       after these queries run (checked `Pens::Model.embedding_search` callers and
       `app/views/pen_models/index.html.slim`), so a narrowed row is safe; if some other caller tried
       to read `.embedding` on these rows it would raise `ActiveModel::MissingAttributeError`, which is
       the fast-fail signal that something reads the vector where it shouldn't.
  3. **Fix the tier-3 `owner.pen_model` N+1** in `Pens::Model.embedding_search`. Replace
     `includes(owner: :pens_micro_cluster)` at pens/model.rb:68 with
     `includes(owner: { pens_micro_cluster: { model_variant: { model_micro_cluster: :model } } })`.
     The chain this preloads is `CollectedPen#pen_variant` → `pens_micro_cluster` (belongs_to on
     `CollectedPen`, `collected_pen.rb:126` returns `pens_micro_cluster&.model_variant`) →
     `Pens::MicroCluster#model_variant` → `Pens::ModelVariant#model_micro_cluster` →
     `Pens::ModelMicroCluster#model` (`pens/model_variant.rb:34-36`, `def pen_model;
model_micro_cluster&.model; end`), which is exactly the chain `models.values.each { |data|
... result.pen_variant ... }` and the `owner.pen_model` calls elsewhere in `embedding_search`
     walk. Ink tier 3 (`macro_cluster.rb:144`) already preloads to the macro cluster and needs no
     change — only confirm it still does after the `.select` above (`includes(owner: {
micro_cluster: :macro_cluster })` stays untouched).
  4. Retrieval fixes land here too, but only on the already-decided threshold (section 5, "Resolved
     without asking"): item 4 is in scope iff S02 reported **model recall@20 < 0.9 or variant
     recall@20 < 0.8** over its assign cases in the top-20-by-distance view. At or above both, S02's
     verdict is "wrap as is" and this step is pure hygiene as written above; below either, S02's
     verdict is "retrieval work needed in S09" and this step's size is re-estimated upward. Read
     S02's recorded verdict before starting — it is a recorded number, not a judgement call.
- **Depends on.** S02 (its verdict on retrieval quality decides whether item 4 above adds scope).
- **Why here.** Shared by the pen tools (S10, which builds `PenSimilaritySearchTool` directly on
  top of `Pens::Model.embedding_search`) and by the embeddings migration cutover (S18 wires these
  constants to config, S24 adds the dual `embedding`/`embedding_v2` columns, S27 flips reads). Doing
  it once here, before either consumer exists, means neither S10 nor the migration touches these six
  query chains again. During the dual-column period (S24-S35) each of these searches would otherwise
  move up to roughly 2,400 rows carrying two 1536-float vectors apiece if the narrowed selects were
  not already in place.
- **Does not include.** Changing the cutoff _values_ (still 0.6 / 200 / 1000), changing the results
  a user sees from the public search, or changing the embedding column name (it stays hard-coded in
  `has_neighbors :embedding` on `PenEmbedding`/`InkEmbedding` and in the six `nearest_neighbors(:embedding,
...)` calls until S24 introduces per-column config entries). No decision-tool, agent, or worker code
  in this step.
- **Definition of done.**
  - `SIMILARITY_CUTOFF` and `HNSW_EF_SEARCH` constants exist on both `MacroCluster` and
    `Pens::Model` and are used in all eight call sites listed above (six `.reject`, two `SET`). The
    `.first(200)` / `.first(2000)` tier ROW LIMITS (macro_cluster.rb:125,135,146;
    pens/model.rb:41,51,70) stay as literals and must NOT be replaced — on `MacroCluster`
    `HNSW_EF_SEARCH` happens to be 200 as well, and substituting the constant into a row limit would
    change behaviour this step forbids changing.
  - Both searches return byte-identical results to before the change on the dev copy for a handful
    of manually chosen queries (spot check pasted into the PR description — e.g. run
    `Pens::Model.embedding_search("Lamy Safari")` and `MacroCluster.embedding_search("Pilot Iroshizuku")`
    before and after and diff the returned ids/distances).
  - `spec/models/pens/model_spec.rb` and `spec/models/macro_cluster_spec.rb` gain the repo's first
    specs that exercise `nearest_neighbors` against real vectors (today both files only assert the
    blank-query short circuit: `model_spec.rb:40-47`, `macro_cluster_spec.rb:255-261` — see recipe
    below).
  - New request spec `spec/requests/pen_models_controller_spec.rb` for the public search — none
    exists today (`grep -rn "pen_models\|PenModelsController" spec/` returns nothing). Cover
    `GET /pen_models?q=...` (route at `config/routes.rb:76`, `resources :pen_models, only: %i[index
show]`) with `allow_any_instance_of(EmbeddingsClient).to receive(:fetch).and_return(vector)` and
    real `PenEmbedding` rows for a `Pens::Model` and a `Pens::ModelVariant`; assert the response
    renders the model row and its variant rows (the view reads `data.owner.pen_model` and
    `data.model_variants`, `app/views/pen_models/index.html.slim:13-27`).
  - `bundle exec rspec spec/models/pens/model_spec.rb spec/models/macro_cluster_spec.rb
spec/requests/pen_models_controller_spec.rb` green with no new deprecation warnings (per
    CLAUDE.md, check RSpec output for new warnings, not just failures).
  - Manual verification in dev: open `https://app.fountainpencompanion.orb.local/pen_models?q=lamy`
    and confirm results and their variant lists render exactly as before the change.
- **Rollback.** No schema or data change; a straight `git revert` of the merge commit is sufficient
  if a regression appears (prod risk: low — behaviour-identical refactor of a read path).
- **Decisions applied.** None — this step carries no owner decision beyond the general rules
  (renumbering). The DIGEST's "refactor before the agent or wrap as is" is settled by build order,
  not by a numbered decision: both S10 (pen tools) and the embeddings migration need these
  constants and narrowed selects, so it is done once here, and the N+1 fix rides along because it
  touches the same lines.
- **Implementation notes.**
  - **Spec recipe for the real-vector specs.** `spec/factories/pen_embeddings.rb:1-3` is currently an
    empty factory (`factory :pen_embedding do end` — no owner, content, or embedding set), and two
    random 1536-dimensional vectors have cosine distance ≈1.0, so randomly generated rows would all
    be dropped by the 0.6 cutoff and prove nothing. Instead build fixed vectors: a query vector
    `query = [1.0, 0.0, *Array.new(1534, 0.0)]`, a near row `near = [0.9, 0.1, *Array.new(1534,
0.0)]` (cosine distance ≈0.01, kept), and a far row `far = [0.0, 1.0, *Array.new(1534, 0.0)]`
    (cosine distance ≈1.0, rejected by the 0.6 cutoff). Stub the client with
    `allow_any_instance_of(EmbeddingsClient).to receive(:fetch).and_return(query)`. Create embedding
    rows directly. Note the `after_save` hook (pen_embedding.rb:12-19) DOES fire on create — the
    `content` attribute changes from nil — and enqueues `FetchEmbedding`; nothing is bypassed. It is
    harmless only because Sidekiq runs in `:fake` mode in specs (spec/rails_helper.rb:8,24), so the
    stored vector is never overwritten; do not assert on total Sidekiq job counts in these examples:
    ```ruby
    model = create(:pens_model)
    PenEmbedding.create!(owner: model, content: "x", embedding: near)
    other = create(:pens_model)
    PenEmbedding.create!(owner: other, content: "y", embedding: far)
    ```
    Assert: `Pens::Model.embedding_search("query").first.owner` equals the near model and the far
    model is absent from the result. Do NOT try to prove the narrowed select through that result
    object: `embedding_search` returns `OpenStruct.new(distance:, results:)` values whose `.owner` is
    the OWNER RECORD (a `Pens::Model`), not the embedding row (pens/model.rb:73-92), so
    `.owner.attributes` can never contain an `"embedding"` key whether the select was narrowed or
    not — the assertion would pass vacuously. Prove the narrowing one of two ways instead: assert
    directly on the tier relation,
    `expect(PenEmbedding.where(owner_type: "Pens::Model").select(:id, :owner_type, :owner_id).nearest_neighbors(:embedding, query, distance: "cosine").first.attributes.key?("embedding")).to be(false)`,
    or wrap the `embedding_search` call in an
    `ActiveSupport::Notifications.subscribe("sql.active_record")` block and assert that no emitted
    SELECT against `pen_embeddings` lists the `embedding` column. Repeat for `InkEmbedding` /
    `MacroCluster`, with one difference: `MacroCluster.embedding_search` returns
    `OpenStruct.new(distance:, cluster:)` (macro_cluster.rb:149,161) — there is no `.owner` at all,
    so assert `MacroCluster.embedding_search("query").first.cluster`. There is no `ink_embedding`
    factory today, so either `InkEmbedding.create!(owner: ..., content: ..., embedding: ...)`
    directly or add a minimal one (the embeddings bench in S23 wants one anyway; adding it here is
    fine and saves that step a trivial addition — note it in the PR description either way).
  - `SET hnsw.ef_search` is per-connection and leaks into the pooled connection (confirmed in the
    pens-domain subsystem map). Decided for this step: keep
    `connection.execute("SET hnsw.ef_search = #{HNSW_EF_SEARCH}")` and add a one-line comment
    documenting the leak, so a future reader isn't surprised by a connection carrying a non-default
    `ef_search` value. Do NOT switch to `SET LOCAL` inside an explicit transaction here: wrapping the
    three tier queries in a transaction changes read behaviour on a public read path, which this
    step's "Does not include" forbids. If the `SET LOCAL` form is wanted, it is a follow-up PR of its
    own.
  - Factories to use in the new specs: `:pens_model`, `:pens_model_variant`,
    `:pens_model_micro_cluster`, `:pens_micro_cluster`, `:collected_pen` (all under
    `spec/factories/pens/*.rb` and `spec/factories/collected_pen.rb`).
  - When narrowing the pen tier-3 query specifically, re-check that `.includes(owner: { pens_micro_cluster:
{ model_variant: { model_micro_cluster: :model } } })` combined with `.select(:id, :owner_type,
:owner_id)` on `PenEmbedding` does not accidentally select columns off the _included_ associations
    (Rails `includes` + explicit `select` on the base relation only narrows the base table; this is
    expected and correct — the associations still load fully, only `PenEmbedding` itself is narrowed).

### S10-pen-tools — PenSimilaritySearchTool (top-K variants per model), PenFullTextSearchTool, PenWebSearchTool, pen KnownBrand (EXISTS over assigned clusters)

- **Goal.** Four standalone, testable `RubyLLM::Tool` classes under `app/agents/tools/`, built and
  spec'd before `PenVariantClusterer` (S11) exists. All four mirror an existing `Tools::Ink*Tool` /
  `InkClusterer::KnownBrand` counterpart; copy structure, not behaviour, from those files.

  1. **`Tools::PenSimilaritySearchTool`** (`app/agents/tools/pen_similarity_search_tool.rb`) wraps
     `Pens::Model.embedding_search` (the narrowed/constant version from S09). Take the top ~20
     models by distance (272 models fall under the 0.6 cutoff for a common query on prod, per the
     pens-domain probe). `Pens::Model.embedding_search` returns `OpenStruct`s whose `.model_variants`
     is `[]` for a tier-1 hit (a model matched directly) — tiers 2 and 3 explicitly exclude models
     already found in tier 1 (`pens/model.rb:47,65`), so a model found via its own embedding never
     gets its variants attached by `embedding_search` itself. This tool must load variants itself:
     for each returned `data`, call `data.owner.pen_model.model_variants` (`data.owner` is a
     `Pens::Model`, `Pens::ModelVariant`, or `CollectedPen`; `owner.pen_model` works on all three —
     `pens/model.rb:114` returns `self`, `model_variant.rb:34` returns
     `model_micro_cluster&.model`, `collected_pen.rb:130` returns `pen_variant&.pen_model`).
     Group and cap (Q17): list the top `VARIANTS_PER_MODEL` variants per model, ordered by
     micro-cluster count **descending, then `id` ascending** (the secondary key makes the order
     deterministic for specs and for S21's bench), then (if more exist) one trailing line reading exactly
     `"and N more variants (use pen_full_text_search)"`. `VARIANTS_PER_MODEL` is a **public class
     constant on the tool** (`VARIANTS_PER_MODEL = 15` — Q17 leaves K to the implementer and
     suggests 15; 15 is adopted; do not make this a private constant, S21's bench exporter reads it
     to classify capped cases as their own stratum). Compute the micro-cluster count for all
     candidate variants in **one grouped query**, never one query per variant:
     `Pens::MicroCluster.where(pens_model_variant_id: variant_ids).group(:pens_model_variant_id).count`
     — build the `variant_ids` array across every returned model before running this single query,
     then look counts up from the resulting hash when rendering each model's variant list.
     **`micro_cluster_count` is the UNSCOPED membership count** — `.with_collected_pens` is NOT
     applied — so the 433 empty ASSIGNED spelling-rule clusters that survive S08 are included. Same
     convention in both pen tools, and the same one S21 uses for its sibling rule
     (`Pens::MicroCluster.where(pens_model_variant_id: v.id).count > 1`, counted unscoped because Q8
     keeps those rows as siblings). The two must agree, or S21's capped-stratum flagging disagrees
     with the ranking the model actually sees. Render
     each model as `{brand:, model:, distance:, variants: [{id:, name:, micro_cluster_count:}, ...],
more_variants_note: "and N more..." or nil}`; `name` is `Pens::ModelVariant#name`
     (`model_variant.rb:37-40`, joins brand/model/color/material/trim_color/filling_system).
  2. **`Tools::PenFullTextSearchTool`** (`app/agents/tools/pen_full_text_search_tool.rb`) wraps
     `Pens::ModelVariant.search(query)` (`model_variant.rb:18-28`). `search` returns the **whole
     class** (i.e. `Pens::ModelVariant.all`, ~7.1k rows on prod) when `query` is blank — guard blank
     input yourself and return an error string ("Please supply a non-blank search string.") instead
     of calling `search` with a blank value. Cap the result at 20 variants, but ORDER FIRST: `search`
     is a grouped relation with no `ORDER BY` (`model_variant.rb:18-28`), so a bare `.limit(20)`
     returns an arbitrary 20 and the tool's output is not reproducible for specs or for S21's bench.
     Order the matched variants by micro-cluster count **descending, then `id` ascending** — the same
     order the similarity tool uses — and take the first 20. This is what makes Q17's escape hatch
     work: the full-text tool is what reaches the variants hidden behind the similarity tool's "and N
     more" line, and for the models this step itself names (Jinhao 82: 110 variants; Lamy Safari: 76,
     57 of them spelled exactly `Safari`, prod-data-check §pen models) an unordered slice would never
     reach them. A single common term like "Safari" is broad — it matches
     `CONCAT(collected_pens.brand, model, color, material) ILIKE '%Safari%'` over a join to collected
     pens — and an uncapped result would blow the prompt budget. Render each matched variant as `{id:, name:, model: pen_model&.name,
micro_cluster_count:}`; `pen_model` may be `nil` for a variant that has no model micro cluster
     yet (`model_variant.rb:34-36`, `model_micro_cluster&.model`), so guard the `&.name` call.
     `micro_cluster_count` uses the same one-grouped-query technique as the similarity tool, and the
     same UNSCOPED convention (do not call `.micro_clusters.count` per variant in a loop, and do not
     apply `.with_collected_pens`).
  3. **`Tools::PenWebSearchTool`** (`app/agents/tools/pen_web_search_tool.rb`) mirrors
     `Tools::InkWebSearchTool` (`app/agents/tools/ink_web_search_tool.rb`) almost line for line, with
     `" fountain pen"` appended to the query instead of ink's `" ink"` (`ink_web_search_tool.rb:16`,
     `search_query = "#{search_query} ink"`). Same constructor shape
     (`attr_accessor :agent_log; def initialize(agent_log) ... end`), same nested
     `GoogleSearchSummarizer.new(search_query, parent_agent_log: agent_log).perform` call, same
     return-string wrapper (`"The search results for '#{search_query}' are:\n #{search_summary}"`).
     Keep the tool's callable name identical to the ink one: override `def name = "search_web"`.
     Without this override, the auto-naming in `config/initializers/ruby_llm.rb:8-22` would turn
     `Tools::PenWebSearchTool` into `pen_web_search`, but `PenVariantClusterer`'s system directive
     (S11) refers to searching the web generically by the tool name `search_web`, matching the ink
     prompt's wording — keep both prompts and both tool names consistent.
  4. **Pen `KnownBrand`** lives at `app/agents/tools/pen_known_brand_tool.rb` as
     `Tools::PenKnownBrandTool`. Constructed with a `Pens::MicroCluster`
     (`attr_accessor :micro_cluster; def initialize(micro_cluster) ... end`), same shape as
     `InkClusterer::KnownBrand` (`app/agents/ink_clusterer.rb:100-112`). Implementation is **one SQL
     query** (Q18 — this is the decided mechanism, not an option to weigh):
     ```ruby
     def execute
       known =
         Pens::MicroCluster
           .where(simplified_brand: micro_cluster.simplified_brand)
           .where.not(pens_model_variant_id: nil)
           .exists?
       if known
         "Yes, the pen brand is known."
       else
         "No, the pen brand is not known. Use the search function to double check for spelling mistakes, though!"
       end
     end
     ```
     This checks other micro clusters sharing the same `simplified_brand` that are already assigned
     to a model variant (600 distinct simplified brands are represented among assigned pen micro
     clusters on prod). Give the tool an explicit `def name = "known_brand"`: Q18 says the pen tool
     mirrors the ink `KnownBrand`, whose effective name is exactly `known_brand` (the initializer at
     `config/initializers/ruby_llm.rb:8-22` demodulizes `InkClusterer::KnownBrand`), and the
     auto-derived name here would otherwise be `pen_known_brand`. S11's system directive names the
     tool `known_brand` and nothing else. Remember
     `Pens::AssignMicroCluster#handle_synonyms!`
     (`app/workers/pens/assign_micro_cluster.rb:59-62`) already folds
     `namiki→pilot` and `capless→vanishingpoint` into `simplified_brand`/`simplified_model` before a
     micro cluster is created, so this query is comparing already-normalized brand strings, not raw
     user input.
     The two string-returning tools (`PenWebSearchTool`, `PenKnownBrandTool`) mirror the tone and
     structure of `ink_clusterer.rb:115-119`'s "check for spelling mistakes" hint style: plain,
     imperative, addressed to the model. The two search tools (`PenSimilaritySearchTool`,
     `PenFullTextSearchTool`) return ARRAYS OF HASHES like their ink counterparts
     (app/agents/tools/ink_similarity_search_tool.rb:9-19, ink_full_text_search_tool.rb:9-13), not
     strings.

- **Depends on.** S09 (the constants and narrowed selects that `PenSimilaritySearchTool` builds on —
  S02's retrieval verdict flows through S09), S03 (the stale-docs fix corrects the tool-writing
  templates in CLAUDE.md and `spec/agents/README.md` that this step's specs and code follow).
- **Why here.** Tools are standalone and independently testable before the agent (S11) exists; their
  output shape and size set the prompt token budget and per-run cost that S11's prompt and S20/S21's
  bench harness both depend on. Building and pricing them first means S11 is wiring, not design.
- **Does not include.** Any decision tool (`AssignToVariant`, `CreateNewVariant`, `IgnorePen`,
  `HandOverToHuman` — all S11), any change to `Pens::Model.embedding_search`'s result shape (S09
  already finished that), and no agent, worker, or prompt-assembly code.
- **Definition of done.**
  - One spec file per tool under `spec/agents/tools/`, following the ink tool spec pattern: assert
    `.name` and the description string **first**, exactly as
    `spec/agents/tools/ink_similarity_search_tool_spec.rb:46-48` (name) and `:50-55` (description)
    do — or see `spec/agents/tools/ink_web_search_tool_spec.rb:7-15`, which shows both back to back
    (a plain `description`
    class-macro call and the auto/explicit `name` are both externally visible contract, and a typo in
    either silently breaks the agent's tool-calling — assert them explicitly, not just via
    `respond_to?`).
  - `PenWebSearchTool` spec mirrors `spec/agents/tools/ink_web_search_tool_spec.rb:17-28`:
    `instance_double(GoogleSearchSummarizer, perform: "some result")` and
    `expect(GoogleSearchSummarizer).to receive(:new).with("<query> fountain pen", parent_agent_log:
agent_log).and_return(the_double)`. Serper (the underlying search API `GoogleSearchSummarizer`
    calls) is never reached in this spec, so no HTTP stub for it is needed — only the
    `GoogleSearchSummarizer.new` double.
  - `PenKnownBrandTool` spec: three cases — brand known via an assigned micro cluster with the same
    `simplified_brand` (returns the "Yes" string), brand appears only on **unassigned** micro
    clusters (still returns "No" — the `.where.not(pens_model_variant_id: nil)` clause excludes
    them), and no matching `simplified_brand` at all (returns "No").
  - `PenFullTextSearchTool` spec: blank query returns the guard error string without calling
    `Pens::ModelVariant.search`; a query matching more than 20 variants is capped at 20 and the 20
    returned are the highest-micro-cluster-count matches, tie-broken by `id` (assert the order, not
    just the size); a variant with no `model_micro_cluster` renders `model: nil` without raising.
  - `PenSimilaritySearchTool` spec proves, with a manual `ActiveSupport::Notifications` subscriber
    (or an equivalent query counter) around `.count`/`.exists?` calls, that the number of SQL queries
    for computing variant + micro-cluster counts does **not** grow with the number of variants
    returned — i.e. it stays at one grouped `.count` call regardless of whether a model has 3 or 110
    variants. Also assert the `"and N more variants (use pen_full_text_search)"` line appears only
    when a model has more than `VARIANTS_PER_MODEL` variants, and is absent otherwise.
  - A sample prompt rendering for Jinhao 82 (110 variants under one model on prod) and Lamy Safari
    (76 variants under that model, 57 of them spelled exactly `"Safari"`) checked into the PR
    description alongside
    its estimated token count (rough token count is fine — a `.length / 4` estimate or an actual
    tokenizer call, either is acceptable; the point is a number the reviewer can sanity-check S11's
    prompt budget against).
  - `bundle exec rspec spec/agents/tools/pen_similarity_search_tool_spec.rb
spec/agents/tools/pen_full_text_search_tool_spec.rb spec/agents/tools/pen_web_search_tool_spec.rb
spec/agents/tools/pen_known_brand_tool_spec.rb` green, `yarn lint` unaffected (Ruby-only PR).
- **Rollback.** No schema or data change; these are new files with zero callers until S11 merges, so
  a `git revert` is trivially safe. Prod risk: none.
- **Decisions applied.**
  - **Q17** — `PenSimilaritySearchTool` lists the top `VARIANTS_PER_MODEL` (public constant, 15
    suggested and adopted as the implementer's choice) variants per model by micro-cluster count
    descending, plus an "and N more" trailing line; the full-text tool is what finds the rest. The
    bench (S21) reports cases whose expected variant fell under the cap as their own stratum,
    reading this same constant — do not make it private or rename it without updating S21.
  - **Q18** — Pen `KnownBrand` is exactly one `EXISTS`-shaped query,
    `Pens::MicroCluster.where(simplified_brand: mc.simplified_brand).where.not(pens_model_variant_id:
nil).exists?`, mirroring the ink `KnownBrand` tool's structure. The `pg_trgm`-similarity option
    and the "precompute all brands' simplified names once per tool instance" option from the v1 plan
    are both **not used** — this is the sole decided mechanism. S11's system directive separately
    tells the model that an unknown-brand result may mean a misspelling, and to double-check spelling
    or search the web before concluding the brand is genuinely new.
- **Implementation notes.**
  - Spec pattern for the similarity tool: doubles alone cannot answer the variant-loading and
    count-grouping queries realistically, so build **real** rows through the factory chain
    `pens_model -> pens_model_micro_cluster(model:) -> pens_model_variant(model_micro_cluster:) ->
pens_micro_cluster(model_variant:)`, then stub only the embedding search itself:
    ```ruby
    allow(Pens::Model).to receive(:embedding_search)
      .and_return([OpenStruct.new(distance: 0.1, owner: model, model_variants: [])])
    ```
    so that `owner.pen_model` (`pens/model.rb:114-116` returns `self`) and the subsequent
    variant/count queries hit the real test database. A real `embedding_search` call would hit
    `/v1/embeddings` via `EmbeddingsClient`, and WebMock would raise inside the tool call loop if it
    were reached unstubbed — stub at the `Pens::Model.embedding_search` boundary, not lower.
  - Result shape to mirror everywhere in this step: `distance`, `owner` (a `Pens::Model`,
    `Pens::ModelVariant`, or `CollectedPen` — `owner.pen_model` works on all three:
    `pens/model.rb:114`, `model_variant.rb:34`, `collected_pen.rb:130`), `results`, `model_variants`
    — this is the `OpenStruct` shape `Pens::Model.embedding_search` builds internally
    (`pens/model.rb:73-90`).
  - Tool naming mechanics: the initializer (`config/initializers/ruby_llm.rb:8-22`) derives a tool's
    callable name from its class name by stripping the `Tools::` prefix and `Tool` suffix and
    underscoring — `Tools::PenSimilaritySearchTool` → `pen_similarity_search`,
    `Tools::PenFullTextSearchTool` → `pen_full_text_search`, `Tools::PenWebSearchTool` would become
    `pen_web_search` without the explicit override (hence `def name = "search_web"`). The
    description string for `PenWebSearchTool` should literally say `" fountain pen"` is appended,
    matching the ink tool's description text convention, because the spec asserts the description
    string verbatim (per the ink tool spec pattern above) — do not phrase it as "appends the word
    pen" or similar; match the ink tool's exact style ("The word '...' is automatically appended to
    the search query.").
  - Cost/sizing input to record in the PR description: prod has 286 `pens_brands`; the largest
    variant lists under one model are Jinhao 82 (110), Sailor Pro Gear Slim (105), Kaweco Sport (81),
    Sailor Pro Gear (77), Lamy Safari (76).
  - Factories available: `:pens_model`, `:pens_model_variant`, `:pens_model_micro_cluster`,
    `:pens_micro_cluster`, `:pens_brand`, `:collected_pen` (all under `spec/factories/pens/*.rb` and
    `spec/factories/collected_pen.rb`); no `pens_model_variant` currently sets
    `model_micro_cluster:`, so pass it explicitly in every spec that needs `pen_model` to resolve
    (`create(:pens_model_variant, model_micro_cluster: create(:pens_model_micro_cluster, model:
create(:pens_model)))`).

### S11-pen-agent-decide — PenVariantClusterer: config/llm.yml entry on the S01 DO model, prompt, decision tools with the create-tool duplicate check, decide, guards, empty-cluster marker log

- **Goal.** `app/agents/pen_variant_clusterer.rb`, a new class `PenVariantClusterer` including
  `RubyLlmAgent`, structured from day one as `perform = guards -> decide(agent_log:) ->
waiting_for_approval!` (this is the shape S19 later retrofits onto `InkClusterer`; the pen agent
  gets it natively so S20's bench runner and S25's shadow worker can call `decide` on it without any
  later re-plumbing).

  **There is no `MODEL_ID` constant on this class (Q32).** Under Q32 the pen agents are born as
  DigitalOcean agents from their first line of code — there is no OpenAI default and no later "pen
  cutover" PR. Instead, this PR adds a `PenVariantClusterer` entry to `config/llm.yml` (the file S04
  introduces) under both the `production:` and `development:` sections:

  ```yaml
  PenVariantClusterer:
    provider:
      openai # DO's OpenAI-compatible endpoint; RubyLLM needs provider: openai
      # even though the backend is DigitalOcean (assume_model_exists needs it)
    model: <the model id S01's spike picked as the pen agents' starting model>
    api_base: https://inference.do-ai.run/v1
    api_key_env: DO_INFERENCE_TOKEN
    assume_model_exists: true
    openai_use_system_role: <whatever value S01's spike determined works on DO>
  ```

  The `test:` section of `config/llm.yml` resolves **every** class to `https://api.openai.com/v1`
  with today's per-agent model ids; `PenVariantClusterer`, which has no incumbent OpenAI model, gets
  the test `default` model id (this is S04's decided
  design: the `test:` section exists specifically so the 173 existing literal `api.openai.com/v1`
  WebMock stubs across the spec suite keep working unchanged). So this class's specs stub the exact same URL every other
  agent spec stubs, and assert the requested model **through the config accessor**
  (`LlmConfig.for("PenVariantClusterer").model` or equivalent — use whatever accessor name S04
  actually defines), never a literal model id string. The class reads its config entry the same way
  every other agent does post-S04 — do not hand-roll a separate config path for this one agent.
  The Fly secret `DO_INFERENCE_TOKEN` must already exist (S00 sets it) before this PR merges,
  because a console call right after merge (`RunAgent.perform_async("PenVariantClusterer", id)`,
  `app/workers/run_agent.rb:8-10`) already calls DO with the prod key — secrets are read at call
  time, not at boot, so a missing secret fails the first run, not app startup.

  **Four halting decision tools**, class names exactly `AssignToVariant`, `CreateNewVariant`,
  `IgnorePen`, `HandOverToHuman`, nested inside `PenVariantClusterer` exactly as `InkClusterer`
  nests `AssignToCluster`/`CreateNewCluster`/`IgnoreInk`/`HandOverToHuman`
  (`app/agents/ink_clusterer.rb:32-99`). Copy `InkClusterer::BaseTool`
  (`ink_clusterer.rb:5-30`) into a `PenVariantClusterer::BaseTool` with the same shape:
  `attr_accessor :micro_cluster, :agent_log`, constructor taking both, a private
  `missing_explanation?`/`missing_explanation_error` pair, a private `micro_cluster_str` (the ink
  one is at `ink_clusterer.rb:27-29` and calls `micro_cluster.all_names`; `Pens::MicroCluster` has
  NO `name`/`all_names` helper, so build the pen version as
  `"Pens::MicroCluster(#{micro_cluster.id})<#{...}>"` from S06's tuple helper — do not call
  `micro_cluster.all_names`), and `update_extra_data(data)` =
  `agent_log.update!(extra_data: (agent_log.extra_data || {}).merge("action" => name, **data))` —
  the initializer (`config/initializers/ruby_llm.rb:8-22`) derives the tool-call names
  `assign_to_variant` / `create_new_variant` / `ignore_pen` / `hand_over_to_human` from these class
  names automatically, and `BaseTool#update_extra_data` is what stores `name` (the tool call name) as
  the `"action"` string that the admin stats key on (mirrors `ink_clusterer.rb:23-25`).
  `HandOverToHuman` takes no params and defines `execute` with no arguments (mirrors
  `ink_clusterer.rb:91-98`).

  Fixed `extra_data` keys, shared with S12 (apply) and S14 (admin): `action`, `variant_id` (assign
  only), `msg`, `explanation_of_decision`, `manual_rejection_note`, `auto_rejection`. No tool writes
  anything else — in particular `CreateNewVariant` stores no tuple columns (see below), because S12
  re-derives them at approval time. `msg` is on the list because every ink tool writes it
  (`ink_clusterer.rb:45,65,81,92`) and the pen tools copy that shape.

  **`AssignToVariant`**: `param :variant_id, type: "integer", ...`, `param
:explanation_of_decision, ...`; looks up `Pens::ModelVariant.find_by(id: variant_id.to_i)`,
  returns the ink-style "please supply a valid id" error string if not found, otherwise
  `update_extra_data` with `"variant_id" => variant.id` and halts. Mirrors `AssignToCluster`
  (`ink_clusterer.rb:32-51`) with `cluster_id`→`variant_id` and `MacroCluster`→`Pens::ModelVariant`.

  **`IgnorePen`**: mirrors `IgnoreInk` (`ink_clusterer.rb:73-88`) exactly, no params beyond
  `explanation_of_decision`.

  **`CreateNewVariant` — this tool has behaviour with no ink-side analogue (Q20), but exactly the
  same NO-DATA-PARAMS shape as `InkClusterer::CreateNewCluster` (`ink_clusterer.rb:54-69`).** Its
  only param is `explanation_of_decision`. The plan is explicit — "`create_new_variant(explanation)`
  — no attributes, see \"derived\" above" (docs/pen-clustering-plan.md, PenVariantClusterer tool
  list) — because variant attributes are **derived, not authored**: `Pens::UpdateModelVariant`
  overwrites brand/model/color/material/trim/filling with the most common values from the collected
  pens on every update, so "the agent therefore only has to decide assign/create/ignore, not to
  author canonical names". Do not add `param :brand` / `:model` / `:color` / `:material` /
  `:trim_color` / `:filling_system`; the six-tuple is the storage and unique-index shape
  (db/structure.sql:1715), not something the model supplies.

  Before halting, `execute` must **check for an identical existing variant and, if one is found,
  RETURN a message telling the model to assign to it instead of halting** — this is the entire, sole
  mechanism the owner decided on (Q20; there is no separate "collision options" list to weigh, this
  is it). The tuple it checks against is DERIVED inside `execute` from the micro cluster (S06's
  `collected_pen_tuples`, most common row), never taken from arguments, so the check tests the row
  S12's `approve!` would actually create:

  ```ruby
  def execute(explanation_of_decision:)
    return missing_explanation_error if missing_explanation?(explanation_of_decision)

    # NOT NULL DEFAULT '' on color/material/trim_color/filling_system (db/structure.sql:926-929),
    # and the UNIQUE index (db/structure.sql:1715) is over the normalised six-tuple, so a nil or
    # missing value must become "" or find_by searches `color IS NULL` and never matches
    # the existing `color = ''` row — which would defeat the whole Q20 duplicate check and make
    # S12's `create!` raise NotNullViolation instead of the RecordNotUnique it handles.
    row = micro_cluster.collected_pen_tuples(limit: 1).first
    tuple =
      Pens::MicroCluster::TUPLE_COLUMNS.to_h { |c| [c.to_sym, row.public_send(c).to_s.strip] }
    existing = Pens::ModelVariant.find_by(tuple)
    if existing
      return "An identical variant already exists: id #{existing.id}, name '#{existing.name}'. " \
             "Use assign_to_variant(variant_id: #{existing.id}) instead of creating a duplicate."
    end

    update_extra_data(
      "msg" => "Creating new variant for #{micro_cluster_str}",
      "explanation_of_decision" => explanation_of_decision
    )
    halt "Creating new variant"
  end
  ```

  The tuple is NOT written into `extra_data`. S12 re-derives it from the same helper at approval
  time, which is what the plan's `approve!` rule says ("create → `Pens::ModelVariant.create!` from
  the micro cluster's most common values"), and is what S12 already assumes this tool does.

  Returning a plain string (not calling `halt`) sends this message back to the LLM as a tool result
  and the conversation loop continues — the model is expected to call `assign_to_variant` next.
  This tool does **not** create a `Pens::ModelVariant` row itself (same as ink's `CreateNewCluster`,
  which only stashes intent in `extra_data`); the actual `Pens::ModelVariant.create!` happens at
  approval time in S12, which is also where the _second_ half of Q20 (a collision that reaches
  `approve!` itself — a race between decision and approval, or a bypassed tool check) is handled by
  refusing and rejecting the log. This step only implements the decide-time check.

  **System directive** (`SYSTEM_DIRECTIVE` constant, mirrors `ink_clusterer.rb`'s heredoc STRUCTURE
  only — the ink directive's content does not carry over) encodes three things.

  1. **The decided ignore policy, written out (pen decision 3).** Do not "adapt the ink directive's
     custom-mix and unidentified-ink guidance": the ink custom-mix clause
     (`ink_clusterer.rb:153-155`) has no pen analogue and must not be carried over. Ignore: nib units
     and bare nibs; a brand or model that literally says unknown or is a placeholder ("don't know",
     "?"); clones, fakes and unbranded copies; non-fountain-pen products (pencils, ballpoints,
     rollerballs, inkwells, accessories); kit pens and self-made one-offs (products of small makers
     are real pens); vintage pens whose model is genuinely unknown. Plus the two explicit
     NON-ignore rules the decision states: calligraphy pens such as the Pilot Parallel ARE fountain
     pens and must be clustered, not ignored; and a micro cluster that is merely malformed (a
     placeholder colour on a real pen) is ASSIGNED, not ignored. And the escape hatch: an obscure
     but real name goes to `hand_over_to_human`, never `ignore_pen`, because ignoring is permanent
     and hand-over is not.
  2. **The variant definition (pen decision 8), stated as the decision states it.** A variant is
     **the model in one colour or finish**. Material and filling system NEVER split a variant — they
     are weak confirming signals, and users spell them inconsistently ("C/C", "Converter",
     "Cartridge/Converter" all live in one Lamy Safari variant today). Trim colour is the one
     exception: when the same colour is a documented, separately sold version with different trim
     (gold vs silver), it may be its own variant. Otherwise same model plus same colour means the
     same variant. Nib is not part of a variant. Year, "LE"/"SE" and edition markers are noise and
     are ignored when matching. Do NOT present the six-tuple to the model as the definition of a
     variant: the six-tuple is the storage and unique-index shape (db/structure.sql:1715), nothing
     more. A _model_ is the brand+model pair a variant belongs to; this class only ever
     creates/assigns _variants_, never models or model micro clusters directly.
  3. **(Q18) An explicit sentence telling the model that an unknown-brand result from `known_brand`
     may mean a misspelling, not a genuinely new brand, and that it should double-check spelling or
     search the web before treating a brand as new** — the tool is named `known_brand` and nothing
     else (S10 gives it an explicit `def name = "known_brand"`). This sentence has no ink-side
     precedent to copy verbatim; write it fresh, matching the tone of the existing "few things to
     keep in mind" list in `ink_clusterer.rb:160-166`.

  **User prompt**: built from the S06 tuple helper (`Pens::MicroCluster`'s `all_names`-shaped
  method — see S06's Implementation notes for its exact query) as JSON, including the cluster's own
  `id` (so the admin "Search" button and the bench can key on it directly, mirroring
  `ink_clusterer.rb:376-385`'s `micro_cluster_data` shape which already includes `id`), plus
  `processed_tries_data` built from previously rejected logs on the same micro cluster including
  their `manual_rejection_note` (mirror `ink_clusterer.rb`'s `processed_tries_data` /
  `processed_try_entry` / `action_summary` private methods almost verbatim, substituting the pen
  action names `assign_to_variant`/`create_new_variant`/`ignore_pen` for the ink ones). The tuple
  cap is a **public class constant** `PROMPT_TUPLE_CAP = 40` on `PenVariantClusterer`, plus a
  trailing "and N more" line when the tuple helper's result is capped. On the current unassigned
  backlog no truncation actually triggers (the largest unassigned cluster today has 39 pens, 14
  clusters have more than 10 distinct tuples, the max is 36 distinct tuples) — but S21's bench runs
  `decide` against _human-assigned_ clusters for leave-one-out cases, and 67-69 of those have more
  than 40 distinct tuples (max 251-253; the single largest holds 832 pens), so S21's case exporter
  must read this same `PROMPT_TUPLE_CAP` constant and report capped cases as their own bench
  stratum — keep the constant public and named exactly `PROMPT_TUPLE_CAP` so S21 can reference it
  without duplicating the number.

  **`decide(agent_log:)`** is the side-effect-free entry point the bench (S20/S21) and, if ever
  needed, a shadow worker call directly, bypassing `perform`'s guards and state transition:

  ```ruby
  def decide(agent_log:)
    raise "chat already built" if @chat
    self.agent_log_id = agent_log.id
    @agent_log = agent_log
    ask!(user_prompt)
    agent_log.reload.extra_data
  end
  ```

  It must run **before** the first call to `chat` — `chat` is memoized (`@chat ||= build_chat`,
  `ruby_llm_agent.rb:12-14`) and `build_chat` (`ruby_llm_agent.rb:85-92`) captures `agent_log` into
  the tool instances and calls `restore_transcript`, which reads `agent_log.transcript`
  (`ruby_llm_agent.rb:170-186`) — so `decide` must set `agent_log_id`/`@agent_log` and either find
  `@chat` still unset or raise, **before** anything else touches `chat`. `ask!(user_prompt)` still
  writes the transcript and usage via `save_transcript`/`after_message`
  (`ruby_llm_agent.rb:29-54,128-141`) even though the state stays `"processing"` — no Sidekiq job is
  pushed and no state transition happens inside `decide` itself. Only one `decide` call is valid per
  instance (a second call on the same instance would hit the `raise "chat already built"` guard,
  which is intentional — a caller that wants a second decision constructs a new instance).

  **`perform`** wraps `decide` with guards and the state transition:

  ```ruby
  def perform
    return if already_resolved?

    if micro_cluster.collected_pens.present?
      decide(agent_log:)
      agent_log.waiting_for_approval!
    else
      # Q19: an empty micro cluster at run time — skip, mark, let the worker's
      # ensure (S13) trigger a top-up. This log is terminal and excluded from
      # every stats query via the same auto_rejection filter S13's CleanUp uses.
      agent_log.update!(
        extra_data: (agent_log.extra_data || {}).merge(
          "auto_rejection" => "empty_cluster",
          "explanation_of_decision" =>
            "The micro cluster has no pens in it. It is not possible to cluster an empty micro cluster."
        )
      )
      agent_log.reject!
    end
  end
  ```

  No debounce and no `recent_activity?` check — unlike `InkClusterer`, this agent has no real-time
  trigger yet (that is pen P5, S40); every run in P0/P1 is either console-triggered or driven by
  S13's `TopUpPenClusteringQueue`, so a debounce window would only add latency for no benefit right
  now.

  **Guards**: `already_resolved?` only — it returns true if `micro_cluster.ignored?`, if
  `micro_cluster.pens_model_variant_id.present?`, or if a **`waiting_for_approval`**
  `PenVariantClusterer` log exists, and the method's last expression is
  `micro_cluster.agent_logs.pen_variant_clusterer.waiting_for_approval.exists?` (a waiting log blocks
  unconditionally). Mirror `ink_clusterer.rb:279-292`'s structure, substituting `Pens::MicroCluster`'s
  `ignored?`/`pens_model_variant_id` for `MicroCluster`'s `ignored?`/`macro_cluster_id`.
  A `processing` log must **NOT** block: the ink comment at `ink_clusterer.rb:283-286` spells out why
  ("Only an in-flight run (waiting for approval) should block a new run"), and
  `RunFailedClusterJobs` (S13, Q34(ii)) plus Sidekiq retries resume a crashed run by calling
  `perform` again on the same micro cluster and rely on `agent_log` finding that `processing` log
  (app/workers/run_failed_cluster_jobs.rb:10-18 re-enqueues exactly the `processing` logs older than
  15 minutes). A `processing` log that were guarded out would stay `processing` for ever and
  permanently consume one slot of the Q24(i) queue depth, and the transcript-restore spec below
  could not pass.
  Do **not** port the ink guard's fourth clause ("newer collected inks than the waiting log" —
  `ink_clusterer.rb:291`'s final line comparing `collected_inks` `updated_at` against the log's
  `updated_at`); the pen method ends with the bare `waiting_for_approval.exists?` above instead,
  and S40 adds the `updated_at` comparison together with the real-time trigger. Without a trigger
  yet, there is nothing that would race a waiting log against newly arrived pens.

  **Constructor and accessors** (never written down anywhere else, and `RunAgent` depends on the
  exact shape): `attr_accessor :micro_cluster, :agent_log_id` and
  `def initialize(micro_cluster_id, agent_log_id: nil)` setting
  `self.micro_cluster = Pens::MicroCluster.find(micro_cluster_id)` and
  `self.agent_log_id = agent_log_id` — mirror `ink_clusterer.rb:168-171` and `:272`. It must take an
  **id**, not a `Pens::MicroCluster` object, because `RunAgent#perform` splats Sidekiq JSON args into
  `klass.constantize.new(*args)` (app/workers/run_agent.rb:8-10) and the caller is
  `RunPenClustererAgent.perform_async("PenVariantClusterer", micro_cluster.id)`.

  **`agent_log`** uses `||=` throughout, not the ink version's second-call reassignment bug at
  `ink_clusterer.rb:174` (`@agent_log = AgentLog.find(agent_log_id) if agent_log_id` — note the bare
  `=`, which S19 separately fixes on the ink side). The pen version is written correctly from the
  start:

  ```ruby
  def agent_log
    @agent_log ||= AgentLog.find(agent_log_id) if agent_log_id
    @agent_log ||= micro_cluster.agent_logs.pen_variant_clusterer.processing.first
    @agent_log ||= micro_cluster.agent_logs.pen_variant_clusterer.waiting_for_approval.first
    @agent_log ||= micro_cluster.agent_logs.create!(name: self.class.name, transcript: [])
  end
  ```

  (`AgentLog.pen_variant_clusterer` is the scope S06 adds, mirroring `AgentLog.ink_clusterer` at
  `agent_log.rb:14`.)

- **Depends on.** S10 (the four tools this class wires up), S06 (the `agent_logs` association on
  `Pens::MicroCluster`, the `pen_variant_clusterer` `AgentLog` scope, and the tuple helper), S04
  (`config/llm.yml` must exist and be read the standard way before this class can get an entry in
  it).
- **Why here.** This is half of the agent — inert in prod, since nothing enqueues it automatically
  yet (S13's worker and S15's drip come later). Note that merging this PR already makes `perform`
  reachable from a Rails console via `RunAgent.perform_async("PenVariantClusterer", micro_cluster_id)`
  (`app/workers/run_agent.rb:8-10`), which already calls DO with the production
  `DO_INFERENCE_TOKEN` secret — a waiting-for-approval log created that way would sit with no
  approve/reject path until S12 merges, which is an acceptable and expected state for the gap
  between these two PRs (do not add a temporary approve path to bridge it). Splitting decide from
  apply keeps each PR a small, reviewable copy of one half of `InkClusterer`.
- **Does not include.** `approve!`/`reject!` (S12), the top-up call issued after a run finishes
  (S13), any Sidekiq worker, the admin review UI (S14), and the "newer collected pens than the
  waiting log" guard clause plus the real-time trigger (both S40).
- **Definition of done.**
  - Specs in `spec/agents/pen_variant_clusterer_spec.rb`, modelled section-by-section on
    `spec/agents/ink_clusterer_spec.rb`: agent_log creation/reuse/memoization (mirror lines 1-75:
    `#initialize` creates and finds by `agent_log_id`; `#agent_log` memoizes, finds an existing
    `processing` log, finds an existing `waiting_for_approval` log), `perform` per action via
    `stub_request(:post, "https://api.openai.com/v1/chat/completions")` returning a `tool_calls`
    envelope for each of the four tools (mirror lines ~156-372), each tool's `.call` returning
    `RubyLLM::Tool::Halt` and its side effects on `agent_log.extra_data` (mirror lines ~553-676),
    prompt formatting including `processed_tries_data` (mirror lines ~881-965, 1061-1233), a 500
    response raising `RubyLLM::ServerError` and malformed JSON raising `Faraday::ParsingError`
    (mirror lines ~967-996), transcript restore across a resumed run, and `already_resolved?` for
    each of its three cases. Build test pens with
    `create(:collected_pen, pens_micro_cluster: mc, ...)`. **Omit** the ink spec's line-5
    `WebMock.reset!` `before` hook (per the project's own WebMock-reset feedback: RSpec's WebMock
    integration resets stubs automatically) and its line-78 `CollectedInk.update_all(updated_at:
1.hour.ago)` debounce-aging hook (this agent has no debounce).
  - A dedicated `#decide` spec: after calling `decide(agent_log:)` directly (bypassing `perform`),
    `agent_log.state == "processing"` (unchanged — `decide` never transitions state),
    `RunAgent.jobs`, `RunInkClustererAgent.jobs`, and total `Sidekiq::Worker.jobs` count are all
    unchanged (nothing was enqueued), while the transcript and the token counts **are** recorded —
    this is the property S20's bench and cost estimation rely on. Assert it precisely: `usage` is
    NOT NULL with a zeroed default, so "non-empty" proves nothing. The stubbed chat-completion
    response must carry a `usage` object (`prompt_tokens`/`completion_tokens`), and the spec asserts
    `agent_log.usage["total_tokens"] > 0` and `agent_log.usage["model"].present?` (both written at
    ruby_llm_agent.rb:130-133, and only written when the response carries usage) plus
    `agent_log.transcript.length >= 2`.
  - `CreateNewVariant` spec proves both branches, and that the tool takes ONE param: no existing
    variant matching the micro cluster's derived tuple → halts with
    `extra_data["action"] == "create_new_variant"`, `msg` and `explanation_of_decision` written and
    **no tuple columns in `extra_data`**; an existing `Pens::ModelVariant` whose six columns equal the
    derived tuple → returns the assign-hint string (asserted against a real `RubyLLM::Tool::Halt`
    **not** being raised — the tool call returns a plain string that continues the conversation) and
    does **not** modify `agent_log.extra_data`'s `action` key. Include a case where a collected pen
    has `color = nil` and the existing variant has `color = ''`, to pin the `.to_s.strip`
    normalisation.
  - A config spec (in `spec/agents/pen_variant_clusterer_spec.rb` or a shared config spec, whichever
    S04's own spec suite conventions establish) asserting the `PenVariantClusterer` entry resolves to
    the DO `api_base`/`model`/`api_key_env` in the `production`/`development` config sections and to
    the test default endpoint in `test` — use whatever `LlmConfig` test helper S04 provides; do not
    invent a second config-resolution mechanism here.
  - An empty-cluster spec: a micro cluster with zero collected pens → `perform` sets
    `extra_data["auto_rejection"] == "empty_cluster"`, calls `agent_log.reject!` (state becomes
    `"rejected"`), and does **not** call `waiting_for_approval!`; assert no `RunPenClustererAgent` or
    top-up job is enqueued directly by this class (S13 wires the actual top-up trigger via its
    worker's `ensure`, not this agent).
  - `bundle exec rspec spec/agents/pen_variant_clusterer_spec.rb` green, no new RSpec warnings.
- **Rollback.** Prod risk: none (nothing yet enqueues this agent automatically). If a merged version
  proves buggy, `git revert` the PR; any `waiting_for_approval` logs it created in the interim are
  orphaned harmlessly until S12 ships (they are not on any review queue page yet — S14 is later).
- **Decisions applied.**
  - **Q32** — no `MODEL_ID` constant; the agent is born as a `config/llm.yml` entry pointing at the
    DigitalOcean model S01's spike picked, using `DO_INFERENCE_TOKEN` (the key is created in S00 per
    decision Q3). There is no later pen cutover step anywhere in the roadmap.
  - **Q19** — an empty micro cluster at run time is skipped: the log is written straight to
    `rejected` with `extra_data["auto_rejection"] = "empty_cluster"` and no `"action"` key, which is
    terminal, excluded from the review queue (never `waiting_for_approval`/`processing`), and
    excluded from every stats query via the same `auto_rejection` filter S13 introduces for its
    `CleanUp` 3-hour auto-rejections. S13's worker `ensure` block triggers the queue top-up after
    this happens.
  - **Q20** — `CreateNewVariant#execute` itself checks for an existing identical variant (by the
    six-tuple DERIVED from the micro cluster, not supplied by the model — the tool takes no data
    params) and, if found, **returns** a message telling the model to assign instead of halting.
    This is the only mechanism; there is no configurable alternative. The corresponding
    approval-time collision (a race, or a tool-check bypass) is S12's `approve!` refusing and
    rejecting the log exactly like the plan's stale-approval rule.
  - **Q18** — the system directive gets an explicit sentence: an unknown-brand result from
    `known_brand` (S10's explicit tool name) may indicate a misspelling rather than a genuinely new
    brand, so the model should double-check spelling or search the web before concluding a brand is
    new.
  - **Pen decision 3** — the ignore policy is written out in the directive as decided (nib units,
    literal-unknown/placeholder brand or model, clones/fakes/unbranded copies, non-fountain-pen
    products, kit and self-made pens, unknown-model vintage), together with its two non-ignore rules
    (calligraphy pens are pens; a malformed placeholder colour is assigned) and the
    ignore-is-permanent/hand-over-is-not rule.
  - **Pen decision 8** — the directive defines a variant as the model in one colour or finish;
    material and filling system never split a variant, trim colour only for a documented separately
    sold version, nib is not part of a variant, year/"LE"/"SE"/edition markers are noise.
- **Implementation notes.**
  - `agent_log` shape with the `||=` fix, written out in full above — copy it exactly; this is the
    corrected version of the bug S19 has to separately fix on `InkClusterer`
    (`ink_clusterer.rb:174`'s bare `@agent_log =`), so there is nothing to "fix later" here.
  - Prompt data: the S06 tuple helper's output (brand, model, color, material, trim_color,
    filling_system, count per tuple) plus the cluster's own `id`; `processed_try_entry` reads
    `variant_id` from a rejected log's `extra_data` (the pen analogue of the ink version's
    `cluster_id`). The helper's cap is required, not defaulted (S06), so pass
    `collected_pen_tuples(limit: PROMPT_TUPLE_CAP)` here and `collected_pen_tuples(limit: 1)` inside
    `CreateNewVariant`.
  - Tool constructor pattern: every decision tool takes `(micro_cluster, agent_log)`; `KnownBrand`
    (from S10) takes only `(micro_cluster)`; the three search tools (also from S10) take no
    constructor args except `PenWebSearchTool`, which takes `(agent_log)` for its nested
    `GoogleSearchSummarizer` child log. Assemble the full tool list in a private `tools` method
    mirroring `ink_clusterer.rb:294-304`:
    ```ruby
    def tools
      [
        AssignToVariant.new(micro_cluster, agent_log),
        CreateNewVariant.new(micro_cluster, agent_log),
        IgnorePen.new(micro_cluster, agent_log),
        HandOverToHuman.new(micro_cluster, agent_log),
        Tools::PenKnownBrandTool.new(micro_cluster),
        Tools::PenSimilaritySearchTool.new,
        Tools::PenFullTextSearchTool.new,
        Tools::PenWebSearchTool.new(agent_log)
      ]
    end
    ```
  - Manual verification in dev after both this PR and S12 (apply) are merged: pick an unassigned
    `Pens::MicroCluster` id with a handful of collected pens on the dev copy, run
    `RunAgent.perform_async("PenVariantClusterer", id)` from the Rails console (`docker-compose exec
app bundle exec rails console`), confirm a Sidekiq job runs against the DO endpoint (check
    `agent_log.transcript` afterwards for the request/response shape) and that the resulting
    `agent_log.state` is `"waiting-for-approval"` with a plausible `extra_data["action"]`. Since S12
    (apply) has not merged when this step alone is manually verified, there is no approve/reject path
    yet — this check only confirms the decide half works end-to-end against the real DO API.

### S12-pen-agent-apply — PenVariantClusterer `approve!`/`reject!`, collision refusal, cleanup, plain refuse-and-reject guard

- **Goal.** Add `approve!(agent: false)` / `reject!(agent: false)` to the `PenVariantClusterer` class
  started in S11, with the exact constructor shape `PenVariantClusterer.new(micro_cluster_id,
agent_log_id:)` that `InkClusterer` uses (ink_clusterer.rb:168, 234, 248; the controller passes
  `agent_log_id:` at ink_clusterer_controller.rb:81), so S38's future `approve!(agent: true)` call
  works unchanged once the checkers exist.
  - `approve!` re-checks that the micro cluster is still unassigned and not ignored; if it is not
    (a human assigned or ignored it while the log sat waiting, or a create collided with another
    approval — see the collision case below), it REFUSES the approval and rejects the log as a plain
    rejection (Q22): no `extra_data` tag, no stats-exclusion filter, no special flash message, no
    auto-reject hook wired into the React controllers. It is indistinguishable in the data from a
    log a human rejected on the merits, and the DoD test below asserts exactly that.
  - `assign` action → `update!(pens_model_variant_id:)` then, after commit,
    `Pens::UpdateMicroCluster.perform_async(micro_cluster.id)`.
  - `create` action → three steps, in this order, mirroring `ink_clusterer.rb:258-261`: derive the
    six-tuple from the micro cluster's most common
    `(brand, model, color, material, trim_color, filling_system)` combination (the same tuple helper
    S06 built and S11's `CreateNewVariant` tool already used to check for a duplicate before the
    model ever proposed the create); `variant = Pens::ModelVariant.create!(tuple)`;
    `micro_cluster.update!(pens_model_variant_id: variant.id)`; then, after commit,
    `Pens::UpdateMicroCluster.perform_async(micro_cluster.id)`. All three are required — the plan's
    rule is "create → `Pens::ModelVariant.create!` from the micro cluster's most common values,
    assign, then `Pens::UpdateMicroCluster`". Stopping after `create!` would leave an orphan variant
    with the micro cluster still unassigned and would never fire the L1.5/L2 chain
    (`UpdateMicroCluster` → `UpdateModelVariant` → `AssignModelMicroCluster` → possibly a new
    unassigned `Pens::ModelMicroCluster`, which is L2's trigger). Because S11's tool
    already refused to let the model create a duplicate at decision time (Q20), the only way
    `create!` here can collide with the six-column unique index on `pens_model_variants`
    (`idx_on_brand_model_color_material_trim_color_fillin_c4996a6771`, db/structure.sql:1715) is a
    genuine RACE: another cluster's create/assign committed between this log's decision and this
    approval. Rescue `ActiveRecord::RecordNotUnique` around the `create!` and treat it exactly like
    the stale-approval refusal above — REFUSE and plain-reject (Q20's approve-time half; the decide-time
    half already lives in S11's tool). Never silently fall back to assigning the pre-existing variant:
    a human reviews the refused log and decides.
  - The branch switches on the literal strings S11 stores, exactly as ink does at
    `ink_clusterer.rb:253-265`:
    `case agent_log.extra_data["action"] when "assign_to_variant" ... when "create_new_variant" ...
when "ignore_pen" ... when "hand_over_to_human" ... end`. A refused approval calls
    `agent_log.reject!` — the `AgentLog` MODEL method (app/models/agent_log.rb:39-41, a plain state
    change with no cleanup), not this class's own `reject!(agent:)` — and returns from `approve!`
    without applying anything.
  - `ignore_pen` action → `update!(ignored: true)`.
  - `hand_over_to_human` action → change the log's state only; do **not** `touch` the micro cluster
    (Q23 removes the ink `touch`, and pen ordering has no "recency" concept the way ink's does).
    Write nothing else: S13's exclusion scope — the single shared method
    `Pens::MicroCluster.handed_over_to_human_ids`, which takes each cluster's LATEST
    `PenVariantClusterer` log (`DISTINCT ON (owner_id) ... ORDER BY owner_id, id DESC`) and keeps it
    only when that log is `approved` with `extra_data->>'action' = 'hand_over_to_human'` —
    reads this exact shape, so approving a hand-over must leave `extra_data["action"]` unchanged and
    only flip the log's state (Q23).
  - `reject!` reverses each action: unassign nils `pens_model_variant_id` **and**, after commit,
    enqueues `Pens::UpdateModelVariant.perform_async(old_variant_id)`, exactly as
    `Admins::Pens::MicroClustersController#unassign` already does it
    (app/controllers/admins/pens/micro_clusters_controller.rb:47-53, the copy-relevant lines being
    :49-51), so the variant's derived
    attributes and embedding stop reflecting the rejected cluster. For an approved `create`, follow
    the pen plan's rule (docs/pen-clustering-plan.md:158-160): destroy the created variant if it only
    ever held this micro cluster (nullifying its micro clusters via `dependent: :nullify` on
    `Pens::ModelVariant#micro_clusters`, app/models/pens/model_variant.rb:2-5), otherwise just
    unassign it. The model micro cluster is created asynchronously (`approve!` →
    `Pens::UpdateMicroCluster` → `Pens::UpdateModelVariant` → `Pens::AssignModelMicroCluster`
    `find_or_create_by!` on the unique `(simplified_brand, simplified_model)` index,
    app/workers/pens/assign_model_micro_cluster.rb:5-9, db/structure.sql:1722), so at reject time it
    may not exist yet or may already be a pre-existing SHARED one (every Lamy Safari variant shares
    one). After destroying the variant, reload `variant.model_micro_cluster`; destroy it only if
    `model_micro_cluster.model_variants.none?` AND `model_micro_cluster.pens_model_id.nil?`; leave an
    assigned, now-empty one alone (the cross-level cascade that also rejects the L2 log on it is
    S36's job, Q21). `un-ignore` → `ignored: false`. `reject!` returns the micro clusters to re-run
    (this cluster plus any siblings freed by destroying a variant), filtered to
    `.reject { |mc| mc.collected_pens.empty? }` exactly like `ink_clusterer.rb:241`.
  - A private helper that writes a synthetic REJECTED guidance log (no `perform`/`ask!` call, just
    `micro_cluster.agent_logs.create!(name: "PenVariantClusterer", state: AgentLog::REJECTED,
rejected_at: Time.current, agent_approved: false, extra_data: {...})`), used by S14's admin
    controller when a human un-ignores or unassigns a cluster from the React app so the agent sees
    that history on its next run.
- **Depends on.** S11 (`decide`, the tools, the config entry).
- **Why here.** Completes the agent's write path while it is still unreachable from prod (depth 0
  until S15). L2 (S36) and the checkers (S38) build on the same collision/cleanup semantics, so
  fixing them now avoids relearning the rules under a schema change later.
- **Does not include.** The `RunPenClustererAgent` worker, `TopUpPenClusteringQueue`, the
  `RunFailedClusterJobs` branch, any admin controller or trigger, and the cross-level cascade that
  destroys an _assigned_ empty model micro cluster or rejects its L2 log (S36).
- **Definition of done.**
  - Specs for every action branch (`assign`, `create`, `ignore`, `hand_over_to_human`, `un-ignore`)
    incl. the after-commit deferral (copy the ink spec's transaction-wrapping pattern), the plain
    refusal branch (two cases below), the `RecordNotUnique` collision on `create!`, both
    create-rejection cleanup cases ("model micro cluster not yet created" and "shared model micro
    cluster left alone"), and the `Pens::UpdateModelVariant.perform_async` call after an unassign.
  - Refusal test case 1 (stale approval): decide `assign_to_variant`, then have a human assign the
    same cluster to a _different_ variant via `Pens::MicroCluster#update!(pens_model_variant_id:)`
    (mirroring `Admins::Pens::MicroClustersController#update`,
    app/controllers/admins/pens/micro_clusters_controller.rb:40-45), then call `approve!` on the
    stale log and assert: the log ends in `rejected` state with **no** `extra_data["auto_rejection"]`
    key (contrast with S13's `CleanUp` tag), and the human's assignment is untouched. A mirror case
    where the human ignored the cluster instead.
  - Refusal test case 2 (create collision): stub `Pens::ModelVariant.create!` (or set up two
    concurrent decided-create logs targeting the identical six-tuple and approve the second) so the
    second `approve!` raises `ActiveRecord::RecordNotUnique`; assert the second log ends `rejected`
    with no tag and the first (already-created) variant is untouched.
  - The EXISTING `spec/workers/pens/update_model_variant_spec.rb` (172 lines today, no
    `RecordNotUnique` example — extend it, do not create or overwrite it) gains the
    `RecordNotUnique` path: build two variants whose collected pens converge on the same six-tuple
    after an edit, run `Pens::UpdateModelVariant.new.perform(variant.id)` on the second, and assert
    (a) exactly ONE retry happens, with the second-most-popular `model` value, and (b) a second
    collision re-raises instead of looping. There is no guaranteed-unique "second most popular
    tuple", so assert the fallback the code actually takes, never a guaranteed-success outcome.
- **Implementation notes.**
  - Copy points: `approve!` at ink_clusterer.rb:248-268, `reject!` at :234-246,
    `clean_up_rejected_approval!` at :313-330 (note :316 only nils the FK, it does not destroy
    anything), `already_resolved?` at :279-292 is NOT copied here (that guard belongs to `decide` in
    S11); include `AfterCommitEverywhere` (already included at ink_clusterer.rb:3) for the
    `after_commit` block. Spec templates: spec/agents/ink_clusterer_spec.rb:678-793 (`#approve!` per
    action, `agent: true`, idempotency — `return if agent_log.approved?`), :795+ (`#reject!`),
    :704-715 (after-commit deferral pattern: wrap the call in `ActiveRecord::Base.transaction`, assert
    `Pens::UpdateMicroCluster.jobs.size` is 0 inside the transaction block and 1 after it commits).
  - Create tuple (reuse, do not reimplement): call S06's helper —
    `row = micro_cluster.collected_pen_tuples(limit: 1).first`, then
    `Pens::MicroCluster::TUPLE_COLUMNS.to_h { |c| [c.to_sym, row.public_send(c).to_s.strip] }`. This
    is the same call S11's `CreateNewVariant` makes for its Q20 duplicate check, so the row the tool
    checked is the row this creates. Do not hand-roll a `group(...).count.max_by` here: it hard-codes
    the column list a second time and has no tie-break, while S06's helper carries the deterministic
    secondary `ORDER BY` the specs and prompts rely on. `approve!`
    calls `Pens::ModelVariant.create!(tuple)` directly (no `find_or_create_by`/`find_by` fallback
    here — S11's tool already ruled out an existing match at decision time; a match found at
    approval time IS the race, handled by the `RecordNotUnique` rescue below, never by silently
    assigning to the found row).
  - `RecordNotUnique` fix for `Pens::UpdateModelVariant#update_attributes!`
    (app/workers/pens/update_model_variant.rb:18-23): today this method calls a bare `model_variant.save`
    with **no** rescue at all — verified in the current tree, so a `RecordNotUnique` from the
    six-column unique index (db/structure.sql:1715) escapes `perform` and Sidekiq re-runs the job on
    its default 25-attempt schedule (~21 days) with the same colliding values every time (`save`
    without `!` still lets a database-level `RecordNotUnique` propagate; it only swallows validation
    failures). Copy the SEMANTICS of `Pens::UpdateModel#update_attributes!` and
    `best_attr_value(attr, retried:)` (app/workers/pens/update_model.rb:18-30 and :32-50, which pick
    "the second most popular value" at :36-38) — the retry varies the `model` attribute, as
    `UpdateModel` does — but copy the SHAPE from `update_macro_cluster.rb:15-26`, i.e. declare
    `retried = false` **before** the `begin` block. `Pens::UpdateModel`'s own `retried = false` sits
    _inside_ the `begin`, so `retry` resets it and a persistent collision loops for ever; that
    sibling bug is left alone here and fixed in S36 when L2 wiring next touches `Pens::UpdateModel`.
    Do not copy that bug.
  - Never destroy micro clusters directly — the FK from `collected_pens`/`agent_logs` (structure.sql:2384
    and neighbours) means only nilling `pens_model_variant_id` is safe; capture
    `variant.micro_clusters.to_a` **before** calling `variant.destroy` (destroy nullifies the
    association immediately, model_variant.rb:2-5), then filter out empty ones exactly like
    `ink_clusterer.rb:241`.
  - `Pens::AssignModelMicroCluster#perform` already rescues `ActiveRecord::RecordNotFound` (a model
    variant destroyed between enqueue and run) — no change needed there, just be aware a
    reject-triggered variant destroy can race a still-queued `AssignModelMicroCluster` job harmlessly.

**Decisions applied:** Q20 (approve-time collision refusal; decide-time duplicate check is S11's),
Q21 (L1 half of the cross-level cascade — destroy only an unassigned empty model micro cluster),
Q22 (a refused approval is a plain `reject!`, no tag, no special handling), Q23 (hand-over `approve!`
changes state only, written in the shape S13 reads).

### S13-pen-workers — RunPenClustererAgent (retry 2), TopUpPenClusteringQueue (waiting + processing by name, hand-over exclusion), RunFailedClusterJobs branch, CleanUp tagging

- **Goal.** `RunPenClustererAgent` copies `RunInkClustererAgent`
  (app/workers/run_ink_clusterer_agent.rb, 11 lines; `perform(klass, *)` dispatches any class name by
  `constantize`, which S38's future checkers rely on) with its own Sidekiq-throttled concurrency-1
  slot on the `agents` queue (own worker class = own throttle slot; sidekiq-throttled 2.1.0 keys
  strategies per class), and its own spec (neither ink worker has one today). It ships with an
  explicit `sidekiq_options retry: 2` (Q4 — decided, not proposed: today's retry behaviour elsewhere
  stays HTTP-client 3x plus Sidekiq's default 25 plus the Honeybadger `sidekiq.attempt_threshold: 3`;
  only `RunPenClustererAgent` gets the tighter cap, so a `DecisionNotReachedError` or a provider error
  cannot re-pay the prompt 25 times; revisit the wider retry budget only after the first DO
  cutover — out of scope here). Give the throttle a `lost_job_threshold` strictly greater than both
  the requeue age below and the longest tolerated run, e.g. `sidekiq_throttle concurrency: { limit: 1,
lost_job_threshold: 3600 }` (in sidekiq-throttled 2.1.0 the threshold is handed to the Lua script
  at `strategy/concurrency.rb:56-65`, which is what actually expires the slot after
  `lost_job_threshold` regardless of any requeue — `:112` only decays the estimated backlog; `ttl:` is a deprecated alias; the value
  must exceed `avg_job_duration`, default 300s or a third of the threshold, or the strategy raises
  `ArgumentError` at class-load time). The pen branch of `RunFailedClusterJobs` requeues on
  `updated_at < 15.minutes.ago` (not `created_at`, unlike the ink branch) because
  `RubyLlmAgent#save_transcript` bumps `updated_at` on every message
  (app/agents/concerns/ruby_llm_agent.rb:138-141), so a live slow run is never requeued while a
  crashed one reliably is; the ink branch is left on `created_at` as today.
  `RunPenClustererAgent#perform` wraps the agent call in `ensure { TopUpPenClusteringQueue.perform_async }`
  so a run that ends without a reviewable log (the S11 empty-cluster marker, `DecisionNotReachedError`,
  a provider error, the `MAX_TOOL_CALLS` raise at `ruby_llm_agent.rb:123`, constant at :110) refills
  its own slot right
  away, exactly as the pen plan asks (docs/pen-clustering-plan.md:194-196); a retried job calls it
  again, harmlessly, because the top-up itself is idempotent.
  - `TopUpPenClusteringQueue` reads `ENV.fetch("PEN_CLUSTERING_QUEUE_DEPTH", "0")`, and counts
    `PenVariantClusterer` logs by **name** (the same key `RunFailedClusterJobs` and the admin queue
    filter use, and the reason a later `Pens::MicroCluster`-owned agent, a checker guidance log, or
    S12's synthetic REJECTED log can never inflate the depth) in the states `waiting-for-approval`
    AND `processing` (Q24(i): the depth counts only these two states; a job that is enqueued on
    Sidekiq but has not yet created its `AgentLog` row is NOT counted — there is no way to count it
    without a new "queued" marker, and the resulting brief overshoot right after a burst of
    back-to-back human reviews is accepted as-is, not engineered around), and with
    `.owner_with_collected_pens` (S06) applied to BOTH counted states. The Q8 filter belongs here as
    much as in the fill query below: without it, a waiting log whose micro cluster has since lost its
    pens occupies a depth slot for ever, because S14's review page filters that log out and no human
    can ever review it away. With it, the worker's depth, S14's `@queue_length`, the page title and
    `AdminStats#pens_micro_cluster_agent_review_count` are literally one definition
    (`AgentLog.pen_variant_clusterer.where(state: [WAITING_FOR_APPROVAL, PROCESSING]).owner_with_collected_pens.count`).
    It fills missing slots from
    `Pens::MicroCluster.unassigned.without_ignored.with_collected_pens` (the S06 scope) ordered by pen
    count desc then random (there is no existing SQL to copy — the React endpoint at
    `Admins::Pens::MicroClustersController#index` orders by `Pens::MicroCluster.ordered`, i.e.
    simplified names, which is the wrong order for a work queue), excluding clusters that already have
    a pending log AND excluding clusters whose LATEST `PenVariantClusterer` log is an approved
    `hand_over_to_human`. Write that exclusion ONCE, as a class method
    `Pens::MicroCluster.handed_over_to_human_ids`, defined as the ids whose newest
    `PenVariantClusterer` log (`SELECT DISTINCT ON (owner_id) id FROM agent_logs WHERE name =
'PenVariantClusterer' AND owner_type = 'Pens::MicroCluster' ORDER BY owner_id, id DESC`) is
    `approved` with `extra_data->>'action' = 'hand_over_to_human'`. It must be LATEST-log, not
    any-log: after a human unassigns a cluster again (`Admins::Pens::MicroClustersController#unassign`,
    app/controllers/admins/pens/micro_clusters_controller.rb:47-53) an any-log rule would keep that
    cluster permanently unreachable by the top-up. S16's `handed_over` serializer attribute and
    filter read this SAME method, so the two definitions cannot drift (Q23 — these stay excluded from
    every refill until a human assigns or ignores
    them in the React app; S12 writes that exact log shape, so this scope and S16's later React marker
    read the identical definition and cannot drift). Idempotent: calling it twice back-to-back with no
    state change in between fills nothing the second time.
  - `RunFailedClusterJobs` gains a `PenVariantClusterer` branch dispatching to `RunPenClustererAgent`
    (the existing spec already asserts other agent names are not restarted by the ink-only branch;
    add positive tests for the new branch, do not touch the ink branch's behaviour).
  - CleanUp tagging happens in `CleanUp::RejectAgentLog#perform`
    (app/workers/clean_up/reject_agent_log.rb, the ONLY place that calls `reject!` on an orphaned log;
    `CleanUp#reject_orphaned_agent_logs` at clean_up.rb:43-49 only plucks ids of `AgentLog.processing`
    rows older than `3.hours.ago` and enqueues `CleanUp::RejectAgentLog` per id — this scope is
    name-agnostic and already covers pen logs the moment they exist): before calling `reject!`, set
    `agent_log.update!(extra_data: (agent_log.extra_data || {}).merge("auto_rejection" => "orphaned"))`,
    and when the rejected log's `name` is `"PenVariantClusterer"` also enqueue
    `TopUpPenClusteringQueue.perform_async` so the freed slot is refilled immediately rather than
    waiting for the next cron tick. Two prod `InkClusterer` rejected logs already have no `action` key
    at all, so every stats filter downstream (S14's presenter, S38's future percentages) must tolerate
    `extra_data` being `NULL` or missing keys, not just missing `auto_rejection`.
  - Q19 (one sentence, no new code here): S11's empty-cluster marker log is written straight to
    `rejected` with `extra_data: { "auto_rejection" => "empty_cluster" }` and no `action` key, reusing
    this same tag convention so S14's presenter needs only one filter, not two; it is terminal, so it
    is never counted toward the depth above, and the WORKER's `ensure` block (not any special-cased
    branch here) is what triggers the top-up after such a run — no additional wiring is needed in this
    step beyond the `ensure` already described.
- **Depends on.** S11 (the agent to run), S06 (the scopes and the `(name, state)` index this step's
  queries rely on), S12 (`approve!`/`reject!`, and the exact hand-over log shape this step's exclusion
  scope reads).
- **Why here.** Wires the agent into Sidekiq but ships with the queue OFF (depth 0, S15 turns it on).
  Nothing in prod enqueues `RunPenClustererAgent` until S14's admin controller (manual approve/reject)
  or S15's first top-up call; the worker's own top-up-after-empty-run ships here but is unreachable
  until the queue has a non-zero depth.
- **Does not include.** Any trigger from the collected-pen save path (that is S40, after the checkers
  and the depth-raise decision).
- **Definition of done.**
  - Specs: top-up never exceeds depth, no-op at depth 0, idempotent (two calls in a row), fill
    ordering (pen count desc, then random — assert the SQL shape, not exact randomness), both
    exclusion rules (pending log; approved hand-over), a positive `RunFailedClusterJobs` test for the
    new branch, a raising/erroring agent run still enqueues exactly one top-up job via `ensure`.
  - `spec/workers/clean_up/reject_agent_log_spec.rb` (new file — `spec/workers/clean_up_spec.rb` today
    only covers `clear_expired_deletion_requests` and friends, not this worker) asserting both the
    `auto_rejection: "orphaned"` tag and, only for a `PenVariantClusterer` log, the `TopUpPenClusteringQueue`
    enqueue; a mirror case for a non-pen log asserting NO top-up is enqueued.
  - `EXPLAIN` of the top-up count query on the dev prod copy pasted into the PR description (after
    S06's `(name, state)` index it should be an index-only scan, not a sequential scan).
- **Implementation notes.**
  - ENV stub convention (new — `grep -rn 'allow(ENV).to receive(:fetch)\|stub_const("ENV'` over
    `spec/` returns nothing today, so state the convention explicitly for whoever writes these specs):
    `allow(ENV).to receive(:fetch).and_call_original` FIRST, then
    `allow(ENV).to receive(:fetch).with("PEN_CLUSTERING_QUEUE_DEPTH", "0").and_return("10")`. A bare
    `.with(...)` stub with no `and_call_original` makes every OTHER `ENV.fetch` call on the same
    thread raise (`ruby_llm_agent.rb:98-103`, `embeddings_client.rb:29` both call `ENV.fetch` for
    unrelated keys during the same request). Alternatively, expose the depth as a class method
    (`TopUpPenClusteringQueue.depth`) and stub that method directly instead of `ENV`.
  - `RunFailedClusterJobs` branch, sketch:
    ```ruby
    AgentLog
      .pen_variant_clusterer
      .processing
      .where("updated_at < ?", 15.minutes.ago)
      .find_each { |log| RunPenClustererAgent.perform_async("PenVariantClusterer", log.owner_id) }
    ```
    Extend `spec/workers/run_failed_cluster_jobs_spec.rb` (5 examples today; :46-55 already asserts an
    `"OtherAgent"` name is left alone and must keep passing unchanged). Cron facts to cite in the PR:
    `RunFailedClusterJobs` runs `*/15 * * * *` (config/sidekiq_schedule.yml, `run_failed_cluster_jobs`
    entry), `CleanUp` runs hourly at `:45` (`clean_up` entry) — the top-up job itself is deliberately
    left OUT of `sidekiq_schedule.yml`; it is only ever enqueued from `ensure` blocks and from S14's
    admin controller after a manual approve/reject.
  - Fill query sketch (adjust table/column names to match S06's actual scope implementation):
    ```ruby
    Pens::MicroCluster
      .unassigned
      .without_ignored
      .with_collected_pens
      .where.not(
        id: AgentLog
          .pen_variant_clusterer
          .where(owner_type: "Pens::MicroCluster", state: [AgentLog::WAITING_FOR_APPROVAL, AgentLog::PROCESSING])
          .select(:owner_id)
      )
      .where.not(id: Pens::MicroCluster.handed_over_to_human_ids)
      .left_joins(:collected_pens)
      .group("pens_micro_clusters.id")
      .order(Arel.sql("COUNT(collected_pens.id) DESC, RANDOM()"))
      .limit(missing)
      .pluck(:id)
    ```
    Base population to cite in the PR: 96,713-96,827 unassigned, non-ignored clusters with pens on
    prod as of 2026-09-14 (re-count before merging, this drifts daily with imports).
  - Prod facts useful for writing these specs: 0 `processing` `AgentLog` rows today across any agent;
    53,808 `waiting-for-approval` rows across 11 agent names; web-search child logs are owned by the
    PARENT `AgentLog` (`owner_type` = `"AgentLog"`, 7,489 `GoogleSearchSummarizer` rows), never by the
    micro cluster directly, so they cannot pollute this step's by-name/by-owner-type queries; zero
    `agent_logs` rows exist today with `owner_type LIKE 'Pens::%'`, so the top-up and exclusion queries
    can only be exercised against hand-made fixtures on the dev copy, not against real prod pen data,
    until S15 starts writing them.
  - The two independent 15-minute-ish constants (the janitor's requeue age here, and the throttle's
    `lost_job_threshold`) must stay reconciled: `lost_job_threshold` (3600s suggested above) strictly
    exceeds the requeue age (900s) so a job `RunFailedClusterJobs` decides is stuck has always already
    had its throttle slot released by the time the requeue fires; if you change one, re-check the
    other.

**Decisions applied:** Q4 (ships with `sidekiq_options retry: 2`, not "proposed"), Q19 (the S11
empty-cluster marker is terminal, never counted, and the worker's own `ensure` triggers its top-up —
no extra branch needed here), Q23 (approved-hand-over exclusion scope, matched exactly to S12's log
shape), Q24(i) (depth = waiting-for-approval + processing by name only; queued-but-unstarted jobs are
never counted; brief overshoot is accepted).

### S14-pen-admin — Admin review controller, shared partial + presenter (latest 500), dashboard count, guidance logs, delete-history fix (also applied to the ink page)

- **Goal.** `Admins::Agents::PenVariantClustererController` (`index`/`update`/`destroy`) mirroring
  `Admins::Agents::InkClustererController`, but passing `agent_log_id` on approve as well as reject
  (the ink approve path at `ink_clusterer_controller.rb:29` calls `InkClusterer.new(id).approve!`
  WITHOUT `agent_log_id:`, which can hit a `processing` log with nil `extra_data` at
  `ink_clusterer.rb:253` if the agent hasn't finished writing its decision yet — fold this fix into the
  shared controller code so the pen controller never repeats the ink bug), handling a refused
  approval as a plain rejection (S12's approve! already rejects it — the controller does nothing
  special: no extra flash branch, no auto-reject hook, it just falls through to the ordinary
  "log moved to rejected, show the next one" path (Q22)), and enqueueing
  `TopUpPenClusteringQueue.perform_async` after every approve and every reject so a freed slot refills
  without waiting for a cron tick.
  - **Two relations, not one — this deliberately diverges from the ink controller.** The ink
    controller sets `@queue_length = agent_logs.count` from the SAME relation it renders
    (`ink_clusterer_controller.rb:3` and `:71-78`). The pen controller splits them, because Q24(ii)
    says agent-decided logs SHOW on the human review page but do NOT count toward the depth:
    `@agent_logs = AgentLog.pen_variant_clusterer.where(state: [AgentLog::WAITING_FOR_APPROVAL,
AgentLog::PROCESSING]).or(AgentLog.pen_variant_clusterer.agent_processed)
.owner_with_collected_pens.order(:id)` is what the page renders (the `agent_processed` branch is
    there for spot checks that feed the "correct auto review" percentages), while `@queue_length`,
    the page title AND `AdminStats#pens_micro_cluster_agent_review_count` all count
    `AgentLog.pen_variant_clusterer.where(state: [AgentLog::WAITING_FOR_APPROVAL,
AgentLog::PROCESSING]).owner_with_collected_pens.count` — the same definition S13's depth uses
    (Q24(i)). Note the `.owner_with_collected_pens` scope (S06) on BOTH: Q8 keeps the empty ASSIGNED
    micro clusters in the database and requires filtering them out of every queue and count, exactly
    as the ink side does with `.with_collected_inks` (`ink_clusterer_controller.rb:76`,
    `admin_stats.rb:19`). Apply the scope AFTER the `.or(...)`, as the ink controller does, or the
    filter silently drops off the `agent_processed` branch.
  - The controller does NOT re-enqueue one agent run per micro cluster that S12's `reject!` returns.
    The ink controller does (`ink_clusterer_controller.rb:80-87` calls
    `RunInkClustererAgent.perform_async("InkClusterer", cluster.id)` per returned cluster); copying
    that here would bypass `PEN_CLUSTERING_QUEUE_DEPTH` entirely and break the pull-based cost
    control (Q28/S13/S15). The pen controller discards the returned array and enqueues
    `TopUpPenClusteringQueue.perform_async` exactly once, so every re-run flows through the depth
    cap; the returned clusters simply become eligible again on the next refill.
  - Extract `app/views/admins/agents/ink_clusterer/index.html.slim` (91 lines) into a shared partial
    parameterised by: the log scope (`agent_logs`), the action list (the ink view's hand-over
    exclusion at :28,:35), the seven route helpers used for the pagination/approve/reject links
    (:70-85), a search-query source (ink uses `owner.all_names.first` at :85; `Pens::MicroCluster` has
    no `all_names` method, so pass in the S06 tuple helper's most-common-tuple joined with spaces
    instead), and a `processing?` predicate for the 3-second `meta http-equiv=refresh` (the ink
    controller derives `@processing` from `extra_data["follow_up_agent"]`/`extra_data["follow_up_done"]`,
    `ink_clusterer_controller.rb:6-13` — pen logs have no follow-up fields until S38's checkers exist,
    so the pen controller uses the simpler `agent_log.processing?` until then, and must be revisited
    to also treat a rejected checker child log as "done" once S38 lands). Keep `per(1)`
    (`app/javascript/src/admin/admin-shortcuts.js:14` queries `[data-shortcut=...]` on the page and
    assumes one log per page), the `data-shortcut` attributes, and the `.reject-btn`,
    `form.reject-form`, `.reject-note` classes (`app/javascript/src/admin/reject-with-note.js:2-6`)
    unchanged in the shared partial.
  - Move the in-view "correct auto review" stats block (ink view :13-39) into a presenter class (a
    plain PORO, NOT an ActiveRecord model) with a NaN guard for actions that have no follow-up data
    yet (every pen log today — S38 is what starts populating follow-up outcomes). Its population is
    the LATEST 500 manually processed logs (Q25(i) — mirrors how the ink page already works)
    **minus** logs with `extra_data->>'auto_rejection' IS NOT NULL` (this single filter, from S13's
    `CleanUp` tag, also covers S11's empty-cluster marker log because both use the same
    `auto_rejection` key — Q19's design goal of "one filter, not two" is met here) **and minus the
    synthetic guidance logs** this step and S12's helper write. The second exclusion is an ADDITION
    beyond Q25(i), recorded as its own engineering decision in section 5, not something Q25 decides:
    Q25(i) fixes only the population ("latest 500 manually processed logs, as inks") and Q25(ii)'s
    "the same fix is applied to the ink page" refers to the delete-history fix, nothing else. The
    reason for the addition: guidance logs are `state: REJECTED, agent_approved: false` with no
    `auto_rejection` key, so they land squarely in the `manually_processed` population
    (agent_log.rb:32) and would inflate every per-action Rejected count that S22 compares against the
    bench. Recognise them by the one thing that is always true of them — they have an empty
    transcript and zero tokens, because nothing ever called the model — and exclude them with a
    second predicate, `where("jsonb_array_length(transcript) > 0")`. The ink page carries the same
    rows today, so the same exclusion is applied there while the block is extracted — which CHANGES
    THE LIVE INK PAGE'S NUMBERS and must be called out in the PR description exactly like the
    delete-history fix below, never shipped silently. The presenter also
    exposes per-action Processed/Approved/Rejected counts (S22's bench-round-0 step compares these
    against the leave-one-out bench numbers per action).
  - `AdminStats#pens_micro_cluster_agent_review_count` counts `waiting-for-approval` PLUS `processing`
    `PenVariantClusterer` logs through `AgentLog.pen_variant_clusterer` and
    `.owner_with_collected_pens` (S06, Q8), consistently with both the queue's own page title and with S13's depth
    definition (contrast: the existing ink count at `admin_stats.rb:14-21` OMITS `processing` — that
    is a pre-existing quirk of the ink page, left alone; do not "fix" it here, only make sure the new
    pen method does not repeat it), plus a dashboard span for it.
  - Synthetic REJECTED guidance logs, written from `Admins::Pens::MicroClustersController#update`
    (un-ignore path) and `#unassign` (copy the pattern from
    `admins/micro_clusters_controller.rb:35-46` and `:56-74`, the ink equivalents) with
    `extra_data: { "action" => "assign_to_variant", "variant_id" => previous_variant_id }` or
    `extra_data: { "action" => "ignore_pen" }` respectively — reuse S12's private helper that builds
    these logs, so a human's manual undo in the React app leaves a trail the next `PenVariantClusterer`
    run can read as prior guidance.
  - **Delete-history fix (Q25(ii)), applied to BOTH the new pen controller and the existing ink
    controller in this same PR.** Today, `Admins::Agents::InkClustererController#destroy` calls
    `persist_manual_rejection_note!` (writes the typed note into `agent_log.extra_data`) and THEN
    `reject_and_reprocess!`, which does:
    ```ruby
    clusters_to_reprocess = InkClusterer.new(micro_cluster.id, agent_log_id: agent_log.id).reject!
    clusters_to_reprocess.each do |cluster|
      cluster.agent_logs.destroy_all if params[:delete_history].present?
      RunInkClustererAgent.perform_async("InkClusterer", cluster.id)
    end
    ```
    This has two bugs: (1) when `delete_history` is checked, `cluster.agent_logs.destroy_all` also
    destroys the log that JUST received the manual note (since that log belongs to `micro_cluster`,
    which is always included in `clusters_to_reprocess`), so the human's just-typed rejection reason
    is silently lost; (2) for a rejected `create_new_cluster` decision, `reject!`'s cleanup returns
    ALL of the macro cluster's other micro clusters too (`ink_clusterer.rb:319-322`), so
    `delete_history` wipes THEIR agent-log history as well, even though the human only asked to clear
    history for the cluster on screen. Fix: only ever call `destroy_all` on the ORIGINATING cluster
    (`micro_cluster`, i.e. `agent_log.owner`), never on any sibling cluster the reject cleanup also
    returns; and after any history deletion for the originating cluster, write a FRESH guidance log
    (reuse the same synthetic-log helper as above) carrying the manual rejection note, so the note
    always survives regardless of whether history was cleared. Siblings still get
    `RunInkClustererAgent.perform_async` re-queued as before — only the `destroy_all` call moves.
    Apply the identical fix to the pen controller's equivalent method. Smoke-test the ink review page
    manually right after this PR auto-deploys (prod risk stays "low", but say explicitly in the PR
    description that this changes live ink behaviour, not just adds pen code).
- **Depends on.** S12 (`approve!`/`reject!` and the synthetic-log helper), S13 (`TopUpPenClusteringQueue`,
  the `auto_rejection` tag).
- **Why here.** Last piece of code before the drip (S15) can be turned on and decisions reviewed by a
  human; the shared partial and presenter built here are reused as-is by S36 (L2), S38 (checkers'
  "correct auto review" percentages) and S42 (L3).
- **Does not include.** Checker-related UI (the percentages column only becomes meaningful once S38
  exists; the presenter's NaN guard is exactly what makes it safe to render before then).
- **Definition of done.**
  - Request specs modeled on `spec/requests/admins/agents/ink_clusterer_controller_spec.rb` (146
    lines): index pagination/refresh, approve (agent_log_id passed), reject (plain rejection path,
    tagged rejection path via CleanUp — assert both render identically to a human rejection),
    delete-history preserving the note and not touching sibling history.
  - The existing `spec/requests/admins/agents/ink_clusterer_controller_spec.rb` still passes
    unchanged after the shared-partial extraction, PLUS new cases for the delete-history fix: a
    create-reject with `delete_history=true` where the log carries a manual note and OTHER micro
    clusters have their own separate history — assert the note survives on a fresh log for the
    originating cluster and the sibling clusters' agent-log history is untouched.
  - New presenter spec under `spec/presenters/` (new directory; the presenter is a plain PORO,
    autoloaded by Zeitwerk from `app/presenters/`, no Rails generator needed) covering: the
    `auto_rejection` exclusion, the NaN guard when an action has zero follow-up data, and the
    per-action counts.
  - Page title and dashboard agree with each other and with S13's depth, and the agent-decided log
    is shown but not counted: in a request spec create one `waiting-for-approval`, one `processing`
    and one `agent_processed` `PenVariantClusterer` log on pen micro clusters that HAVE pens, plus a
    `waiting-for-approval` log on an EMPTY (assigned, pen-less) micro cluster, plus one log tagged
    `auto_rejection: "empty_cluster"`. Assert
    `AdminStats.new.pens_micro_cluster_agent_review_count == controller.view_assigns["queue_length"]`
    and that both equal **2** (waiting + processing, the empty-cluster owner filtered out by
    `owner_with_collected_pens`), while `controller.view_assigns["agent_logs"]` contains **3** logs —
    the `agent_processed` one included (Q24(ii)). Assert separately that the empty-cluster-owner log
    never appears in the index (that is the Q8 filter, exercised by a WAITING log so the scope is
    really tested) and that the `auto_rejection`-tagged log is absent from the presenter's
    population (mirrors the ink spec's :20-46 pattern).
- **Implementation notes.**
  - Wiring: `config/routes.rb:124-126` — add
    `resources :pen_variant_clusterer, only: %i[index destroy update]` inside the existing
    `namespace :agents do ... end` block (alongside `resources :ink_clusterer, ...`). Dashboard span
    in `app/views/admins/dashboards/show.html.slim` (copy the `micro_cluster_count` /
    `micro_clusters_to_assign_count` pattern at lines 42-43) with
    `span(class="stats" data-id="pens_micro_cluster_agent_review_count")` /
    `span(class="conditional-stats" data-id="pens_micro_cluster_agent_review_count" data-href=admins_agents_pen_variant_clusterer_index_path data-template="%count% agent decisions to review")`
    — the `data-template` attribute is required; without it the span renders a bare number (the ink
    equivalent is `app/views/admins/dashboards/show.html.slim:44`).
    `Admins::StatsController::NO_ARG_STATS` (`stats_controller.rb:7`) is derived automatically from
    `AdminStats.instance_methods(false)`, so simply adding the new public method to `AdminStats` is
    enough — no controller change needed there. `jsonify` (used by the dashboard's JS polling) lives
    in `app/helpers/application_helper.rb:21`.
  - `PensModelVariantSerializer` (`app/serializers/pens_model_variant_serializer.rb:4`) already has
    `has_many :micro_clusters, serializer: PensMicroClusterSerializer` — the synthetic-log helper does
    not touch serialization, only writes rows; no serializer change is needed in this step (S16 is
    what changes `PensMicroClusterSerializer`).
  - Q25(ii) evidence to put in the PR description for the owner: today, `destroy` →
    `persist_manual_rejection_note!` (`ink_clusterer_controller.rb:58-65`, writes onto the CURRENT
    log) → `reject_and_reprocess!` → `cluster.agent_logs.destroy_all if params[:delete_history]`
    (`:83`) for EVERY cluster `reject!` returns; for a rejected `create_new_cluster` decision,
    `ink_clusterer.rb:319-322` returns every sibling micro cluster of the destroyed macro cluster, so
    today's code wipes their history too. This step changes that live behaviour for the ink page in
    the same PR — call this out explicitly, it is not pen-only.
  - Human assignment/un-ignore while an agent log sits `waiting-for-approval`:
    `Admins::Pens::MicroClustersController#update` (`micro_clusters_controller.rb:40-45`) is also what
    handles the React app's manual assign (`pens_model_variant_id=`). This path does NOT (Q22)
    auto-reject the cluster's pending `PenVariantClusterer` log — the log simply gets refused the next
    time someone (or S15's queue) tries to approve it, per S12's stale-approval check (Q22). Do not
    add an auto-reject hook here; Q22 explicitly rules it out ("not a case in practice; the React app is only
    used as the fallback for hand-overs, never at the same time as the agent").
  - The same controller/view file this step creates is edited again by S16 (adds the pending/handed-
    over badge to the React app's OWN controller, a different file — `Admins::Pens::MicroClustersController`,
    not this step's `PenVariantClustererController`) and later by S36/S38/S42 (which extend the shared
    partial and presenter for L2/checkers/L3) — land this step first so those all have something to
    extend rather than parallel-build against.

- **Decisions applied.** Q22 (a refused approval is just an ordinary rejected log — no special
  controller branch), Q8 (`owner_with_collected_pens` on both the rendered scope and the count), Q24(i)
  (title, dashboard and depth all count waiting + processing through the same definition), Q24(ii)
  (agent-decided logs are rendered for spot checks but not counted), Q25(i) (presenter population = latest 500 manually processed logs, minus
  `auto_rejection`-tagged rows), Q25(ii) (delete-history preserves the just-typed note on a fresh
  guidance log, never wipes sibling clusters' history — fixed on both the pen and the ink page in this
  PR).

### S15-pen-drip-enable — Set `PEN_CLUSTERING_QUEUE_DEPTH=10`, first top-up, hand review for about two weeks

- **Goal.** This is a non-code, operational step: turn the pen agent queue on in production and watch it
  for about two weeks. It is also the **first prod DigitalOcean tool-calling traffic** for this app (Q32):
  `PenVariantClusterer` (built in S11-S12, wired to workers in S13 and to the review UI in S14) has
  been running against the DO catalog model picked by S01,
  through the `config/llm.yml` entry S11 added, since S11 merged — but at queue depth 0 nothing was ever
  enqueued in prod. This step is the first time that changes.
  - Run `flyctl secrets set PEN_CLUSTERING_QUEUE_DEPTH=10 -a fountainpencompanion`. Setting a Fly secret
    restarts every machine (6 web + 1 worker, `kill_timeout 120s` in `fly.toml`), so do it at a quiet hour
    or `--stage` it and let the next deploy pick it up.
  - In `fly console`, run `TopUpPenClusteringQueue.perform_async` — **not** `.new.perform`, so the run
    executes on the worker machine and shows up in Sidekiq Web (`/admins/sidekiq`,
    `config/routes.rb:177`). `TopUpPenClusteringQueue` itself carries no throttle; the ten
    `RunPenClustererAgent` jobs it enqueues are what hold the limit-1 concurrency slot (S13), which is
    why they execute serially.
  - With Sidekiq concurrency 1 for this worker class, the first ten runs execute serially (roughly
    30-60 s each), so expect about 10 minutes before all ten logs reach `waiting-for-approval`. Confirm
    within that window that none is stuck in `processing` past 15 minutes (`RunFailedClusterJobs` would
    requeue it, per S13) and that none gets auto-rejected by `CleanUp` at the 3-hour mark.
  - Watch the first ten runs the same day: `DecisionNotReachedError` rate, run latency including the
    `embedding_search` call, tokens per run compared with the 5,337-token InkClusterer 30-day average,
    `search_web` calls per run, and `agents` queue latency.
  - Add to the day-one watch list, because this is the first real DO traffic in prod (Q32):
    - `usage["model"]` on the new `AgentLog` rows shows the DO response's `model` string (recorded by
      S01 checklist item (10)), not an OpenAI id — confirm it matches what S11's config entry requested.
    - DO 429 responses and RubyLLM's built-in 3x HTTP retry (Q4 kept the gem default; no code changed
      this).
    - The `DecisionNotReachedError` rate specifically on the DO model (compare against whatever the S01
      spike observed on a handful of manual runs — there is no prod baseline yet).
    - Any `RunFailedClusterJobs` requeue here means a transcript **replay against DO** (tool-call ids and
      role `developer` system messages resent to the same provider that produced them — same-provider
      replay, not the cross-provider case S01 item 3 tested for the later ink flips).
    - The S05 "model not found" alert should stay silent; if it fires, the DO catalog model id has
      changed or expired — see S05's runbook row for the manual replacement model.
    - Note the mixed run: pen agent `search_web` calls still go to `GoogleSearchSummarizer`, which stays
      on OpenAI `gpt-4.1-mini` until S31 (Q14 applies only inside the bench/shadow harness, not to the
      live drip) — so a drip run is DO for the parent decision and OpenAI for its sub-agent call.
  - Then review every decision by hand for about two weeks, in parallel with the S16-S21 build (marker,
    bench DB, embeddings config, ink decide entry point, harness core, pen bench cases). Track, per
    action — the four literal `extra_data["action"]` values S11's tools write, which are also what the
    step's own `GROUP BY extra_data->>'action'` SQL and S14's presenter buckets key on:
    `assign_to_variant`, `create_new_variant`, `ignore_pen`, `hand_over_to_human` — approval rate,
    hand-over rate, `DecisionNotReachedError` rate, and tokens and latency per run (pen plan P1 asks
    for all five over the two weeks, not only on day one). Rejection notes typed during this review are the tuning input for S33 (directive tuning) and
    become the bench's hard-negative subset once S21 exports pen cases from a refreshed bench copy.
  - Cost: at the DO catalog price S01 recorded for the picked model (roughly a fifth of gpt-4.1's
    measured $0.012/run — 5,337 prompt + 165 completion tokens at gpt-4.1 rates, per the prod data
    check — for a Haiku-class candidate; use the exact per-token price from S01's catalog note, not
    this estimate, once it exists), so a batch of ten costs a few cents, not $0.12. Runs per day
    equal reviews per day plus retries; with 1-5 review batches a day, expect well under $1/day. This
    bound holds only because `RunPenClustererAgent` carries the `retry: 2` cap from S13, and because
    `RunFailedClusterJobs` requeues are counted in it.
- **Depends on.** S14 (admin review controller so decisions can actually be approved/rejected), S13
  (workers: `RunPenClustererAgent` retry cap, `TopUpPenClusteringQueue`, `RunFailedClusterJobs` pen
  branch), S05 (model-not-found alert must exist before the first prod DO traffic), S00 (Fly login; the
  `DO_INFERENCE_TOKEN` Fly secret, set no later than S11's merge, must already be live).
- **Why here.** Earliest possible start of the only feedback loop that costs weeks of calendar time.
  Everything in S16-S21 runs while labels accumulate, so this step does not wait on any of them; per the
  ordering skeleton, round 0 (S22) is the step that waits on this one ("about two weeks of drip").
- **Does not include.** No code changes. No change to the React marker (S16, which now ships **after**
  this step, not before it — see Decisions applied). No queue-depth change beyond 10 (S33 raises it later,
  once the owner sets the bar this step's Definition of Done asks for).
- **Definition of done.**
  - Kill switch documented in the pen plan's "Runbook" section (alongside S05's model-not-found runbook
    table). Depth 0 stops new top-ups only: already-enqueued `RunPenClustererAgent` jobs, Sidekiq retries
    and `RunFailedClusterJobs` do not consult the depth. Full stop procedure:
    `flyctl secrets set PEN_CLUSTERING_QUEUE_DEPTH=0 -a fountainpencompanion`, then in Sidekiq Web delete
    any `RunPenClustererAgent` jobs from the `agents` queue and from the Retry/Scheduled sets, then in
    `fly console`:
    `AgentLog.where(name: "PenVariantClusterer", state: [AgentLog::PROCESSING, AgentLog::WAITING_FOR_APPROVAL]).find_each(&:reject!)`
    so `RunFailedClusterJobs` has nothing left to requeue.
  - Weekly numbers per action recorded in the pen plan (see the SQL below), for the full two weeks.
  - At the end of the two weeks, **the owner sets the Q27 approval-rate bar** that later gates S33's
    depth raise and S38 (pen checkers). This is a human decision, not code, but this step's DoD is not
    complete until it is recorded in the pen plan alongside the two candidate yardsticks below, so the
    later steps have something concrete to check against:
    - (a) the ink agent's recent **human-only** monthly per-action approval rate, as a point of
      comparison: all-time `assign` 95.8% vs `create` 76.7%; monthly human approval 78-92% except a dip to
      64-68% in August 2026 (1,000-1,170 decisions that month) and 89% in September 2026; by
      `created_at` month: Feb-Apr 83-86%, May 78.7%, Jun-Jul 83-84%, Aug 68.3% — all of this excluding the
      ink Human checker's auto-approvals (231-237 parent logs) and the empty-cluster pseudo-action (74
      rows, the ink analogue of the Q19 marker).
    - (b) the simpler all-time approval figure, 84.8% ("~85%"), as the other candidate bar.
    - The owner picks one of these (or a value between them) once real pen drip data exists; this step
      only has to make sure both numbers, and the pen drip's own two-week per-action numbers, are on
      record when that choice is made.
- **Decisions applied.** Q32 (pen agents are DO agents from birth; this is the first prod DO
  tool-calling traffic, not the eventual backfill or an ink flip — added watch items above), Q26 (the
  React marker, S16, is no longer a dependency of this step and ships one PR after it), Q28 (queue depth
  10 — the decided depth), Q27 (the approval-rate
  bar is explicitly deferred to the owner, after this step, with both yardsticks recorded here so the
  choice has data to work from).
- **Implementation notes.**
  - How to observe (there is no timing column on `agent_logs`, and prod's `pg_stat_statements` is
    unreadable by the read-only role): run latency = `updated_at - created_at` on the log; tool calls per
    run = count of `tool_calls` entries in the `transcript` array (filter by name `search_web` to isolate
    web-search calls); DB latency of `embedding_search` via `/admins/pghero` → Queries (app role,
    `config/routes.rb:178`) or New Relic transaction traces (enabled in production,
    `config/newrelic.yml`); Sidekiq queue latency via `/admins/sidekiq`.
  - Weekly numbers SQL (per action, per state, per approval, excluding auto-rejections):

    ```sql
    SELECT extra_data->>'action' action, state, agent_approved, count(*)
    FROM agent_logs
    WHERE name = 'PenVariantClusterer'
      AND created_at > now() - interval '7 days'
      AND coalesce(extra_data->>'auto_rejection', '') = ''
    GROUP BY 1, 2, 3
    ORDER BY 1, 2;
    ```

    `auto_rejection` is the tag S11 (empty-cluster marker, `"empty_cluster"`) and S13
    (`CleanUp::RejectAgentLog`, `"orphaned"`) write; it exists on no row created before those merge,
    so the `coalesce(...) = ''` clause is a no-op for pre-S13 rows and a real filter afterwards.
    Run this every week for two weeks (or however often you want an interim read) via the prod
    read-only console/role; do not run it against the bench DB — this is a prod-only count.

  - Prod numbers used as the earlier baseline are current as of 2026-09-14: nothing has been manually
    assigned at L1 since January 2026 (61 rows last touched 2026-01, zero since); InkClusterer's 30-day
    average is 5,337 prompt tokens over 999 runs; there are 96,713-96,827 unassigned, non-ignored pen
    micro clusters with pens (the `with_collected_pens` scope from S06 is what this count, and every
    later queue/dashboard/cleanup query, must go through).
  - Sanity check before flipping the secret: confirm S14's admin review page already shows the pen queue
    (even at depth 0, with 0 items) and that a manually created `waiting-for-approval`
    `PenVariantClusterer` log on the dev/bench copy renders and can be approved/rejected there, so the
    two-week review actually has a working UI on day one.

### S16-pen-react-marker — Badge plus index filters for pending-agent-log and handed-over clusters in the pens-micro-clusters React app

- **Goal.** Ship this **after** the drip (S15) is already live and running (Q26). Its purpose is not
  "prevent double work" — the owner has confirmed humans never work the React app and the agent queue at
  the same time (Q22) — its purpose is to make the hand-over fallback workable: give a human a way to
  find, in the `pens-micro-clusters` React app, the clusters the agent has handed over or is currently
  working, so they can be resolved there.
  - `PensMicroClusterSerializer` (three attributes today) gains **two** boolean-shaped signals, not one:
    - `pending_agent_log`: true when the cluster has a `PenVariantClusterer` `AgentLog` in state
      `processing` or `waiting-for-approval`.
    - `handed_over` (this exact name everywhere: serializer attribute `handed_over`, filter param
      `handed_over=true`, shared method `Pens::MicroCluster.handed_over_to_human_ids`): true when the
      cluster's **LATEST** `PenVariantClusterer` log is `approved` with
      `extra_data->>'action' = 'hand_over_to_human'` (Q23, Q26) — latest-log, computed as
      `SELECT DISTINCT ON (owner_id) id FROM agent_logs WHERE name = 'PenVariantClusterer' AND
owner_type = 'Pens::MicroCluster' ORDER BY owner_id, id DESC`, then filtered to `approved` with
      that action. This is the same set S13's `TopUpPenClusteringQueue` excludes from refills, and the
      two call ONE method: S13 defines `Pens::MicroCluster.handed_over_to_human_ids` (latest-log, never
      any-log) and this step calls it. Do not hand-write a second query here. A human who assigns or ignores a handed-over cluster in the React app
      drops out of both places for a different reason: both start from
      `Pens::MicroCluster.unassigned.without_ignored` (pens/micro_cluster.rb:10-11), and the hand-over
      log itself is never touched (Q23: no timestamp touch, no new log —
      `Admins::Pens::MicroClustersController#update`, micro_clusters_controller.rb:40-45, writes no
      `AgentLog` at all).
  - This serializer is reused by `has_many :micro_clusters` in
    `app/serializers/pens_model_variant_serializer.rb:4` and by the single-record render in
    `Admins::Pens::MicroClustersController#update` (`:44`); `#index` also adds
    `.joins(...).group("pens_micro_clusters.id")` when `params[:count]` is set (`:10-17`) and paginates
    with Kaminari (`paginates_per 100`, `pens/micro_cluster.rb:8`), so a virtual column added via `select`
    alone is not safe across every code path. Use the controller-computed-set shape: the controller
    builds `pending_ids` and `handed_over_ids` (two `AgentLog` queries — the second one being
    `Pens::MicroCluster.handed_over_to_human_ids`, the single shared method the worker also calls) and
    passes `params: { pending_ids:, handed_over_ids: }` into the serializer, whose attributes read from
    those sets. Note the parentheses — a brace block cannot attach to a paren-less method call that
    already has an argument, so the obvious spelling is a Ruby syntax error:
    ```ruby
    attribute(:pending_agent_log) { |mc, params| params[:pending_ids]&.include?(mc.id) || false }
    attribute(:handed_over) { |mc, params| params[:handed_over_ids]&.include?(mc.id) || false }
    ```
    There are TWO option builders to edit in the controller, not one: `index_options(rel)`
    (micro_clusters_controller.rb:70-80) and `update_options` (:61-68) — merge
    `params: { pending_ids:, handed_over_ids: }` into both (for `update_options`, compute the two sets
    for the single updated cluster). Gotcha: `Admins::Pens::ModelVariantsController` renders the same
    serializer with no `params:` at all (model_variants_controller.rb:8, :26, :31); that stays harmless
    only because its sparse fieldset at :58 (`fields: { pens_micro_cluster: %i[model_variant collected_pens] }`)
    excludes the new attributes, which is why the exact-match spec at
    spec/requests/admins/pens/model_variants_controller_spec.rb:70-73 (`"attributes" => {}`) stays
    green — do NOT add the new attributes to that fieldset.
  - React: this is NEW UI. There is no badge pattern anywhere in `app/javascript/src/admin/`
    (`grep -rn "badge"` returns nothing), so use Bootstrap, which the app already loads:
    `span.badge.bg-warning` for `pending_agent_log` and `span.badge.bg-info` for `handed_over`. The
    mount point is
    `app/javascript/src/admin/components/clustering/DisplayMicroCluster.jsx` — render the badges above
    its `<table>`, guarded by `activeCluster.pending_agent_log` / `activeCluster.handed_over` so the
    ink app, whose clusters carry neither attribute, renders unchanged. Do NOT put them in
    `EntriesList.jsx` (that renders collected-pen rows, not micro clusters) and do not look for a
    micro-cluster LIST to hang a per-row badge on: the micro cluster is rendered one at a time by
    `DisplayMicroCluster.jsx` (reading `activeCluster` from `StateContext`, :16) inside the prev/next
    carousel in `DisplayMicroClusters.jsx:24-48`.
  - Two index filter params (`pending=true` / `handed_over=true`) on the controller, mirroring the
    boolean-param pattern already at `micro_clusters_controller.rb:18-19` (e.g.
    `clusters = clusters.unassigned if params[:unassigned]`). On the JS side there is no filter UI
    today and `microClusterLoader` reaches `App` as a prop and is a `useEffect` dependency
    (App.jsx:25-28, :39), so a toggle's React state cannot reach the loader without rewiring it.
    Take the cheap faithful route instead: read the two flags from the URL exactly the way `count` is
    already read. In `loadMicroClusterPage`
    (`app/javascript/src/admin/pens-micro-clusters/microClusters.js:76-84`; the query string is built
    at :77, the `count` precedent at :78-81) add:

    ```js
    ["pending", "handed_over"].forEach((k) => {
      if (location.search.match(new RegExp(k + "=true"))) search += "&" + k + "=true";
    });
    ```

    and render two `<a>` links in `Summary.jsx` pointing at `?pending=true` and `?handed_over=true`.
    (If real in-page toggles are wanted later, `getMicroClusters` must become a factory
    `getMicroClusters(filters)` wrapped in `useCallback` in `pens-micro-clusters/index.jsx` so the
    changed `microClusterLoader` identity re-triggers App.jsx's load effect — out of scope here.)
    The app already polls every 30 s while its list is empty (`App.jsx:32-39`), so both the badge and
    the filtered list refresh on their own without any new polling code.

  - The shared row component `DisplayMicroCluster`/`EntriesList`
    (`app/javascript/src/admin/components/clustering/`) is used by the ink React app too
    (`app/javascript/src/admin/micro-clusters/index.jsx:3`; the pen app passes `extraColumn = () => {}`,
    `pens-micro-clusters/index.jsx:32`). Guard both new badges behind the presence of their attribute so
    the ink app (which never receives `pending_agent_log`/`handed_over`) renders unchanged — do not fork
    the shared component into a pen-only copy.
- **Depends on.** S06 (the `with_collected_pens`/hand-over scopes this reuses), S13 (the exact
  hand-over-exclusion scope this filter must match), S14 (same controller file,
  `admins/pens/micro_clusters_controller.rb`, already edited there for guidance logs — expect to add to,
  not fight, that diff). Ordered **after** S15 (Q26): the drip must already be producing pending and
  handed-over logs before this ships, otherwise there is nothing to demonstrate the badge against.
- **Why here.** In v1 this step shipped before the queue went live, framed as preventing double work
  between a human and a running agent. Q22 says that scenario does not happen in practice (the React app
  is only ever the hand-over fallback, never used concurrently with the agent queue), so that framing is
  dropped entirely. Q26 moves the step to after the drip instead: nobody has manually assigned a pen
  cluster at L1 since January 2026 (prod query, 2026-09-14), so the one-PR delay while S15 runs costs
  nothing, and building it after the drip means the two real cases (a `waiting-for-approval` log and an
  approved hand-over) already exist in prod to build and test against.
- **Does not include.** Any change to `Pens::UpdateMicroCluster` — that worker's real-time trigger belongs
  to S40. Any change to `TopUpPenClusteringQueue`'s own exclusion logic: S13 already ships
  `Pens::MicroCluster.handed_over_to_human_ids` as a reusable class method, so this step only calls it.
- **Definition of done.**
  - Serializer spec updated: the exact `match` hash at
    `spec/requests/admins/pens/micro_clusters_controller_spec.rb:22-45` gains
    `"pending_agent_log" => false/true` **and** `"handed_over" => false/true`, with one spec case per
    combination that matters: no log, a `processing` log, a `waiting-for-approval` log, and an approved
    `hand_over_to_human` log.
  - A request spec per new filter param. There is no existing filter spec in that file to mirror (its
    `#index` block has exactly two examples, "requires authentication" at :7 and "renders the json" at
    :15), so write it out: inside the existing `describe "#index" > context "signed in"` block create
    three `:pens_micro_cluster` records — one with a `:waiting_for_approval` `PenVariantClusterer` log,
    one with an `:approved` log carrying `extra_data: { action: "hand_over_to_human" }`, one with no
    log — then `get "/admins/pens/micro_clusters.json?pending=true"` and assert
    `JSON.parse(response.body)["data"].map { |d| d["id"] }` contains only the first; repeat for
    `handed_over=true` and the second.
  - Jest test next to `DisplayMicroCluster.spec.jsx` (colocated) or under
    `spec/javascript/src/admin/components/clustering/` (both patterns already exist in this repo; the
    Jest config has no `testMatch` restriction that would prevent either) asserting the badge renders for
    each attribute and that the ink app's render is unchanged when the attributes are absent.
  - Badge and both filters visible and working on the dev/bench copy against a hand-made log of each
    kind (see seed snippets below).
- **Decisions applied.** Q26 (scope = badge plus the two filters described above; ships after the drip,
  not before it; purpose is hand-over workability, not double-work prevention), Q23 (the hand-over filter
  reuses S13's exact exclusion scope so the two never drift), Q22 (every "prevent double work" framing,
  the auto-reject-from-React-controllers idea, and any flash-message/tag design tied to that framing is
  dropped — the owner has confirmed this scenario does not occur).
- **Implementation notes.**
  - Seed data for manual verification and for the request spec, using the factory traits in
    `spec/factories/agent_logs.rb`:
    ```ruby
    # pending
    create(:agent_log, :waiting_for_approval, owner: pens_cluster, name: "PenVariantClusterer")
    # handed over
    create(:agent_log, :approved, owner: pens_cluster, name: "PenVariantClusterer",
           extra_data: { action: "hand_over_to_human" })
    ```
    For a console/manual check on the dev copy, the equivalent direct-create call is:
    ```ruby
    AgentLog.create!(
      owner: Pens::MicroCluster.unassigned.without_ignored.joins(:collected_pens).first,
      name: "PenVariantClusterer",
      state: AgentLog::WAITING_FOR_APPROVAL,
      transcript: []
    )
    ```
    (`transcript` is `NOT NULL`, so it cannot be omitted even for a hand-made log.)
  - This PR edits the same controller file S14 already edited for guidance logs; rebase onto S14's merge
    rather than developing this in parallel against a stale copy — a trivial conflict is expected either
    way, but starting from the merged file avoids re-deriving S14's diff.
  - Because the hand-over filter must match S13's exclusion scope exactly, write it as one shared method
    called from both places (worker and controller/serializer) rather than two independently-maintained
    queries — if S13 did not already extract this into a reusable scope, do that extraction as part of
    this PR's diff, not as a silent behavior change to S13.

### S17-bench-db — Bench database tooling; kick off the first dump

- **Goal.** Scripts that run inside the `app`/`postgres` containers (PostgreSQL 17.x tools; the host's
  Postgres.app 18.1 must never be used):
  `pg_dump -Fd -j4 --no-owner --no-privileges` from `PRODUCTION_READONLY_DATABASE_URL`, with **no
  `--exclude-table-data` at all**. Q7 decides "full prod copy, no PII blanking, no retention rule", so
  every table's data is dumped — including `versions` (the PaperTrail table on
  `MacroCluster`/`BrandCluster`, `macro_cluster.rb:31`, `brand_cluster.rb:2`). The
  `versions`/`usage_records` exclusion idea came from the evidence maps, not from either plan, and Q7
  replaced it; if dump time later proves to matter, raise it as a new question rather than reviving
  the exclusion. `usage_records` (689,695 rows, 94 MB — minutes of dump time) stays for the same
  reason and for one of its own: `PenAndInkSuggester`'s prompt rows derive `usage_count`/`daily_usage_count`/`last_usage` from it
  (`pen_and_ink_suggester.rb:241,249`; `collected_pen.rb:65-66,77-82`; `collected_ink.rb:183,229-234`),
  and S28 exports its cases from the bench DB, so this table must be present and complete.
  - **Full copy, no exclusions, no PII blanking, no retention rule (Q7).** Do **not**
    `--exclude-table-data=users` — nor any other table — and do
    **not** run any blanking SQL afterward. Seven `FOREIGN KEY (user_id) REFERENCES users(id)` constraints
    exist (`db/structure.sql:2248,2272,2296,2368,2376,2408,2448`) that would make `pg_restore` fail in the
    post-data section if `users` rows were excluded while other tables still reference them, and both
    `PenAndInkSuggester` and `SpamClassifier` cases need real `users` rows to build correct prompts. The
    bench DB is therefore a full, unmodified prod copy: real email addresses, real encrypted passwords,
    everything. There is no retention rule to build or document — Q7 settles this permanently, it is not
    a per-refresh choice.
  - **Bench DB selection (Q6).** Restore into a second database in the **same Postgres container** as
    dev, selected by one env var: `database: <%= ENV.fetch("DATABASE_NAME", "fountainpencompanion_development") %>`
    in the development block of `config/database.yml` (this is the only `config/database.yml` change this
    step makes — do not add a separate `bench` Rails environment). Running
    `-e DATABASE_NAME=fountainpencompanion_bench` against the `app` container points the **whole
    process** (every `ApplicationRecord` model, so the real agents, tools and jobs) at the bench database
    with no other configuration change.
  - **Refresh cadence (Q6).** Refresh the bench DB from a fresh prod dump only before MAJOR rounds — S22
    (round 0, this step's first consumer) and S30 (the paid chat bench round). Minor rounds (S33's pen
    directive-tuning iterations, S38's checker bench) re-export cases **from the existing bench copy**,
    which is exactly what Q6 says. Reading a label from `PRODUCTION_READONLY_DATABASE_URL` (e.g. a
    newly rejected drip log) is an ADDITION beyond Q6, allowed only under one constraint that has to
    be stated wherever it is used: a case can only be RUN against owners that exist in the bench copy,
    so any log whose owner or corrected state postdates the copy is reportable but NOT runnable until
    the next major-round refresh. The next refresh after this
    step's first dump is S22's (bench refresh #1); there is no refresh between the two, and none at
    S21. Do not refresh a second time before S22.
  - Skip the two HNSW indexes on restore and rebuild them afterward with a raised `maintenance_work_mem`
    (a docker-compose `command:` override; the container default is 64 MB, far too low for a 1536-dim/
    1024-dim HNSW build at this row count).
  - **Isolation is code, not procedure, and must be spelled out precisely:** a shared `Bench.isolate!`
    helper, called at the _top of every_ `bench:*` rake task block (never at file load time — Rails loads
    every `lib/tasks/*.rake` for _any_ rake invocation, including the Fly release command, so requiring
    `sidekiq/testing` at the top level of a rake file would switch the whole boot process to fake Sidekiq
    mode):
    - `require "sidekiq/testing"; Sidekiq::Testing.fake!` (inside the task block).
    - `Rails.cache = ActiveSupport::Cache::RedisCacheStore.new(url: ENV.fetch("BENCH_REDIS_CACHE_URL", "redis://redis:6379/6"))`
      — `development.rb:23-25` builds the cache store from `REDIS_CACHE_URL` at boot, and dev already uses
      Redis DB 0 (Sidekiq) and DB 1 (cache), so the bench process needs its own DB number to avoid
      colliding with a running dev/sidekiq container.
    - Abort immediately with an explicit "not a bench database" error unless BOTH
      `ActiveRecord::Base.connection_db_config.database.end_with?("_bench")` AND `Rails.env.development?`
      hold. This means a forgotten `-e DATABASE_NAME=...` flag, or a mistyped bench task accidentally run
      in a prod console, cannot silently run bench logic against the wrong database. The **only**
      exception is the `bench:db:*` tasks themselves (dump/restore/rebuild-indexes), which name the bench
      database explicitly as an argument and therefore skip this guard by construction (they are what
      creates the `_bench` database in the first place).
    - Call `Sidekiq::Worker.clear_all` once per bench case run (not once per task invocation) so fake
      queues accumulated across ~200 cases do not grow unbounded in memory.
  - **Add `.dockerignore`** (this file does not exist in the repo today — verified). At minimum:
    `bench/data`, `.env.local`, `coverage`, `node_modules`, `log`, and `tmp/*` with `!tmp/pids/.keep` (or
    scope it to just `tmp/cache` and `tmp/*.pid` if a blanket `tmp/*` proves too aggressive). The
    production Dockerfile's `prod-build` stage does `COPY . .` (Dockerfile:98) and then
    `RUN bundle exec bootsnap precompile app/ lib/` (:101); the final `prod` stage does
    `COPY --from=prod-build /app /app` (:124), `RUN rm -rf /app/tmp/cache /app/tmp/pids
/app/tmp/sockets /app/log` (:126) and `RUN mkdir /app/tmp/pids` (:127, no `-p`). So with `tmp`
    excluded, `COPY . .` creates no `/app/tmp` and it is the bootsnap precompile that creates
    `/app/tmp/cache`, which survives the stage copy so that the final `mkdir /app/tmp/pids` still
    finds an existing `/app/tmp`. `/app/log` is removed at :126 and nothing recreates it — check that
    at boot. Verify the image still builds after this change (see Definition of done). This is a
    change to the production image, not just to local dev: CI's `docker-build` job is a signal but the
    `deploy` job does **not** wait for it (`needs: [rspec, jest]` in `.github/workflows/ci.yml`), so the
    Fly remote build is what actually fails safe if `.dockerignore` breaks something; a runtime-only
    omission (something needed at boot but excluded here) would only be caught by that build failing, not
    by CI. Also gitignore `bench/data` (the migration plan already decides on gitignored JSON case files
    under `bench/data/`, `docs/llm-migration-plan.md:188`) and add the same path to `.prettierignore`
    (nine entries today: `.yarn`, `.ruby-lsp`, `coverage/`, `app/assets/builds/`, `node_modules/`,
    `public/`, `spec/fixtures/`, `tmp/`, `vendor/`).
  - Document on merge: ~14 GB on disk for the dump, roughly 15 GB+ of text-serialized vectors within it,
    a transfer rate of 1-1.5 MB/s from DO (so hours, not minutes, for the full dump), and that prod runs
    pgvector 0.7.4 while local/dev runs 0.8.2 — a version gap worth knowing about if an index-build or
    query-plan difference ever looks suspicious.
  - Kick off the first dump right after this PR merges; it runs in the background while S18 (embeddings
    config) and S19 (ink `decide` entry point) are being built. This first dump serves S20's smoke run
    and ink-exporter development, and S21's pen-exporter development. The pen CASES S22 grades come
    from the refreshed copy S22 makes (bench refresh #1, Q6), because they need two weeks of drip
    labels — so do not refresh again before S22.
- **Depends on.** S08 (stale-data cleanup — the prod tables this dumps should already be free of the
  decided-for-deletion empty rows and orphans before the first dump, so the bench copy does not need a
  second cleanup pass later).
- **Why here.** This is long wall-clock activity (hours) that should start as early as its one
  prerequisite allows, because every later bench step depends on it: S20 (harness core), S21 (pen bench
  cases), S22 (round 0), S23 (embeddings bench), S28 (checker/ReviewApprover bench), S29 (pen L2 case
  exporter), S30 (chat bench round). Q6 fixes the refresh cadence described above, so there is no open
  question left about when to refresh again.
- **Does not include.** The harness itself, or any case export. The harness location is settled, not a
  question this step touches: `lib/bench/` per `docs/llm-migration-plan.md:190`, loaded via explicit
  `require` from the rake tasks (outside Zeitwerk autoloading, but still Prettier-checked and
  SimpleCov-tracked). The dump/restore SHELL-OUTS themselves are plain `pg_dump`/`pg_restore`
  invocations wrapped in rake tasks and need no harness Ruby — but `Bench.isolate!` (below) IS Ruby
  this step ships, because S20 and every later `bench:*` task calls it on its first line.
- **Definition of done.**
  - `bench:db:dump` and `bench:db:restore` (or `bin/bench-db-dump`/`bin/bench-db-restore`) rake tasks in
    `lib/tasks/bench_db.rake`, with real timings from the first run recorded in the migration plan (dump
    duration, restore duration, index-rebuild duration).
  - `lib/bench/isolate.rb` defining `module Bench; def self.isolate!; ...; end; end` with the four
    behaviours described above, `require`d explicitly from `lib/tasks/bench_db.rake` (`lib/` is not
    autoloaded) and from every later `bench:*` rake file — S20's harness opens every task with
    `Bench.isolate!`, so it must exist and be requirable when S20 starts. Spec at
    `spec/lib/bench/isolate_spec.rb` covering BOTH guard branches (the database-name check and the
    `Rails.env.development?` check) — `lib/` is SimpleCov-tracked and CI enforces the 0.2% project /
    5% patch coverage thresholds, so untested `lib/` code costs coverage.
  - Restore verified: row counts for `micro_clusters`, `pens_micro_clusters` and `agent_logs` in the bench
    DB match counts taken on `PRODUCTION_READONLY_DATABASE_URL` **at dump start time**, not at whatever
    moment you happen to check afterward — `pg_dump -Fd` is one consistent snapshot, but `agent_logs`
    grows 150-200 rows/day in prod, so a count taken even a day later will not match and is not a valid
    check.
  - `EXPLAIN` shows the rebuilt HNSW indexes are actually being used. In a bench-DB Rails console:
    ```ruby
    InkEmbedding.nearest_neighbors(:embedding, Array.new(1536, 0.01), distance: "cosine").limit(200).explain
    ```
    and the `PenEmbedding` equivalent, must each show `Index Scan using index_ink_embeddings_on_embedding`
    / `index_pen_embeddings_on_embedding` (index definitions at `db/structure.sql:1911` and `:2065`) — not
    a sequential scan, which would mean the rebuild step silently failed or used the wrong dimension.
  - `.dockerignore` merged; CI's `docker-build` job green; the next real Fly deploy healthy (confirms
    `.dockerignore` did not accidentally exclude something the production image needs at boot).
  - There is no "no real email addresses" check in this DoD — the bench DB intentionally keeps them
    (Q7).
- **Decisions applied.** Q6 (bench DB = second database in the same Postgres container via
  `DATABASE_NAME`; refresh only before major rounds, minor rounds re-export from the existing copy),
  Q7 (full prod copy, no PII blanking, no retention rule — this replaces the v1 text's conditional
  blanking-SQL branch entirely).
- **Implementation notes.**
  - Run the dump from the `app` container: it has `pg_dump` 17.10 and
    `PRODUCTION_READONLY_DATABASE_URL` available via `env_file: .env.local`
    (`docker-compose.yml:19-23`); the `postgres` container has neither by default. Write the `-Fd`
    directory output under `tmp/bench_dump/` (a bind mount, already gitignored) — or, alternatively, pass
    `-e PRODUCTION_READONLY_DATABASE_URL` to the `postgres` container and write inside its own volume
    instead, per the pattern noted in the infra map.
  - Prod is the primary, not a standby (`pg_is_in_recovery()` returns false), so `-j4` parallel/
    synchronized-snapshot dumps work correctly. `max_connections` is 50 with roughly 24 already in use and
    no per-role connection limit — a 4-way parallel dump adds 5 connections for the duration of an
    hours-long dump, so run it off-peak, not during a normal business-hours window.
  - Skip-then-rebuild recipe for the HNSW indexes:
    ```
    pg_restore -l dump.dir > toc.list
    grep -v -E 'INDEX .* index_(ink|pen)_embeddings_on_embedding' toc.list > toc.noidx
    pg_restore -j4 --no-owner --no-privileges -L toc.noidx -d fountainpencompanion_bench dump.dir
    ```
    then, in a bench-DB session:
    ```sql
    SET maintenance_work_mem = '2GB';
    CREATE INDEX index_ink_embeddings_on_embedding ON ink_embeddings USING hnsw (embedding vector_cosine_ops);
    ```
    and the pen equivalent (both index definitions live at `db/structure.sql:1911` and `:2065`).
    `createdb -U fpc fountainpencompanion_bench` must run first; the dump itself carries
    `CREATE EXTENSION IF NOT EXISTS vector`, so the extension does not need to be created by hand.
  - Example docker-compose `command:` override to raise Postgres memory settings for the rebuild (the
    infra map's recommendation):
    ```
    command: postgres -c maintenance_work_mem=2GB -c shared_buffers=1GB -c max_wal_size=4GB -c max_parallel_maintenance_workers=4
    ```
    Note this setting applies to the **whole** Postgres container, including the ordinary dev database,
    and needs `docker-compose up -d postgres` (a container restart) to take effect — do not expect it to
    apply live.
  - Manual verification in dev/bench once restored: open a bench-DB Rails console
    (`docker-compose exec -T -e DATABASE_NAME=fountainpencompanion_bench app bundle exec rails console`)
    and confirm `ActiveRecord::Base.connection_db_config.database` reports `fountainpencompanion_bench`
    before running anything destructive against it; then run the `EXPLAIN` checks above.
  - Rollback: the bench database is disposable and never read by prod code paths — if a restore goes
    wrong, `dropdb fountainpencompanion_bench` and restore again; there is no prod-facing rollback
    concern for this step (the `.dockerignore` change is the only part that touches the production image,
    and its rollback is `git revert` + redeploy if the next Fly build is unhealthy).

### S18-llm-config-embeddings — Embeddings config, model-aware cache key, `fetch_many`, explicit-entry client, search constants wired to config, dev-branch removal, model-not-found matcher

- **Goal.** Rewrite `EmbeddingsClient` (app/lib/embeddings_client.rb, 31 lines today; cache key at
  line 14, hard-coded model string at line 15, bare `ENV.fetch("OPEN_AI_EMBEDDINGS")` at line 29) so
  it reads model, dimensions, and provider/api_base/key-env from `config/llm.yml` (the same file S04
  created, under a new `embeddings:` block — do not create a second YAML file), and so it can be
  constructed against an _explicit_ config entry rather than only the default one. Concretely:
  - Add an `embeddings:` block to `config/llm.yml` INSIDE the `shared:` section (with per-environment
    overrides under `production:`/`development:`/`test:` where an entry must differ). It is not an
    agent-class entry, but it also cannot be a sibling TOP-LEVEL key: `config_for` returns only
    `shared.deep_merge(current environment section)` (railties-8.1.3.1
    `lib/rails/application.rb:296-305`), so any other top-level key is silently dropped and
    `Rails.application.config_for(:llm)[:embeddings]` would be `nil` in every environment. One named entry for now: `legacy` — `provider: openai`, `model:
text-embedding-3-small`, `api_base: https://api.openai.com/v1` (or omitted, since that's the
    OpenAI default), `api_key_env: OPEN_AI_EMBEDDINGS`, `dimensions: 1536`. S24 (embedding_v2
    backfill) adds the `current` entry (pointed at the model S23 picked) plus the `dual_write` and
    `read` keys; S27 changes the VALUE of `read`. S23 adds no YAML entry: the constructor (below)
    accepts either a config entry NAME or an inline entry HASH, and S23 passes its four candidates in
    as inline hashes (`model:`, `api_base:`, `api_key_env:`, `dimensions:`, `provider:`,
    `assume_model_exists:`) through the same `resolve_entry` wrapper. Do not build the multi-entry shape yet beyond
    what "legacy" needs — S24 is where the second entry and the column parameter arrive. Read via
    `Rails.application.config_for(:llm)` exactly as S04 does (same file, so no new `config_for` call
    site is needed if S04 already memoises the whole parsed hash somewhere reusable — otherwise add a
    second `Rails.application.config_for(:llm)[:embeddings]` read; `config_for` is not expensive
    enough to bother caching beyond what S04 already did).
  - `EmbeddingsClient.new(entry_or_name = :legacy)` — a Symbol/String names an entry in
    `config/llm.yml`'s `embeddings:` block, a Hash IS an inline entry (this is the form S23's sweep
    uses, so the bench can address four candidates without adding four YAML entries). Either way the
    point Q1/Q3 fix is that the class no longer hard-codes `"text-embedding-3-small"` or reads `ENV`
    directly. It resolves the entry at construction time and stores it via `attr_accessor`
    (project convention per CLAUDE.md: prefer `attr_accessor` with `self.x = ...` in the constructor
    over bare `@x`), e.g. `attr_accessor :entry` with `self.entry = resolve_entry(entry_or_name)` in
    `initialize` (a Hash argument skips the `config/llm.yml` lookup and is wrapped directly).
    `resolve_entry` must WRAP the raw hash before storing it —
    `ActiveSupport::OrderedOptions.new.update(config_for(:llm)[:embeddings].fetch(entry_name) { raise ConfigurationError, ... })`,
    or a Struct — because `config_for` wraps only its top-level return value in `OrderedOptions`
    (railties `lib/rails/application.rb:307-309`) and everything nested stays a plain symbol-keyed
    Hash after `deep_symbolize_keys` (:295). Without the wrap, every `entry.model` / `entry.api_key_env`
    in this step raises `NoMethodError`. The bench (S23), dual-write (S24) and the read flip (S27) each construct
    `EmbeddingsClient.new(:current)` / `EmbeddingsClient.new(:dual_write)` / etc. to address a
    specific model without touching global config; nothing else in the app passes an explicit entry
    yet, so `EmbeddingsClient.new` (implicit `:legacy`) is what every existing caller keeps calling
    unchanged.
  - Cache key becomes `"embedding:#{entry.model}:#{entry.dimensions}:#{Digest::MD5.hexdigest(text)}"`
    (today it is bare `"embedding:#{digest}"`, embeddings_client.rb:14). This matters because
    `neighbor` 1.2.0 validates vector length on save (`lib/neighbor/model.rb:50-55`, raises "must have
    1536 dimensions") and again on `nearest_neighbors` query (:94-95); a 1024-dim vector served from a
    cache entry keyed only by text (left over from a 1536-dim model) would silently raise instead of
    degrading. Add the first spec of this cache (see Definition of done).
  - `dimensions` from the config entry is used ONLY for (a) the cache key and (b) validating the
    returned vector's length against the config's declared size; it is passed to the `embed(...,
dimensions:)` request parameter ONLY when the entry explicitly sets `send_dimensions: true`.
    Reason: ruby_llm-1.16.0's `providers/openai/embeddings.rb:14-19` sends `dimensions:` in the
    request body whenever it is non-nil, and `spec/workers/fetch_embedding_spec.rb:8-10` asserts the
    request body is **exactly** `{model:, input:}` for the legacy OpenAI model — so the legacy entry
    must never set `send_dimensions: true` (its `dimensions: 1536` is descriptive only, used for the
    cache key and validation). A future fixed-size DO/Voyage-style model can also omit
    `send_dimensions:`; only a Matryoshka/variable-size model as picked in S23 sets it to true if that
    candidate needs the request to constrain output size.
  - Build the context from the entry, not just from the key: `context` becomes
    `RubyLLM.context { |c| c.openai_api_key = ENV.fetch(entry.api_key_env) { raise ConfigurationError, ... }; c.openai_api_base = entry.api_base if entry.api_base.present? }`
    — today embeddings_client.rb:24-26 sets only `openai_api_key`, and ruby_llm-1.16.0 takes the base
    URL from `@config.openai_api_base || 'https://api.openai.com/v1'`
    (providers/openai.rb:17-18), so without this an `EmbeddingsClient.new(:current)` /
    `(:dual_write)` — the whole point of the explicit-entry client for S23/S24 — would still call
    api.openai.com with a DigitalOcean key. The `embed` call then passes
    `provider: entry.provider.to_sym, assume_model_exists: entry.assume_model_exists`.
    Both values come from the ENTRY, never hard-coded — that is the whole point of the config layer
    this step creates. `provider` is `openai` for OpenAI and DigitalOcean alike (S04's decided entry
    shape: `assume_model_exists` requires `provider:`), and the OpenAI/DO difference is expressed as
    CONFIG VALUES: the `legacy` entry sets `assume_model_exists: false` (the gem's registry already
    has `text-embedding-3-small` at `models.json:28621`, so nothing changes for today's only
    consumer), while every DO/candidate entry sets `assume_model_exists: true` because
    `RubyLLM::Models.resolve` (`lib/ruby_llm/embedding.rb:14-23`) raises `ModelNotFoundError` for any
    model id that is not in the bundled registry.
  - Replace the bare `ENV.fetch("OPEN_AI_EMBEDDINGS")` (embeddings_client.rb:29, raises bare `KeyError`
    if unset, silently different from the chat side's `nil`-tolerant fallback) with
    `ENV.fetch(entry.api_key_env) { raise ConfigurationError, "Missing embeddings API key env var
#{entry.api_key_env}" }` (or reuse whatever configuration-error class S04 introduced for the same
    situation on the chat side — check S04's `config/llm.yml` resolver file for a
    `LlmConfig::ConfigurationError` or similar and reuse it rather than inventing a second one).
  - **Remove the `Rails.env.development?` branch entirely** (embeddings_client.rb:26-30: today
    development reads `OPEN_AI_DEV_TOKEN`, everything else reads `OPEN_AI_EMBEDDINGS`). From this PR
    on, every environment reads the key named by the config entry's `api_key_env`
    (`OPEN_AI_EMBEDDINGS` for `legacy`). **This is the point at which `.env.local`'s
    `OPEN_AI_DEV_TOKEN` stops being read by anything** — S04 kept a copy of it around specifically
    because this client still branched on it until now (S04's DoD said so explicitly). Say this in
    this step's DoD: developers may now delete `OPEN_AI_DEV_TOKEN` from `.env.local` (S04 told them
    not to yet) — but only AFTER adding a real key to `.env.local` as `OPEN_AI_EMBEDDINGS=<key>`.
    This is a required task, not a likelihood: `.env.local` today carries `HCAPTCHA_*`,
    `OPEN_AI_DEV_TOKEN`, `GOOGLE_*`, `OPEN_ROUTER_DEV_TOKEN`, `SERPER_API_KEY` and
    `PRODUCTION_READONLY_DATABASE_URL` and has NO `OPEN_AI_EMBEDDINGS` line, while `.env:7` holds only
    the placeholder `OPEN_AI_EMBEDDINGS=xxx` — so removing the development branch without this step
    makes every dev embedding call authenticate with "xxx" and fail with 401. Verify with one console
    `EmbeddingsClient.new.fetch("test")` call in the dev container after this merge, then delete
    `OPEN_AI_DEV_TOKEN`.
  - `fetch_many(texts, cache: true)` — new method, batch counterpart to `fetch`. Uses RubyLLM's Array
    input support: `providers/openai/embeddings.rb:22-29` returns an `Array` of vectors (one per input
    string) when `text.is_a?(Array)`, mapped **in response order** without re-sorting by any `index`
    field returned by the API (line 25) — so this only works correctly if the provider is confirmed to
    return `data` in input order. S01 item (7) in the spike must have confirmed this for whichever DO
    candidate S23 might pick; if S01's finding was "unconfirmed" for a given provider, `fetch_many`
    must not be used against it without re-verifying — leave a comment citing S01's finding.
    - Chunk inputs to the provider's max batch size: OpenAI allows up to 2048 inputs per
      `/v1/embeddings` call; use whatever limit S01 recorded for the DO candidate(s) (default to 2048
      if S01 recorded nothing lower for the "current"/OpenAI-compatible path).
    - `fetch_many(texts, cache: true)` performs the SAME per-text `Rails.cache.fetch` wrapping as
      `fetch`, but batches the underlying HTTP call: partition `texts` into "already cached" and "not
      cached" (using the same model/dims-aware key), issue one (or one-per-chunk) `embed` call for the
      misses, then write each result to its own cache key exactly like `fetch` does, and return vectors
      in the same order as the input `texts` array (do not assume the miss subset preserves the
      original order — build a lookup by text and reassemble).
    - `fetch_many(texts, cache: false)` — the bulk path with NO per-text caching. This is what S23
      (bench, up to 4 candidate models over the corpus) and S24 (prod backfill) both use. Reason
      caching must be skippable: per-text caching writes 10-21 KB per 1024-float vector into Redis for
      a week; benching 4 candidate models against roughly 1.0M pen+ink rows would push 40-85 GB into
      the local `redis:7-alpine` dev container, and the one-time prod backfill would push 10-20 GB
      into the prod cache Redis for embeddings nothing will ever re-request from cache (the backfill
      writes straight to the DB column). `cache: false` must still return vectors in input order and
      still chunk to the provider limit; it simply skips every `Rails.cache` read/write.
  - Wire the S09 search constants to config. `MacroCluster::SIMILARITY_CUTOFF`,
    `MacroCluster::HNSW_EF_SEARCH`, `Pens::Model::SIMILARITY_CUTOFF` and
    `Pens::Model::HNSW_EF_SEARCH` (all added in S09) keep their names but read their VALUES from
    `config/llm.yml`'s `embeddings:` block, e.g.
    `embeddings: { search: { ink: { cutoff: 0.6, ef_search: 200 }, pen: { cutoff: 0.6, ef_search: 1000 } } }`.
    There is no second YAML file (Q1). Today's values become the defaults so nothing changes yet; S23 (bench sweep) and S27 (read flip) are what actually change
    them.
  - Wire the S05 "model not found" matcher into this client's embed call: `rescue RubyLLM::Error => e`
    around the `context.embed(...)` call, `if LlmErrors.model_not_found?(e)` then
    `Honeybadger.notify(e, error_class: "LlmModelNotFound", context: { client: "EmbeddingsClient",
entry: entry_name, model: entry.model, provider: entry.provider, api_base: entry.api_base })` and
    re-raise — same shape as S05's chat-side hook, reusing S05's `LlmErrors.model_not_found?` matcher
    (do not write a second matcher).
- **Depends on.** S04 (config file and its resolver/`ConfigurationError` class exist), S09 (the
  cutoff/ef_search constants this step wires to config must already exist as named constants), S05
  (the model-not-found matcher this step calls into `EmbeddingsClient`).
- **Why here.** The pen tools call `EmbeddingsClient` through `Pens::Model.embedding_search`
  (app/models/pens/model.rb:33-34), which stays on OpenAI `text-embedding-3-small` until the read flip
  (S27); none of the drip's traffic (S15) needs the model-aware cache key, `fetch_many`, or the
  explicit-entry client. The first real consumers of this rewrite are S20 (the harness's ink-bench key
  path — until this step lands, `MacroCluster.embedding_search` still goes through a client that
  branches on `Rails.env.development?`), S23 (the embeddings bench, needs `fetch_many(cache: false)`
  against up to four candidate entries) and S24 (the prod backfill, needs a column-aware batch call
  built on top of `fetch_many`). Landing this before the drip would add a PR to the drip's
  critical path for a capability the drip does not use.
- **Does not include.** The second `embedding_v2` DB column, dual-write logic, the `column:` parameter
  a caller passes to say which column it's populating (S24 introduces this — the config-entry
  shape here just needs to be able to grow a second named entry later without a rewrite), any actual
  model change (still `text-embedding-3-small` everywhere after this PR merges), the HNSW index work
  (S26).
- **Definition of done.**
  - New `spec/lib/embeddings_client_spec.rb` (does not exist today — `EmbeddingsClient` is currently
    only exercised indirectly through `spec/workers/fetch_embedding_spec.rb`, and asserted NOT to be
    instantiated for blank queries in `spec/models/macro_cluster_spec.rb:255-262` and
    `spec/models/pens/model_spec.rb:40-46` — those two are `expect(EmbeddingsClient).not_to receive(:new)`
    examples and need no change). Cases:
    - `fetch` caches by `model:dims:md5(text)`: stub `/v1/embeddings` once, call `fetch(text)` twice
      with the same entry, assert the stub was requested exactly once (test cache store is
      `:memory_store`, config/environments/test.rb:23, cleared before each example by rails_helper —
      confirm this is still true after S04/S09 changes).
    - Same `text`, two different entries (or the same entry with a different configured `dimensions`)
      → two distinct cache entries → stub requested twice.
    - `fetch_many(texts, cache: true)`: partial cache hit — pre-warm the cache for one of three texts,
      call `fetch_many`, assert the HTTP stub's request body contains only the two uncached texts as an
      Array, and the returned array has 3 elements in the original input order.
    - `fetch_many(texts, cache: false)`: no `Rails.cache` interaction at all (`expect(Rails.cache
).not_to receive(:fetch)`), one HTTP call, vectors returned in input order, chunked correctly
      when `texts.size` exceeds the configured batch limit (stub two separate requests, assert both
      were made and the two response arrays were concatenated in order).
    - Explicit entry: `EmbeddingsClient.new(:some_other_entry)` reads that entry's model/api_base/
      key-env, not `:legacy`'s.
    - Missing API key env var raises the clear configuration error, not `KeyError`. The key is read
      lazily inside `access_token` (first embedding call, never at boot) and CI sets
      `OPEN_AI_EMBEDDINGS: test` for the whole job (`.github/workflows/ci.yml:17`), so this example
      must stub `ENV` or use an entry whose `api_key_env` names a var CI does not set.
    - `Rails.env.development?` branch is gone: stub `ENV` in a `development`-tagged example (or use
      `Rails.env` stubbing) and confirm the same `api_key_env`-named var is read regardless of
      environment.
    - Model-not-found: stub the exact status/body S01 item (14) recorded → assert
      `Honeybadger.notify` receives `error_class: "LlmModelNotFound"` and the error re-raises; a plain
      500 (`RubyLLM::ServerError`) does not notify (mirror S05's spec shape exactly).
  - `spec/workers/fetch_embedding_spec.rb` stays green unchanged, still asserting the exact
    `{model: "text-embedding-3-small", input: "content"}` request body for the default (legacy) entry
    — this is the regression guard that `send_dimensions` defaults to false/absent for that entry.
  - Manual verification in dev: after merge, in the `app` container console, run
    `EmbeddingsClient.new.fetch("test string")` and confirm it succeeds using only `OPEN_AI_EMBEDDINGS`
    from `.env`/`.env.local` (no `OPEN_AI_DEV_TOKEN` involved) — this is the practical check that the
    dev-branch removal didn't break local embedding calls.
- **Decisions applied.** Q1 (config lives in `config/llm.yml`, entries addressable by name). Q3 (the
  bare `ENV.fetch("OPEN_AI_EMBEDDINGS")` becomes the config-named key of the legacy entry with a clear
  configuration error when missing; the `Rails.env.development?` branch is removed in this PR, meaning
  `OPEN_AI_DEV_TOKEN` becomes deletable from `.env.local` from this point on — S04 kept it only because
  this file still needed it). Q33 (the S05 model-not-found matcher is wired into the embed call here,
  not before).
- **Implementation notes.**
  - Callers to check for regressions (none of their call sites change, only the client's internals):
    `FetchEmbedding#fetch_embedding` (app/workers/fetch_embedding.rb:19-21, calls
    `EmbeddingsClient.new.fetch(model.content)`), `MacroCluster.embedding_search`
    (app/models/macro_cluster.rb:108-109, `EmbeddingsClient.new.fetch(query)`),
    `Pens::Model.embedding_search` (app/models/pens/model.rb:33-34). None of these three pass an
    entry name today, so all three implicitly use `:legacy` after this change — verify none of them
    needs updating to keep compiling if the constructor signature changes shape (i.e. keep
    `EmbeddingsClient.new` with zero args valid and equivalent to `EmbeddingsClient.new(:legacy)`).
  - Cache-key change on deploy invalidates the entire existing one-week embedding cache (every key
    changes from `embedding:<md5>` to `embedding:<model>:<dims>:<md5>`) — this causes one burst of
    re-embedding for repeated public ink/pen searches right after deploy; harmless and already noted in
    the v1 text, keep this note in the PR description.
  - The gem detail worth re-verifying before writing `fetch_many`: `providers/openai/embeddings.rb:22-29`
    — read the installed gem source directly. In the container (where CLAUDE.md says all app commands
    run), `docker-compose exec -T app bundle show ruby_llm` prints the path; on the host it is
    `~/.rbenv/versions/4.0.1/lib/ruby/gems/4.0.0/gems/ruby_llm-1.16.0/lib/ruby_llm/providers/openai/embeddings.rb`.
    Read it rather than trusting this note verbatim, since exact line numbers can drift between reads of the
    same version.
  - Rollback: this step touches no schema and no prod behaviour (embeddings still resolve to the same
    OpenAI model for every caller) — a `git revert` + merge is sufficient; no data migration to reverse.

### S19-ink-decide-entry-point — Side-effect-free `decide(agent_log:)` on InkClusterer; memoisation fix at ink_clusterer.rb:174

- **Goal.** Refactor `InkClusterer#perform` (app/agents/ink_clusterer.rb:180-205) so the LLM-calling
  part is a separate, side-effect-free method the bench harness (S20), the checker bench (S28) and
  shadow mode (S25) can all call directly without going through Sidekiq, `waiting_for_approval!`, or
  `schedule_follow_up!`.
  - Extract a new public method `decide(agent_log:)` with the SAME contract S11 already gave
    `PenVariantClusterer#decide` — one `decide` path across the codebase (section 4), so write it
    identically:

    ```ruby
    def decide(agent_log:)
      raise "chat already built" if @chat
      self.agent_log_id = agent_log.id
      @agent_log = agent_log
      ask!(user_prompt)
      agent_log.reload.extra_data
    end
    ```

    Concretely, it: 0. Raises `"chat already built"` if `@chat` is already memoised — the same guard S11 ships, and the
    direct enforcement of the memoisation hazard described in (1). Only one `decide` call is valid
    per instance; a caller wanting a second decision builds a new instance.
    1. Assigns `@agent_log = agent_log` (and `self.agent_log_id = agent_log.id`) **before** the first
       call to `chat` or `tools` — this matters because `build_chat` (ruby_llm_agent.rb:85-92) is
       memoised behind `@chat ||=` (ruby_llm_agent.rb:13) and `ruby_llm_context` is memoised behind
       `@ruby_llm_context ||=` (ruby_llm_agent.rb:95), and both are built lazily from whatever
       `agent_log` currently resolves to when first touched. If `@agent_log` isn't set first, the
       memoised `@chat` would build tools bound to the wrong (or a freshly-created) log.
    2. Runs `ask!(user_prompt)` against that specific log (same call `perform` makes today,
       ink_clusterer.rb:189, `ask!` defined at ruby_llm_agent.rb:29-54).
    3. Returns `agent_log.reload.extra_data` — RELOAD, as S11 does, so the decision tool's DB write is
       read back rather than a stale in-memory hash (the tool calls `agent_log.update!` on its own
       reference to the record, e.g.
       `{"action" => "assign_to_cluster", "cluster_id" => 123, "explanation_of_decision" => "..."}`,
       see ink_clusterer.rb's `BaseTool#update_extra_data`, lines 5-30).
    4. Does **not** call `already_resolved?`, `recent_activity?`, any `perform_in`/`perform_async`
       enqueue, `waiting_for_approval!`, or any state transition. Rescue nothing: let
       `RubyLlmAgent::DecisionNotReachedError` (raised at ruby_llm_agent.rb:48-51 when `ask!` exhausts
       `MAX_DECISION_RETRIES`) and the bare `RuntimeError` "Max tool calls (50) exceeded"
       (ruby_llm_agent.rb:123, raised inside the `before_tool_call` callback) propagate uncaught, so the
       bench harness (S20) can catch and count them per case instead of them being swallowed here.

  - `perform` becomes a thin wrapper that still does exactly what it does today
    (`already_resolved?` / `recent_activity?` guards, the empty-micro-cluster branch that rejects
    without calling the LLM at all, ink_clusterer.rb:188-204, stays in `perform`, unchanged — this
    branch never reaches `decide` and is not part of this refactor) but, on the LLM-calling path,
    delegates to `decide(agent_log: agent_log)` instead of inlining `ask!(user_prompt)`, then continues
    with `agent_log.waiting_for_approval!` and `schedule_follow_up!` exactly as before. Also unchanged:
    `schedule_follow_up!`'s destroy-and-retry safety-net branch (ink_clusterer.rb:227-231, the
    `else` arm that fires if a Halt occurred without writing `extra_data["action"]`).
  - Fix the memoisation bug at ink_clusterer.rb:174. Today:
    ```ruby
    def agent_log
      @agent_log = AgentLog.find(agent_log_id) if agent_log_id
      @agent_log ||= micro_cluster.agent_logs.ink_clusterer.processing.first
      @agent_log ||= micro_cluster.agent_logs.ink_clusterer.waiting_for_approval.first
      @agent_log ||= micro_cluster.agent_logs.create!(name: self.class.name, transcript: [])
    end
    ```
    Line 174 (`@agent_log = AgentLog.find(agent_log_id) if agent_log_id`) is a **plain `=`, not
    `||=`**: every single call to `agent_log` re-runs `AgentLog.find` and replaces `@agent_log` with a
    fresh instance whenever `agent_log_id` is set. Change it to `@agent_log ||= AgentLog.find(agent_log_id)
if agent_log_id` so one `InkClusterer` instance keeps one memoised `AgentLog` object once
    `agent_log_id` is present. Why this matters for `decide(agent_log:)`: the runner will construct
    `InkClusterer.new(micro_cluster_id, agent_log_id: bench_log.id)` and call `decide` on it; without
    the `||=` fix, later reads of `agent_log` inside the same call (e.g. inside `BaseTool#update_extra_data`,
    which does `agent_log.update!(...)`, or `save_transcript_and_usage`, which does
    `agent_log.usage[...] += ...; save_transcript` and mutates the object in place before saving) could
    read and write to _different_ Ruby objects representing the same DB row, silently losing the usage
    accumulation or the extra_data write depending on call order.
    - **Today in prod this bug is latent, not live**: the only call sites that pass `agent_log_id:`
      are `approve!`/`reject!` (via the admin controller, `app/controllers/admins/agents/ink_clusterer_controller.rb:81`,
      and `check_ink_clustering/base.rb:98,103`), and neither of those calls `perform` — no `perform`
      call site in prod passes `agent_log_id:` (`RunInkClustererAgent.perform_async("InkClusterer",
micro_cluster_id)` is always the positional-id-only form). So today's behaviour is unchanged by
      this fix; it only becomes load-bearing once the bench/shadow code (S20, S25) starts constructing
      `InkClusterer.new(id, agent_log_id: ...)` and calling `decide` on it.
- **Depends on.** Nothing (app-only change; S11's `PenVariantClusterer` already uses this
  `decide(agent_log:)` shape from its first line of code, so this step brings `InkClusterer` in line
  with a pattern the pen agent already established rather than inventing a new one).
- **Why here.** The bench runner (S20), the checker bench (S28), and the shadow-mode subclass
  (S25 wraps `ReviewApprover`'s equivalent `decide`) all need one side-effect-free way to run a
  decision without Sidekiq, state transitions, or enqueues; a small app-only PR guarded by the
  existing 1,653-line ink spec is safer than folding this refactor into the much larger harness PR
  (S20) where a regression would be harder to isolate.
- **Does not include.** Any bench code (S20 adds the runner that calls `decide`), any change to the
  checkers' own `decide` (S28 adds that, on `CheckInkClustering::Base`), a keyword or flag to switch
  `processed_tries_data` (the rejected-try feedback injected into the prompt, ink_clusterer.rb:307-346)
  off — S20 handles hiding that feedback by deleting the rejected logs inside its per-case rolled-back
  transaction, not by adding a parameter here.
- **Definition of done.**
  - The full existing `spec/agents/ink_clusterer_spec.rb` (1,653 lines) stays green with no
    behavioural changes asserted differently — this is the regression guard for the refactor.
  - New spec example(s) for `decide(agent_log:)` directly: build a `MicroCluster` with collected inks
    and a fresh `AgentLog`, stub the chat completion to call one of the decision tools, call
    `InkClusterer.new(micro_cluster.id).decide(agent_log: log)`, and assert:
    - it returns the tool-written `extra_data` hash,
    - `AgentLog.count` and every Sidekiq job queue are unchanged (`not_to change { AgentLog.count }`,
      `not_to have_enqueued_sidekiq_job` or equivalent for `RunInkClustererAgent`),
    - the log's `state` is still whatever it started as (not `waiting-for-approval`),
    - the log's `transcript` and `usage` ARE populated (the concern's own `save_transcript_and_usage`
      still runs as part of `ask!`; only the outer state machine is skipped).
  - A dedicated spec for the `||=` fix: construct `InkClusterer.new(micro_cluster.id, agent_log_id:
log.id)` and assert `expect(clusterer.agent_log).to equal(clusterer.agent_log)` — i.e. object
    identity (`equal?`, not just `==`) across two calls, which fails today with the plain `=` and
    passes once it is `||=`.
- **Decisions applied.** None of Q1-Q39 changes this step's content directly — it is pure
  renumbering; it is listed here because the v2
  ordering (S19, after S18's embeddings config and before S20's harness) is unchanged from v1's
  relative position and no decision moves or alters it.
- **Implementation notes.**
  - `user_prompt` (ink_clusterer.rb:307-311) still appends `processed_tries_data`
    (ink_clusterer.rb:316-346) whenever
    `micro_cluster.agent_logs.ink_clusterer.rejected.where("created_at < ?",
agent_log.created_at).exists?` — for a bench case this means every historical rejected log on that
    micro cluster (including any human `manual_rejection_note` that names the "right" answer) would be
    injected into the prompt unless the caller (S20) deletes those rejected logs inside its rolled-back
    transaction first. This step does not need to do anything about that itself — just be aware
    `decide` inherits this behaviour unchanged from `perform`, and note it so whoever writes S20 does
    not get surprised. `agent_log` in the `processed_tries` query below is `agent_log.created_at`, i.e.
    it filters correctly by the log passed to `decide`, not by "now" — this stays correct because
    `decide(agent_log:)` sets `@agent_log` before the prompt is built.
  - Reference for the shape being followed: `app/agents/pen_variant_clusterer.rb`'s `decide(agent_log:)`
    (introduced in S11) is structured the same way — `perform = guards -> decide -> waiting_for_approval!`
    — so this step is literally making `InkClusterer` match a pattern that already exists in the
    codebase by the time this PR is written; read that file for the exact target shape before writing
    the ink version.
  - Rollback: app-only, no schema, no prod behavioural change for `perform`'s existing call path — a
    `git revert` + merge is sufficient.

### S20-harness-core-ink — Harness skeleton: InkClusterer case exporter (decided label rules), leave-one-out runner, record/replay, report, hand-maintained price table

- **Goal.** Build the generic bench harness in `lib/bench/` (per docs/llm-migration-plan.md:190;
  `lib/` is NOT autoloaded — `config/application.rb` (39 lines) sets no `config.autoload_lib`, and
  `lib/tasks/*.rake` is picked up only because `Rakefile:6` calls `Rails.application.load_tasks` — so
  every `lib/bench/*.rb` file must be
  `require`d explicitly from the rake task, never relied on to autoload; do **not** put this in
  `app/lib/`, which IS autoloaded and eager-loaded in both CI (config/environments/test.rb) and prod,
  and would have to boot without any DO/OpenAI keys present). Entry point: a `bench:*` rake namespace
  in `lib/tasks/bench.rake` that requires the harness files it needs at the top of each task body (not
  at file load time — see S17's `Bench.isolate!` note about why `sidekiq/testing` must be required
  inside the task block, not eagerly).
  - **Every task starts with `Bench.isolate!`** (built in S17-bench-db): fakes Sidekiq
    (`Sidekiq::Testing.fake!`), points `Rails.cache` at the bench Redis DB
    (`BENCH_REDIS_CACHE_URL`, defaulting to `redis://redis:6379/6`), and aborts unless
    `ActiveRecord::Base.connection_db_config.database.end_with?("_bench")` and
    `Rails.env.development?` — this guard is why no rake task in this step can accidentally run
    against dev or prod data. Call `Sidekiq::Worker.clear_all` once per case so fake-mode queues do not
    grow unbounded across a ~200-case run.
  - **Exporter**: `bench:export[InkClusterer]` reads
    `AgentLog.where(name: "InkClusterer", state: %w[approved rejected], agent_approved: false)` with
    `owner_type: "MicroCluster"` and an `EXISTS` check that the owning `MicroCluster` still has
    `collected_inks` (on prod this is 10,047 of 11,759 = 85.4% of all such logs). Apply, in order:
    1. Exclude unconditionally the empty-micro-cluster pseudo-rejection
       (`ink_clusterer.rb:188-204`'s `extra_data["action"] == "reject"` with the fixed explanation
       string "The micro cluster has no inks in it...") — this is not a real decision, just a guard.
    2. Exclude logs with no action at all — CleanUp's 3-hour auto-rejections (`agent_approved =
false`, untagged before S13's `extra_data.auto_rejection = "orphaned"` tag exists; on older
       data these are just logs with a blank `extra_data["action"]`).
    3. **(Q10.ii)** Exclude approved hand-over cases (`extra_data["action"] ==
"hand_over_to_human"` and the log is `approved`), and exclude any OTHER approved log whose
       owning `MicroCluster` is, as of export time, neither assigned (`macro_cluster_id IS NOT NULL`)
       nor `ignored`. State the rule that generally, not only for assign/create: it covers
       assign/create logs a human later undid AND `ignore_ink` logs a human later un-ignored, both of
       which would otherwise fall through step 5 with no label at all. All of them reflect "this label
       no longer describes today's ground truth."
    4. **(Q10.i)** Dedupe to one case per micro cluster: the LATEST human-labelled run (i.e. per
       `micro_cluster_id`, keep only the log with the greatest `created_at` among the ones that
       survive steps 1-3).
    5. Label each surviving log from **today's actual state**, not from `extra_data["action"]` alone:
       - `assign` if the micro cluster is currently assigned (`macro_cluster_id.present?`) —
         **(Q10.iii)** this includes originally-`create_new_cluster` logs whose created macro cluster
         was later merged into another one (`InkBrandClusterer`'s `add_to_brand_cluster` / a human
         merge); those count as `assign` to the merged cluster, not as `create`, because the eventual
         ground truth is "this ink belongs with that cluster."
       - `create` if the micro cluster's CURRENT macro cluster has no other micro clusters
         (`macro_cluster.micro_clusters.count == 1`), i.e. the cluster this create produced was never
         merged into. Use that current-state test, not the log: `CreateNewCluster#execute`
         (ink_clusterer.rb:55-70) writes only `action`/`explanation_of_decision` via
         `update_extra_data` (:23-25), and `approve!` creates the macro cluster and assigns it
         (:257-260) without recording its id anywhere, so "the cluster this log produced" is not
         identifiable from the data. Every other originally-create log is labelled `assign` to
         `micro_cluster.macro_cluster_id` (Q10.iii).
       - `ignore` if the micro cluster is currently `ignored: true`.
       - a `rejected` log (state `rejected`, `agent_approved: false`, meaning a human explicitly said
         "no" to a real decision) becomes a case in the hard-negative subset ONLY if its owning micro
         cluster is, today, assigned or ignored (`micro_clusters.macro_cluster_id IS NOT NULL OR
ignored`) — on prod, 1,642 of 1,787 such logs qualify; the other 145 are unresolved (never
         re-decided) and must be reported separately, never scored as if they had a known right answer.
    6. **(Q10.iv)** Feedback hiding: by default, hide `processed_tries_data` (the "this ink was
       processed before and rejected because..." block ink_clusterer.rb:316-346 injects into the
       prompt via `user_prompt` at :307-311 — `processed_tries?` :332-334, `processed_tries`
       :336-338, `processed_tries_data` :340-346) by deleting every rejected `InkClusterer` log on
       that micro cluster older than the
       case's own log, **inside the rolled-back per-case transaction** the runner opens (see below) —
       not permanently. Add a `--with-feedback` mode/flag that skips this deletion, for a mode that
       measures how much the historical-rejection context helps.
    7. Stratify the exported case set by (action, verdict) — `assign`/`create`/`ignore` crossed with
       "approved"/"in the hard-negative subset" — and split into dev/test partitions (an 80/20 or
       similar split is fine; pick one and document it in the exporter's own comment, since this file
       does not mandate an exact ratio). Write cases to gitignored JSON under `bench/data/` (already
       gitignored per the migration plan, docs/llm-migration-plan.md:188; also already added to
       `.dockerignore` and `.prettierignore` by S17).
    8. **Record shapes — fixed here, because S21 and S28 both read them.** The assign target field is
       named GENERICALLY, not `cluster_id`: S21's pen cases assign to a `Pens::ModelVariant`, not to a
       cluster, and the migration plan requires one shared harness and one report over both agents. A
       CASE is
       `{agent: "InkClusterer", owner_type: "MicroCluster", owner_id:, source_agent_log_id:,
original_action:, expected_action: "assign"|"create"|"ignore", expected_target_id: (nil
unless assign; a `MacroCluster`id for inks, a`Pens::ModelVariant` id for pens), subset:
"approved"|"hard_negative", stratum:, partition: "dev"|"test"}`, one
       JSON array per agent at `bench/data/cases/<agent>.json`. A RUN writes one JSON file per
       `(agent, model, timestamp)` at `bench/data/runs/<agent>-<model>-<ts>.json`, each record
       `{owner_id:, expected_action:, expected_target_id:, actual_action:, actual_target_id:,
tool_calls: [...], prompt_tokens:, completion_tokens:, cost:, latency_ms:, error: nil |
"DecisionNotReachedError" | "MaxToolCalls"}`. `bench:report` globs `bench/data/runs/`.
  - **Runner**: `bench:run[InkClusterer,<model>]`. For each exported case, inside one
    `ActiveRecord::Base.transaction` that is **rolled back** at the end (never committed):
    1. Set the case's `MicroCluster.macro_cluster_id = nil` and `ignored = false` (undoing whatever the
       ground-truth label implies, so the agent sees the same "undecided" state a real run would).
    2. Hide the lonely macro cluster's own `ink_embeddings` row — for a `create`-labelled case, the
       macro cluster the log created would otherwise still be findable via
       `MacroCluster.embedding_search`'s first tier (which searches `InkEmbedding.where(owner_type:
"MacroCluster")` at app/models/macro_cluster.rb:119-126, inside `embedding_search` which starts
       at :105) even after step 1 nulls the micro cluster's
       assignment — either delete that macro cluster's `InkEmbedding` row or NULL its `embedding`
       column (`neighbor`'s `nearest_neighbors` adds `.where.not(embedding: nil)` automatically, so
       NULLing is sufficient and non-destructive within the transaction).
    3. Unless `--with-feedback` is on, `destroy_all` (not `delete_all` — `AgentLog has_many
:agent_logs, dependent: :destroy`, so a bare `delete_all` would orphan any nested sub-agent
       logs) every `micro_cluster.agent_logs.ink_clusterer.rejected` log created before the case's own
       log — this is the Q10.iv feedback-hiding step, executed here (inside the transaction) rather
       than in the exporter, so it is naturally undone by the rollback.
    4. Call `InkClusterer.new(micro_cluster.id, agent_log_id: fresh_bench_log.id).decide(agent_log:
fresh_bench_log)` — the `decide(agent_log:)` entry point S19 built, with a **freshly created**
       `AgentLog` for this bench run (not the historical one) — with provider/model injected through
       S04's `LlmConfig.with_override("InkClusterer" => { model:, provider:, api_base:, api_key_env: })`
       block. The ink baseline round (this step's own smoke test, and later S22's round 0) needs no
       override at all: the config default for `InkClusterer` is still OpenAI (`OPEN_AI_TOKEN`), so
       running the harness with zero override IS the OpenAI baseline. A later candidate-model round
       (S30) passes the override.
    5. Capture: the decided action, the target cluster id (if any), every tool call made (from the
       transcript), token counts, a computed cost (see pricing below), wall-clock latency, and whether
       a `RubyLlmAgent::DecisionNotReachedError` or the "Max tool calls (50) exceeded" `RuntimeError`
       was raised instead of a decision (S19 made `decide` propagate both uncaught specifically so this
       step can catch and count them per-case rather than have them silently retried).
    6. Roll back the transaction (raise `ActiveRecord::Rollback` or open the block with
       `transaction { ...; raise ActiveRecord::Rollback }`) so nothing written by step 1-4 (including
       the fresh bench `AgentLog` itself, since it belongs to a real `MicroCluster` and would otherwise
       pollute prod-shaped data even in the bench DB) survives.
  - **Record/replay cache** for two things the runner should not re-hit on every re-run of the same
    case set. Mechanism, so this is not left to invention: put `Bench::Replay.fetch(key) { ... }` in
    `lib/bench/replay.rb`, backed by JSON files under `bench/data/replay/`, and install it from the
    rake task by prepending a module to the two call sites below. Do NOT use `Rails.cache` —
    `Bench.isolate!` points it at the bench Redis, which is wiped between rounds. The two sites:
    - Serper search results: `GoogleSearchSummarizer`'s underlying HTTP call
      (`app/lib/google_search.rb:7,31-35`, `Faraday.new("https://google.serper.dev/").post("search")`
      with body `{q: query}` and header `X-API-KEY`) — prepend to `GoogleSearch#perform` and key the
      replay cache on the **exact** query string passed in, which already includes the suffix
      `Tools::InkWebSearchTool` appends (`" ink"`, `ink_web_search_tool.rb:16`; the pen equivalent
      appends `" fountain pen"`). The runner has no handle on the object itself — `GoogleSearch` is
      constructed inside `GoogleSearchSummarizer`, which is constructed inside
      `Tools::InkWebSearchTool#execute` (ink_web_search_tool.rb:15-18) — and a rake task has no
      WebMock, which is why the prepend is the mechanism.
    - The `GoogleSearchSummarizer`'s own LLM-generated summary of those search results — prepend to
      `GoogleSearchSummarizer#perform`, key on `(query, effective summarizer model)` so a cached summary is invalidated correctly if a later bench round
      changes which model `GoogleSearchSummarizer` runs on under Q14's "sub-agents run on the same
      candidate as the agent under test" rule.
  - **Report**: `bench:report` reads the recorded run(s) and prints, per agent x model: an
    approved/rejected split, every metric ALSO broken out (a) by expected action
    (assign/create/ignore) and (b) by the hard-negative subset, with a Wilson confidence interval per
    cell (cell sizes around n~200 are what S21's drip comparison and S30's acceptance bar both use, so
    build the interval calculation as a small reusable method now).
  - **Pricing**: a hand-maintained price table, e.g. `lib/bench/pricing.rb`, a `Hash` keyed by the
    exact response `model` string (the string the provider actually returns, e.g.
    `"gpt-4.1-2025-04-14"` for OpenAI, or whatever DO's `data["model"]` echoes back — RubyLLM
    1.16.0's bundled `models.json` has no DigitalOcean entries at all, so this cannot be looked up from
    the gem) mapping to `{input_price_per_1k:, output_price_per_1k:}` (or per-token, pick one unit and
    be consistent), filled in from the price/model table S01's spike recorded in its catalog. Unknown
    model string → cost omitted for that row, tokens still shown, no exception raised. There is NO
    change to `agent_logs.usage` and NO admin cost graph (Q5 dropped that step entirely) — this pricing
    table lives only in `lib/bench/` and is consumed only by `bench:report`.
  - Print the effective per-agent config (provider, model, api_base) at the start of every `bench:run`
    so a baseline accidentally run against a DO override (or a candidate model accidentally left
    active from a previous shell) is visible in the recorded output, not just inferred after the fact.
  - Everything under `lib/bench/` needs specs so the Codecov project-coverage threshold (0.2%,
    `codecov.yml:10-12`, tracked by SimpleCov's `rails` profile over `{app,lib}/**/*.rb`) stays green,
    and needs to pass `prettier --check .` (Prettier covers `.rb`/`.rake` via the Prettier Ruby plugin;
    `.prettierignore` already excludes `.yarn`, `coverage`, `builds`, `node_modules`, `public`,
    `spec/fixtures`, `tmp`, `vendor` — bench code is not in that exclusion list, so it must be
    formatted, not ignored).
- **Depends on.** S17 (bench DB + `Bench.isolate!` must exist), S04 (chat config + `LlmConfig.with_override`
  injection point), S18 (embeddings key path — until S18 landed, `MacroCluster.embedding_search` still
  went through an `EmbeddingsClient` that branches on `Rails.env.development?`; this harness's
  `ink_similarity_search` tool calls depend on that client being fully config-driven), S19 (the
  `decide(agent_log:)` entry point this runner calls).
- **Why here.** The generic runner is built once, against the real injection point (S04), and reused
  by the pen L1 cases (S21), the checker + ReviewApprover bench (S28), and every later bench round
  (S22, S23, S30). Ink is the first agent benched because its labels are the richest (11,759+ historical
  decisions vs. the pen agent's much younger queue) and its leave-one-out design (hiding the macro
  cluster's own embedding, hiding sibling logs) validates the whole approach before the pen exporter
  (S21) has to reproduce the same shape with an oversampling twist (Q12).
- **Does not include.** The pen case exporter and its hide step (S21 adds these, reusing this step's
  runner/report/pricing code unchanged), the checker and `ReviewApprover` case exporters and export
  mode for unlabelled agents (S28), any actual model change or cutover (this step only runs baselines
  for comparison — S22 is the first round that's meant to be read as a result).
- **Definition of done.**
  - `bench:export[InkClusterer]`, `bench:run[InkClusterer,<model>]`, `bench:report` all work against
    the bench DB, with fake Sidekiq and the bench Redis DB active throughout (verified by
    `Bench.isolate!`'s own guard, which aborts the task otherwise).
  - Every `bench:run` invocation prints the effective config (provider, model, api_base, and the
    embeddings model in use) at start, so a baseline accidentally run on a DO override is visible in
    the saved report output, not just inferred later.
  - A 20-case smoke run on `gpt-4.1` (the current OpenAI default, i.e. no `LlmConfig.with_override`
    needed) is recorded and attached to the PR; this run must exercise the injection point end-to-end
    (chat through S04's config resolution, embeddings through S18's config-driven client with no
    `Rails.env` branch left) even though it doesn't change the model.
  - Can be split into two PRs if that is easier to review: (a) exporter + label rules + specs, (b)
    runner + record/replay + report. Either way both land before S21 starts.
  - Bench code specs pass and Codecov project status stays green; `prettier --check .` passes over
    the new `lib/bench/*.rb` and `lib/tasks/bench.rake` files.
- **Decisions applied.** Q10 (ink bench label rules: one case per micro cluster from the latest
  human-labelled run; exclude approved hand-over and approved-but-unassigned-today cases; approved
  creates later merged count as assign to the merged cluster; rejected-try feedback hidden by default
  with an opt-in `--with-feedback` mode). Q2 (the runner injects provider/model through S04's scoped
  `LlmConfig.with_override`, active only for the duration of one `decide` call, thread-safe for
  concurrent bench/Sidekiq work — though the bench harness itself runs single-threaded per rake
  invocation). Q5 (cost is bench-only, from a hand-maintained price table keyed by the response model
  string; there is no in-app usage-field change and no admin cost graph — the dropped step this
  otherwise would have depended on, v1's S17/usage-cost-fields, does not exist in v2).
- **Implementation notes.**
  - Hide-step mechanics: neither `MicroCluster` nor `Pens::MicroCluster` has any `before_save`/
    `after_save` callback that would fight the case setup; `InkEmbedding`/`PenEmbedding` do have
    `after_save` callbacks that enqueue `FetchEmbedding` on content change, but Sidekiq is faked
    (`Bench.isolate!`) so those enqueues are inert — use `update_columns`/`.delete` directly on the
    case rows rather than `update!`, to avoid triggering validation/callback paths that assume a real
    content change.
  - `MacroCluster.embedding_search` issues `SET hnsw.ef_search = 200` (session-level, not
    `LOCAL` — i.e. it persists on the connection until changed again) and the pen search issues `1000`;
    within one connection the later `SET` wins. Irrelevant for correctness here (each search call sets
    what it needs right before querying) but worth recording in the report/PR when comparing latencies
    against S02's pen retrieval numbers, since a shared connection pool could otherwise make a latency
    comparison misleading.
  - `.reject { |e| e.neighbor_distance > MacroCluster::SIMILARITY_CUTOFF }` (app/models/macro_cluster.rb:126,
    136, 147 — the literal `0.6` became the S09 constant, so the literal is gone by the time this step
    is implemented) runs AFTER the gem's own `nearest_neighbors` cap — i.e. the cutoff is applied in
    Ruby, not in SQL, so a
    bench-DB row count comparison against prod needs to account for this two-stage filter.
  - Specs for the exporter/label-rules/hide-step/feedback-hiding logic should be bench-DB-free: they
    are unit-testable against the normal test DB with FactoryBot factories under `spec/lib/bench/`,
    following the real-pgvector spec pattern S09 introduced (a spec that exercises actual `nearest_neighbors`
    queries against a real, if small, set of factory-created embeddings rather than mocking pgvector
    out) as the model to copy for anything that needs the embedding hide step to actually behave like
    pgvector.
  - Rollback if something goes wrong post-merge: this step touches no prod schema and no prod runtime
    path (it is bench-DB-only, gated by `Bench.isolate!`'s guard) — a `git revert` + merge is
    sufficient; there is no data to unwind in prod.

### S21-harness-pen-cases — Pen L1 case exporter (over-sampled singletons, re-derivation inside the transaction), hide step, hard-negative label rule

- **Goal.** Exporter over the ~15.3k human-assigned `Pens::MicroCluster` rows that still have pens
  (15,744 assigned, 453 empty) and the 355 ignored ones with pens (361 in total, 5 of them empty).
  **Implementer default:** the one row that is both ignored and assigned is excluded outright — it is
  a single row and counts in neither cell.
  Two different scopes, deliberately: CASE SELECTION goes through `Pens::MicroCluster.with_collected_pens`
  (S06), so only clusters that still have pens become cases. The SIBLING COUNT that decides the label
  does NOT apply that scope: label = `assign` if another `pens_micro_clusters` row shares
  `pens_model_variant_id`, counted unscoped — `Pens::MicroCluster.where(pens_model_variant_id: v.id).count > 1`
  — because Q8 keeps the 453 empty assigned pen micro clusters in the database as human spelling
  rules, and they still count as siblings. That is why the 433 assign cases whose only siblings are
  empty stay `assign` (the variant's own embedding remains); else `create`. Add an exporter spec: a
  variant with exactly one EMPTY assigned sibling labels `assign`.
  Ignore labels that violate the decided ignore policy are EXCLUDED from the bench (Q13). The rule is
  the WHOLE policy, not one family: exclude every ignored micro cluster the decided ignore policy
  (pen decision 3) would NOT ignore. Two groups qualify today:
  (a) calligraphy-set family pens — 4 of the 361 ignored rows match parallel/calligraphy on prod; the
  known ones are the two `pilot / parallel` colours (`blanco`, `white`) and the
  `?/calligraphyparallelset` row (decision 3: "calligraphy pens such as Pilot Parallel (they are
  fountain pens)");
  (b) rows that are a real, identifiable branded fountain pen carrying only a malformed or
  placeholder COLOUR — decision 3's "Opus 88 clear color" case, which it says "should be assigned
  instead", so an ignore label there contradicts the policy.
  Write the rule, not the ids, and let the exporter spec assert both cases (an ignored cluster whose
  pens are a Pilot Parallel is not exported; an ignored real-brand/real-model cluster whose only
  defect is a placeholder colour is not exported; an ignored `waterman/?/black` cluster is). The
  ~252 `?`/unknown brand-or-model placeholder rows, nib units, clones, non-fountain-pen products,
  kit pens and unknown-model vintage all conform to the policy and stay.

  Hide step, stated once for all three labels, mirroring S20's runner step 1: inside the rolled-back
  per-case transaction set `pens_model_variant_id = nil` **and** `ignored = false` on the case's
  `Pens::MicroCluster` (use `update_columns`, as S20 prescribes, to skip callbacks) — the `ignored`
  half matters for the ~355 ignore cases, which would otherwise reach `decide` with the ground-truth
  label still visible in the record the agent and its tools read, a state a real queue run never
  presents. Add a spec asserting an ignore case reaches `decide` with `ignored == false` and
  `pens_model_variant_id == nil`.
  Additionally for create cases: NULL `pens_model_variant_id`, then `variant.destroy` the held-out
  variant INSIDE the rolled-back transaction (micro clusters are already nulled; `dependent:
:destroy` on `Pens::ModelVariant has_one :pen_embedding` (model_variant.rb:2-7) removes its
  `pen_embedding` row too) — this is the chosen mechanism (Q12), not a tool-side skip: without
  destroying the row, `Pens::ModelVariant has_many :micro_clusters, dependent: :nullify`
  (model_variant.rb:2-5) would leave the variant alive under its model with zero micro clusters and
  its old derived name, and `Tools::PenSimilaritySearchTool` (S10; it loads `model.model_variants`
  itself, not through the micro-cluster join) would still list it by id and name. Add a spec that
  asserts the held-out variant id never appears in `Tools::PenSimilaritySearchTool`'s output for a
  create case. Tier-3 search (pens/model.rb:53-71, the `collected_pens_embeddings` block, verified
  2026-09-14) and
  `Pens::ModelVariant.search` (model_variant.rb:19-27) join through micro clusters, so the held-out
  pens disappear from those paths on their own.

  OVER-SAMPLE the singleton cells (Q12) — assign/singleton 787 and create/singleton 205 are the cells
  that get the oversampling weight. The reason is population shape, not cost: the labelled set is 99%
  multi-pen clusters (labelled assigned clusters average 6.46 pens) while the production backlog is
  96% singletons (1.05 pens), so a proportional sample would leave the singleton cells nearly empty
  and the bench would not measure the work the agent actually faces. **Implementer default** for the
  200-case budget: assign/multi 60, assign/singleton 50, create/multi 40, create/singleton 40,
  ignore 10; report each cell with its own Wilson interval, and note that the raw cell counts (787 and 205) cap how far over-sampling can go. Re-derivation is a separate matter and runs for EVERY assign
  case, not only singleton ones — "singleton" here refers to pens per micro cluster, not to how many
  micro clusters the variant keeps. Q12 asks for the held-out variant's **and single-variant model's**
  name and embedding, so an assign case re-derives BOTH where both are affected. Re-derive the
  held-out variant's name and embedding from the remaining pens inside the same rolled-back
  transaction: call
  `Pens::UpdateModelVariant.new.perform(variant.id)` (a Sidekiq::Worker, called directly as a plain
  object — it returns early when `collected_pens` is empty, update_model_variant.rb:6-7, and
  `update_embedding!` (:37-40) only sets `pen_embedding.content`, it does not call the API) then the
  harness must itself call `FetchEmbedding.new.perform("PenEmbedding", variant.pen_embedding.id)`
  (fetch_embedding.rb:8-13) — one real embeddings API call per case, cached through S18's
  model-aware cache key — so the query the agent issues during `decide` hits the re-derived vector,
  not the stale one. `Pens::UpdateModelVariant#perform` also calls
  `Pens::AssignModelMicroCluster.perform_async(model_variant_id)` (update_model_variant.rb:10); this
  is fine to leave enqueued into the fake Sidekiq queue used by every bench task (S17's
  `Bench.isolate!`) since the whole case rolls back.
  Then, still on the assign branch and still inside the same savepoint: if the variant's model has NO
  other variants (a single-variant model, Q12's "(and single-variant model's)" half), also run
  `Pens::UpdateModel.new.perform(model.id)` followed by
  `FetchEmbedding.new.perform("PenEmbedding", model.pen_embedding.id)`. Without it, tier 1 of
  `Pens::Model.embedding_search` (pens/model.rb:36-42) searches
  `PenEmbedding.where(owner_type: "Pens::Model")` with NO join to micro clusters and would serve a
  model name and vector still derived from the held-out pens — the leak Q12 exists to close. Budget:
  up to TWO embedding calls for such a case, one otherwise. Extend the "held-out variant never
  appears in `Tools::PenSimilaritySearchTool` output" spec to also assert that, for a single-variant
  model, the model's `pen_embedding.content` and vector no longer reflect the held-out pens.
  Gotcha: `Pens::UpdateModelVariant#update_attributes!` ends in a bare `model_variant.save` with NO
  unique-violation retry (update_model_variant.rb:18-23; only `Pens::UpdateModel` has one, at
  update_model.rb:24-29), and the six-tuple is a unique index (db/structure.sql:1715). Removing one
  micro cluster's pens can shift the most-common values onto an existing variant's tuple, and in
  Postgres the resulting `ActiveRecord::RecordNotUnique` aborts the enclosing per-case transaction.
  So wrap the re-derivation in a savepoint —
  `ActiveRecord::Base.transaction(requires_new: true) { Pens::UpdateModelVariant.new.perform(variant.id) }` —
  rescue `ActiveRecord::RecordNotUnique`, skip the case, and count it in the report as a
  re-derivation-collision stratum.

  For create cases the held-out variant is destroyed, so the model needs handling too — split by
  whether any pens remain under it. `Pens::Model` reaches pens only through its variants
  (model.rb:4-10), so after the destroy:
  (a) the model still has OTHER variants, i.e. `model.collected_pens` is non-empty — re-derive it:
  `Pens::UpdateModel.new.perform(model.id)` (update_model.rb:5-12, same shape as the variant worker)
  then `FetchEmbedding.new.perform("PenEmbedding", model.pen_embedding.id)`, so the model's name and
  embedding no longer reflect the destroyed variant's pens;
  (b) the held-out variant was the model's ONLY variant — `model.collected_pens` is now empty, so
  `Pens::UpdateModel#perform` returns at update_model.rb:7 without touching anything and the
  following `FetchEmbedding` would re-embed unchanged stale content and burn a call for nothing.
  Destroy the model instead, inside the same rolled-back transaction: `Pens::Model has_one
:pen_embedding, dependent: :destroy` (model.rb:11) removes its vector and `has_many
:model_micro_clusters, dependent: :nullify` (model.rb:4-7) leaves nothing behind. This matters
  because tier 1 of `Pens::Model.embedding_search` (pens/model.rb:36-42) searches
  `PenEmbedding.where(owner_type: "Pens::Model")` with no join to variants, so a surviving stale model
  vector would still be retrievable by `Tools::PenSimilaritySearchTool`. Extend the tool-output spec
  to assert the held-out MODEL id also never appears for such a case.

  Stratify over the cells assign/multi 10,038-10,039, assign/singleton 787 (oversampled), create/multi
  4,260, create/singleton 205 (oversampled), ignore 355 minus the Q13-excluded rows, plus
  known/unknown brand (S10's `KnownBrand` EXISTS-query definition from Q18, not
  `Pens::Brand.simplified_names`) and big/rare model, plus the CAPPED stratum (Q17): an assign case
  joins it when its expected variant is NOT among the top
  `Tools::PenSimilaritySearchTool::VARIANTS_PER_MODEL` variants of its model ranked by micro-cluster
  count descending (S10) — i.e. the model has more than `VARIANTS_PER_MODEL` variants and the expected
  one ranks below the cut, so the tool shows it only inside the "and N more" line. Create cases have
  no expected variant and are never in this stratum. Exporter spec: a model with
  `VARIANTS_PER_MODEL + 1` variants whose expected variant has the fewest micro clusters is flagged
  capped; the same case with the expected variant ranked first is not. Plus the
  cases whose tuple list exceeds `PenVariantClusterer::PROMPT_TUPLE_CAP = 40` (S11; 67-69
  assigned clusters exceed 40 tuples, max 251-253, the largest holds 832 pens) — **Implementer
  default:** report these capped cases as their own stratum rather than excluding them (simpler,
  keeps every label in the split; neither Q12 nor Q17 addresses this edge case directly, and nothing
  about the tuple cap concerns hide/leakage).

  Feedback hiding as in S20 (S11's prompt includes `processed_tries_data` from earlier rejected
  logs, so a fresh bench log must not see them unless `--with-feedback` is on). Runner hide step for
  the owning `Pens::MicroCluster` then calls `PenVariantClusterer#decide(agent_log:)`.

  Hard-negative label rule for the drip's rejected logs: a rejected `PenVariantClusterer` log is a
  case only if the same owner has a later approved `PenVariantClusterer` log or is
  assigned/ignored today (positive label = today's state); otherwise it is scored negative-only
  ("did not repeat the rejected action/variant", optionally "matches `manual_rejection_note`");
  unresolved owners are excluded from the accuracy figure and reported separately. Nobody assigns at
  L1 by hand (prod query, 2026-09-14), so most drip rejections will be negative-only. This step
  delivers the exporter code path; the populated hard-negative subset first appears after S22's
  refresh (prod has 0 `PenVariantClusterer` logs today — the drip starts in S15). Rejected-log LABELS
  can be read directly from `PRODUCTION_READONLY_DATABASE_URL` without a bench refresh, with the
  constraint S17 states: a case is only RUNNABLE against owners that exist in the bench copy, so a
  rejection on a cluster created after the last refresh is reportable but not runnable until the next
  major-round refresh (Q6: minor rounds re-export from the existing copy).

- **Depends on.** S20 (the runner/report harness this reuses), S11 (`PenVariantClusterer#decide`,
  `PROMPT_TUPLE_CAP`).
- **Why here.** Needed by the very next step, S22 (round 0); built before the checker/ReviewApprover
  parts (S28) and the L2 case exporter (S29) so pens are benched as early as inks.
- **Does not include.** L2 cases (S29), prompt changes, a bench DB refresh (S22 does the one
  refresh that picks this exporter's cases up).
- **Definition of done.** Exporter specs for the label rules, the hide step (incl. the "held-out
  variant never appears in `PenSimilaritySearchTool` output" assertion) and the hard-negative rule,
  in `spec/lib/bench/pen_cases_spec.rb` (bench-DB-free, real factories, the pattern S09's
  real-pgvector spec and S20's ink exporter spec both use — no bench DB needed for the label-rule
  and hide-step unit tests); the exporter code itself lives at `lib/bench/pen_cases.rb`, required
  explicitly from `lib/tasks/bench.rake` (mirrors S20's ink exporter under `lib/bench/`). The
  exporter registers under the same task shape S20 defined: `bench:export[PenVariantClusterer]` and
  `bench:run[PenVariantClusterer,<model>]`, dispatching on the agent name to `Bench::PenCases`;
  `bench:report` needs no change. A stratified 200-case dev/test split written to `bench/data`
  (gitignored) and its cell counts recorded in the pen plan.
- **Implementation notes.**
  - Label derivation: `pens_cell = count(collected_pens) > 1 ? :multi : :singleton`; expected action
    = `Pens::MicroCluster.where(pens_model_variant_id: v.id).count > 1 ? :assign : :create`
    (unscoped — see the sibling rule in the Goal); ignore cases need `ignored = true` with pens (355
    on prod, 2026-09-12), minus the Q13-excluded rows.
  - Scopes: case selection uses `Pens::MicroCluster.with_collected_pens` (S06); the hard-negative log
    query uses `AgentLog.pen_variant_clusterer.owner_with_collected_pens` (S06). Do NOT use
    `owner_with_model_variants` — that scope is restricted to `owner_type = "Pens::ModelMicroCluster"`,
    i.e. the L2 population, which this step explicitly excludes.
  - When S23's embeddings bench reuses these cases, its hide operates on `bench_embeddings`, not on
    `pen_embeddings`; S23 spells that out.
  - Anchor corrections carried from the ink side: `Pens::ModelVariant.search` is
    model_variant.rb:18-28 (the same anchor S10 uses); `has_one :pen_embedding, dependent: :destroy,
as: :owner` is model_variant.rb:7 (`:2-7` is the whole association block).
  - Why the harness calls `FetchEmbedding` itself: `update_embedding!` (update_model_variant.rb:37-40)
    only writes `pen_embedding.content`; the vector is fetched by `PenEmbedding`'s `after_save` hook
    (pen_embedding.rb:12-20) via `FetchEmbedding.perform_async`, which the bench's fake Sidekiq
    (`Bench.isolate!`, S17) swallows.
- **Decisions applied.** Q8, Q12, Q13, Q17.

### S22-bench-round-0 — Round 0: gpt-4.1 for InkClusterer, the S01 DO model for pen L1, on current embeddings; compare with the drip

- **Goal.** Refresh the bench DB overnight — this is bench refresh #1 (Q6), the single refresh
  before this round that picks up the two weeks of drip logs S15 has been producing — then run
  InkClusterer (~200 cases) on gpt-4.1 through the OpenAI key, and `PenVariantClusterer` L1 (~200
  stratified cases from S21) on the S01-picked starting DO model — the SAME model the drip (S15) is
  running in prod — both against the current (pre-swap) embeddings. Running pen L1 on the identical
  model the drip runs means bench and drip differ only by population and label rules, never by the
  model: any disagreement can only be a bench artifact or a genuine population difference, not "the
  bench used a different model than prod." Round 0 runs on dev + test splits (fine before any
  tuning; S33's test split stays untouched by tuning).

  Compare the pen bench's approval-equivalent rate per action and per stratum with the drip's
  per-action approval rates from S14's presenter (two weeks at depth 10 yield roughly 100-300
  decisions; state the drip's n and a Wilson interval next to the bench cell before calling
  agreement or disagreement). The bench's multi-pen cells are the drip's counterpart (the drip, by
  S13's pen-count-desc top-up ordering, contains only multi-pen clusters in its first weeks); the
  singleton cells have no drip counterpart to compare against. Rule out population and label
  differences first (bench = matches today's human-assigned state; drip = human approved a specific
  agent decision) before changing the harness or the agent; if bench and drip still disagree badly
  on the multi-pen stratum after that check, fix the bench (or the agent) before anything else is
  measured on it.

  Re-run the S02 retrieval check on the cleaned bench DB through the real
  `Tools::PenSimilaritySearchTool` (top-20 as the agent actually sees it, not a raw
  `embedding_search` call). Read failure transcripts and list concrete failure modes for S33's
  directive tuning.

  Cost: 200 InkClusterer cases x ~$0.012 on gpt-4.1 (OpenAI key); pen L1 cost comes from the
  hand-maintained price table (S20, Q5) keyed on the S01-picked DO model's response `model` string —
  materially cheaper than gpt-4.1's measured $0.012/run (S15's day-one note estimated roughly a fifth
  of that for a Haiku-class candidate; use the exact per-token price from S01's catalog, not this
  estimate); plus GoogleSearchSummarizer
  runs on ~~30-40% of cases and first-run Serper queries (~~$1/1000). Total stays well under $10 only
  if record/replay is on from the first run (a second run to debug the harness would exceed it).

- **Depends on.** S21 (pen cases), S15 (about two weeks of drip data — the drip must have been
  running long enough for S14's presenter to have a meaningful n per action).
- **Why here.** First quantitative feedback and the moment the drip's labels become useful. This
  baseline is deliberately taken before the embedding swap, and deliberately re-run after it (S30):
  a few dollars buy a harness validated while bench and prod still measure the same thing, before
  the retrieval layer underneath either agent changes.
- **Does not include.** Candidate models, prompt changes.
- **Definition of done.** Numbers, round date and failure-mode list recorded in both plan docs;
  bench-vs-drip agreement stated per action and per stratum with both n's and Wilson intervals; the
  bench refresh #1 (Q6) timestamp recorded so S30's refresh #2 is clearly the next one, not this one.
- **Decisions applied.** Q32, Q5, Q6.

### S23-embeddings-bench — `bench_embeddings`, four DO candidates, recall@k and cutoff sweep for inks and pens; pick

- **Goal.** Harness task that creates `bench_embeddings(model, owner_type, owner_id, embedding
vector(1024))` in the bench database only (harness-executed DDL, not a Rails migration: the plan
  calls it a bench table, and a migration would ship an unused table to prod against the "bench data
  is gitignored" decision). Baseline vectors are **read from the existing `embedding` column** of
  `ink_embeddings`/`pen_embeddings` in the bench DB (1536 dims cannot be inserted into
  `vector(1024)`, and re-embedding them would be a 1M-call OpenAI run for vectors already there);
  only the four DO candidates (all 1024 dims per S01) are embedded into `bench_embeddings`, via the
  no-cache bulk path of `fetch_many` on an explicit-entry `EmbeddingsClient` (S18) with the DO dev
  key, throttled to the limits found in S01 (~8-10M tokens: sum of content lengths is 23.29M + 8.70M
  chars over 797,700 + 210,534 rows; under $1 per model; minutes to hours). Vectors are written
  straight to `bench_embeddings`; per-text caching is only for the ~200 leave-one-out query strings.
  Disk: 4 candidates x 1.0M rows x 1024 floats = 16-18 GB on top of the 14 GB bench DB and 12 GB dev
  DB (79 GB free).

  Retrieval logic: a bench-only copy of both tiered searches parametrised by table and column
  (mirroring S09's `SIMILARITY_CUTOFF`/`HNSW_EF_SEARCH` constants and joins; a spec compares it with
  the real `embedding_search` on the baseline column), because the real methods are hard-wired to
  `InkEmbedding`/`PenEmbedding` and `nearest_neighbors(:embedding, ...)`. Ink retrieval:
  leave-one-out, query = micro cluster names, expected = macro cluster, recall@1/5/20 through the
  three-tier logic. Pen retrieval: the S02/S22 cases (S02's retrieval-check methodology, re-run
  against the cleaned bench DB in S22). The hide step operates on the bench table/column being
  measured, and `bench_embeddings` is a flat table with no `content` column and no `FetchEmbedding`
  path, so S21's mechanics do not carry over unchanged — spell it out per case, inside the rolled-back
  transaction: (1) DELETE from `bench_embeddings` the row whose `(model, owner_type, owner_id)`
  matches the held-out variant (and, for a single-variant model, its `Pens::Model` row) for the
  candidate under measurement; (2) when the BASELINE column is the one being measured, NULL the
  matching `pen_embeddings.embedding` instead; (3) embed the re-derived variant (and model) name with
  the candidate model — `fetch_many(..., cache: false)` on an explicit-entry client (S18) — and INSERT
  it back as that owner's row before querying (≤ 200 x 4 uncached calls). Both tables live in the
  bench DB, so the per-case rollback undoes all of it. This is the same re-derivation S21 built for
  the chat bench, run here once per candidate embedding model instead of once per chat model (Q12).

  Report brute-force (exact kNN) and prod-path (exact kNN with the tiered LIMITs 200/200/2000 and
  the post-filter; `hnsw.ef_search` only affects HNSW index scans and the bench table has no index,
  so the ANN effect is not measured here and is checked by S26's EXPLAIN and S27's watch week.
  **Implementer default:** build NO HNSW index on `bench_embeddings` — exact kNN is what this step
  measures, and the index build hours buy nothing here) side by side across a
  cutoff sweep; count or exclude NULL rows (1,165 ink, 305 pen before S08's cleanup — S08 re-enqueues
  them, so by the time this step runs there should be none left; count what remains as a sanity
  check, not an expected steady state). The owner picks **one** embedding model (used for both
  tables and both columns, as the plan's single embeddings entry implies) and a **cosine cutoff per
  table** (ink and pen may differ, as S09's constants already do); record the pick in the migration
  plan. The plan asks this step for a THRESHOLD only ("Report recall across cutoffs and pick a new
  threshold for the chosen model", docs/llm-migration-plan.md:214-215), and this bench cannot measure
  `ef_search` at all: the bench table carries no index, so the ANN parameter has no effect here.
  `ef_search` therefore keeps today's per-table values (`MacroCluster::HNSW_EF_SEARCH = 200`,
  `Pens::Model::HNSW_EF_SEARCH = 1000`, S09) unless S26's `EXPLAIN` or S27's watch week shows a need
  to change them.

- **Depends on.** S18 (`fetch_many` no-cache path, explicit-entry client, model-aware cache), S21
  (pen retrieval cases in the harness), S01 (candidate ids, limits). Placed after S22 so the harness
  is validated first (ordering, not a hard dependency).
- **Why here.** The plan decides embeddings before chat models: InkClusterer's and the pen agent's
  benches both go through `embedding_search`, so a chat model pick made on the old embeddings would
  be invalidated the moment the embedding model changes underneath it.
- **Does not include.** Any prod change.
- **Definition of done.** Recall-vs-cutoff table per model per table in the migration plan; the pick
  and the new per-table cutoffs written down (no `ef_search` pick — see the goal); bench DDL script
  and its spec merged.
- **Implementation notes.**
  - Verified numbers (prod, 2026-09-12, from the prod data check): ink_embeddings **797,700** rows
    (1,165 with a NULL vector; owners CollectedInk 704,255 / MicroCluster 75,844 / MacroCluster
    17,601), pen_embeddings **210,534** rows (305 NULL; CollectedPen 201,610 / Pens::ModelVariant
    7,126 / Pens::Model 1,798). Total relation sizes 8,833 MB / 3,233 MB.
  - Prod-path constants to reproduce: macro_cluster.rb:108 `SET hnsw.ef_search = 200`, tier LIMITs
    200/200/2000 with `.reject { neighbor_distance > 0.6 }` at :126,:136,:147; pens/model.rb:33 `SET
hnsw.ef_search = 1000`, LIMITs 200/200/2000 at :40-71 (post-S09 these read from
    `SIMILARITY_CUTOFF`/`HNSW_EF_SEARCH`, not literals). Pen model recall uses
    `data.owner.pen_model`; variant recall for tier-1 hits comes from
    `Pens::ModelVariant.where(model_micro_cluster: model.model_micro_clusters)`, not from the search
    result (S02 rule).
  - The four DO embedding candidates and their catalog ids/prices/limits come from S01's findings
    table; do not re-derive them here.
- **Decisions applied.** Q12.

### S24-embedding-v2-backfill — `embedding_v2` columns, two-entry embeddings config, dual-write (YAML flip PR), self-chaining backfill; run the prod backfill

- **Goal.** Migration adding nullable `embedding_v2 vector(1024)` (the column is named `embedding_v2`
  and keeps that name forever; there is no rename step anywhere in this roadmap — Q31) to
  `ink_embeddings` and `pen_embeddings`, no index yet (safe in the release command; no
  `disable_ddl_transaction!` needed for a nullable column with no default). Template:
  db/migrate/20250401120318_create_ink_embeddings.rb:1-9 (`t.vector :embedding, limit: 1536, index:
{ using: :hnsw, opclass: :vector_cosine_ops }`) -> a plain migration body
  `add_column :ink_embeddings, :embedding_v2, :vector, limit: 1024` /
  `add_column :pen_embeddings, :embedding_v2, :vector, limit: 1024` (no `index:` option here — S26
  builds the index separately). `has_neighbors :embedding, :embedding_v2` on both `InkEmbedding`
  and `PenEmbedding` (neighbor 1.2.0 is already the pinned version, Gemfile.lock:309; `model.rb:3`
  supports `has_neighbors(*attribute_names, ...)` with per-attribute dimension validation at :42-57
  validated against each column's own `limit:` — do **not** pass a shared `dimensions:` option, which
  would validate both columns against one dimension count and break the 1536 column) with a model
  spec proving the two dimensions are validated independently (assign a 1024-float array to
  `embedding_v2` and a 1536-float array to `embedding` on the same record and expect both valid; a
  1536-float array on `embedding_v2` must be invalid).

  `config/llm.yml` (created by S04) gains an `embeddings:` block with two named entries:
  `embeddings.legacy` (`model: text-embedding-3-small`, `api_key_env: OPEN_AI_EMBEDDINGS`,
  `column: embedding`, `dims: 1536`) and `embeddings.current` (`model:` the DO embedding model S23
  picked, `api_key_env: DO_INFERENCE_TOKEN`, `column: embedding_v2`, `dims: 1024`), plus a scalar
  `embeddings.read` naming which entry queries use (value `legacy` until S27) and a scalar
  `embeddings.dual_write` (`true`/`false`). Config validation (extend whatever S18 built) raises a
  clear configuration error at boot if `read` names an entry that does not exist under `embeddings:`.
  The two `embedding_search` methods (`Pens::Model.embedding_search`, app/models/pens/model.rb:30,
  and `MacroCluster.embedding_search`, app/models/macro_cluster.rb:105) derive the query embedding
  model from `embeddings.read`, and all SIX `nearest_neighbors` calls (pens/model.rb:38, :48, :67 and
  macro_cluster.rb:123, :132, :143) take the column from the `read` entry — never a literal column
  name or model string. This PR does not change `read` (it stays `legacy`); it only adds the plumbing
  the flip (S27) will use.

  `FetchEmbedding#perform` (app/workers/fetch_embedding.rb, currently 22 lines:
  `sidekiq_throttle concurrency: { limit: 4 }`, `sidekiq_options queue: "low"`,
  `model.update!(embedding: fetch_embedding)` where `fetch_embedding` calls
  `EmbeddingsClient.new.fetch(model.content)`) is rewritten, not extended, and the rule is expressed
  against `read`, never against a fixed column: it ALWAYS writes the column named by
  `embeddings.read` (today `legacy`, from S27 on `current`), and additionally writes the OTHER
  entry's column whenever `embeddings.dual_write` is true. Stating it this way is what keeps the read
  column from ever going unwritten — after S27 flips `read` to `current`, a rule that hard-coded
  "always write legacy" would leave every newly saved ink or pen with a NULL `embedding_v2`, the very
  column reads now use, during S34's `dual_write: false` window. (Equivalently: S24 and S34 must agree
  that the `dual_write: false` flip and this worker's rule ship in one deploy, with S34's queue-drain
  check done BEFORE that deploy, not between two deploys.) The `current` write goes through the SAME content-digest cache as
  the `legacy` write, under S18's model-aware cache key — single-row organic traffic is low volume, so
  only `BackfillEmbeddings` bypasses the cache. Both writes happen in the one `after_save` callback path
  (`PenEmbedding#fetch_embedding` / `InkEmbedding#fetch_embedding`, both currently
  `return unless content_previously_changed?; FetchEmbedding.perform_async(self.class.name, id)` —
  unchanged call site, only the worker body changes).

  `BackfillEmbeddings` (new worker, `queue: "low"`) uses the `current` entry ONLY and **never
  touches `Rails.cache`** — the no-cache path S18 builds for the batch/explicit-entry client,
  because 1,008,262 rows (797,725 ink + 210,537 pen — TOTAL rows, prod 2026-09-12; 796,559 and
  210,232 of them respectively carry a vector today, the rest being the NULL-vector rows S08
  re-enqueues, which means `where(embedding_v2: nil)` also enumerates those ~1,471 content-carrying
  rows, correctly and intentionally) at 10-21 KB per cached vector would push 10-20 GB into the prod
  cache Redis, whose size cannot be
  verified without the Fly login (S00 item). Shape: one Sidekiq job per batch,
  `BackfillEmbeddings.perform(class_name, ids = nil)` — a nil `ids` means "enumerate the first batch
  from `where(embedding_v2: nil).order(:id).limit(100).pluck(:id)`, process it, then chain", which is
  what makes the one-argument kick-off in the runbook below legal; otherwise `ids` is a batch of <= 100
  — embeds those rows in one batched
  `fetch_many` call (S18's explicit-entry, no-cache client) and writes them with
  `update_columns`/`upsert_all` (skips `after_save`, so it cannot re-trigger `FetchEmbedding`). A
  coordinator (or the last batch, self-chaining) enqueues the next batch from
  `where(embedding_v2: nil).order(:id).limit(100).pluck(:id)` until that query returns empty
  (`content` is `NOT NULL`, db/structure.sql:458 for `ink_embeddings` / :790 for `pen_embeddings`,
  and 0 rows have `content = ''` on prod, so no content-blank guard is needed). Each batch is
  idempotent — it skips rows already filled by dual-write or a previous partial run — so a deploy
  mid-backfill (the Sidekiq worker restarts with `:timeout: 90`, config/sidekiq.yml:1; S25 merges
  concurrently) loses at most one in-flight batch, which the next `where(embedding_v2: nil)`
  enumeration re-picks-up; the chaining is done by the LAST batch enqueuing the next one — there is
  no separate coordinator class. sidekiq-throttled 2.1.0's `threshold:` pacing counts job EXECUTIONS
  (strategy.rb:43-56), so it only produces the intended rate when there is exactly one row-processing
  job per batch (not one job per row). Use `sidekiq_throttle concurrency: { limit: 2 }` — half of
  `FetchEmbedding`'s existing `limit: 4` (app/workers/fetch_embedding.rb:5), so organic embedding
  traffic keeps priority — and set `requeue: { with: :schedule }` (valid in 2.1.0, strategy.rb:43,107,131 — the
  default `:enqueue` would busy-loop the `low` queue when throttled) on the class. Pace it
  deliberately: Sidekiq's queues run in the strict priority order `mailers, agents, default, low,
reviews` (config/sidekiq.yml:4-8), so a saturated `low` queue starves `reviews` (ReviewApprover
  follow-ups) for hours.

  Sidekiq retry: keep the gem default (25 attempts); do not add an explicit `sidekiq_options retry:`
  to `BackfillEmbeddings` — the retry-budget question (Q4) is deferred until after the first DO
  flips, and `RunPenClustererAgent`'s `retry: 2` (S13) is the one decided exception, not a general
  policy.

  Update `spec/workers/fetch_embedding_spec.rb` (currently one example, lines 3-19: stubs
  `POST https://api.openai.com/v1/embeddings` with the exact body
  `{model: "text-embedding-3-small", input: "content"}` and a 1536-float vector response, asserts
  `embedding.reload.embedding == vector`) so it keeps passing with `dual_write: false` (the PR's
  shipped default) — the existing example only exercises the `legacy` write and needs no new stub;
  add new examples for `dual_write: true` (a second stub against the `current` entry's `api_base`,
  asserting `embedding_v2` is also written) and `dual_write: false` (asserting `embedding_v2` stays
  `nil`). Add `spec/factories/ink_embeddings.rb` (only `spec/factories/pen_embeddings.rb` exists
  today; four lines, an EMPTY `factory :pen_embedding do ... end` with no attributes at all — callers
  pass `owner:` and `content:` explicitly, see spec/workers/fetch_embedding_spec.rb:6). Mirror exactly
  that empty shape; do NOT declare a polymorphic `owner` association in the factory, since FactoryBot
  cannot resolve one without a concrete type.

  The PR ships with `embeddings.dual_write: false` in every environment. **After merge, run this
  exact sequence, in order** (this list is the runbook, not a suggestion):
  1. Confirm the `DO_INFERENCE_TOKEN` Fly secret already exists (S00 sets it before S11 merges, so it
     predates this step; nothing to create here — this is the first prod DO EMBEDDINGS traffic, not
     the first prod DO traffic at all, because the pen agents have been calling DO chat models since
     S15).
  2. Flip `embeddings.dual_write` to `true` — a second small PR editing `config/llm.yml` plus a
     deploy (the config format is a YAML file in the repo, so every flip in this whole migration is a
     `git`-reviewable PR, never a bare `flyctl secrets set`) — and merge it **before** starting the
     backfill. Skipping this ordering means rows edited during the hours-long backfill get a fresh
     `embedding` write but a NULL `embedding_v2` that only the final backfill sweep (re-running the
     `where(embedding_v2: nil)` enumeration once more) catches.
  3. Verify one new pen and one new ink each get both columns populated (create one of each in
     `fly console`, or watch the next organic import).
  4. Start the backfill from `fly console` (no rake wrapper is built): `BackfillEmbeddings.perform_async("InkEmbedding")`
     and `BackfillEmbeddings.perform_async("PenEmbedding")` — the one-argument form, which the nil
     `ids` default turns into "enumerate the first batch and chain". It is the self-chaining worker,
     not a blocking rake loop.
  5. Watch, for the duration of the run: `reviews` queue latency (Sidekiq Web or `fly logs`), DO 429
     responses, and Honeybadger (`sidekiq.attempt_threshold: 3`, config/honeybadger.yml:42-43, so a
     handful of retried batches is silent — watch for a sustained climb, not single blips).

- **Depends on.** S23-embeddings-bench (the DO embedding model pick), S00-ops-prereqs (the
  `DO_INFERENCE_TOKEN` Fly secret, set before S11 merged — already true well before this step).
- **Why here.** First prod-touching migration step in the embeddings half of the migration, additive
  only (no read change yet); its multi-hour run overlaps the shadow-mode code (S25), which needs no
  embeddings work at all.
- **Does not include.** The HNSW index on `embedding_v2` (S26 — an index would slow down the batched
  `UPDATE`s during the backfill for no benefit since nothing queries the column yet). Any change to
  what `embeddings.read` points at (S27).
- **Definition of done.**
  - `structure.sql` regenerated inside the app container: `docker-compose exec app bin/rails
db:schema:dump` (the project sets `config.active_record.schema_format = :sql` at
    config/application.rb:30, so this is what writes `db/structure.sql`; `bin/rails db:migrate`
    regenerates it too). `db:structure:dump` does NOT exist in Rails 8 — never hand-edit the file,
    never run the dump on the host (host Postgres.app is 18.x, the container has pg_dump 17.x).
  - Specs: dual-write on and off (both write paths asserted independently), a batch of exactly 100
    ids processed in one job, the self-chaining behavior (enqueue-the-next-batch) proven down to zero
    remaining rows so resumability is demonstrated, the two-column dimension validation spec, the
    `embeddings.read` config validation (bad entry name raises at load), and an assertion on the
    declared throttle strategy (read `BackfillEmbeddings.sidekiq_throttle_options` or equivalent
    class-level config in the spec — do not try to exercise actual rate-limiting under fake Sidekiq,
    since sidekiq-throttled's counting only means anything against a real Redis and real elapsed
    time; the real pacing is verified on prod via `low` queue latency per the runbook above).
  - Backfill run report: `InkEmbedding.where(embedding_v2: nil).count == 0` and
    `PenEmbedding.where(embedding_v2: nil).count == 0` on prod (read-only URL).
  - Prod Redis memory graph flat during the entire backfill window (proves the no-cache path held).
  - Runbook entry recorded in docs/llm-migration-plan.md: rollback = set `embeddings.dual_write` back
    to `false` (a PR + deploy); if `embeddings.read` was ever experimentally flipped, flip it back
    first. The nullable `embedding_v2` column is left in place either way — dropping the OLD
    `embedding` column is S35's job, two steps (S34, S35) after the read flip, never here.

- **Decisions applied.** Q1 (YAML config, `embeddings.dual_write` is a one-line PR-and-deploy flip,
  not an ENV var or `flyctl secrets set`), Q3 (the DO key is the one name `DO_INFERENCE_TOKEN`,
  already provisioned by S00; `OPEN_AI_EMBEDDINGS` stays as the `legacy` entry's key name), Q4
  (deferred — no explicit retry budget on `BackfillEmbeddings`; Sidekiq's default 25 stands), Q9 (the
  tables are complete going into this backfill because S07 routed CSV imports through
  `SaveCollectedPen` before S08's one-off re-save ran — there is no later pen re-save to coordinate
  with the backfill), Q31 (the column is `embedding_v2` forever; nothing here anticipates a rename).

### S25-shadow-code — Shadow-mode code for InkClusterer and ReviewApprover, sub-agents on the candidate (not enabled)

- **Goal.** A shadow entry point that calls the agent's `decide` with the candidate model's config
  injected and records the result as a distinct AgentLog name
  (`InkClusterer::Shadow`, `ReviewApprover::Shadow`), moved to a terminal state with
  `extra_data["shadow"] = true`, never `waiting_for_approval!` and never `schedule_follow_up!`. A
  same-named log would interfere with prod in two independent ways if it were not kept fully
  separate: while `processing` it would be picked up and re-enqueued by `RunFailedClusterJobs` (which
  only restarts `AgentLog.ink_clusterer.processing` rows older than 15 minutes,
  app/workers/run_failed_cluster_jobs.rb:16-18) and rejected by `CleanUp` after 3 hours
  (`AgentLog.processing.where("updated_at < ?", 3.hours.ago)` has no name filter at all,
  app/workers/clean_up.rb:43-49, so ANY stuck shadow log is swept regardless of name — this is a
  safety net, not something to rely on); once `waiting-for-approval` a same-named log would block new
  prod runs via `already_resolved?` and would appear in the admin review queue
  (`Admins::Agents::InkClustererController#agent_logs`,
  app/controllers/admins/agents/ink_clusterer_controller.rb:71-78, currently scoped to
  `AgentLog.ink_clusterer.where(state: [WAITING_FOR_APPROVAL, PROCESSING]).or(AgentLog.ink_clusterer.agent_processed).with_collected_inks`).
  The shadow classes use their OWN AgentLog `name` (`"InkClusterer::Shadow"`,
  `"ReviewApprover::Shadow"`) specifically so none of that machinery ever sees them by accident, but
  every one of those call sites is still audited below because a couple of them filter by anything
  BUT name (`CleanUp`, `CheckInkClustering::Human`'s `PreviousAgentLogs` tool) and must be corrected
  explicitly.

  **The on/off switch, shipped in this PR, off everywhere.** `config/llm.yml` (S04) gains a `shadow:`
  block inside `shared:` mapping agent class name -> the name of the candidate chat entry to shadow
  with: `shadow: { "InkClusterer": null, "ReviewApprover": null }`. The inline hook reads
  `LlmConfig.shadow_entry_for(self.class.name)` and returns immediately — no log, no LLM call, no
  measurable cost — when it is nil, which is what every environment ships with here. When it is
  non-nil, the hook opens ONE `LlmConfig.with_override` block naming the shadowed agent plus THE
  SUB-AGENTS THAT AGENT ITSELF CALLS — Q14 is per-agent, not a fixed set of four, and S32 names the
  same pairs: `LlmConfig.with_override("InkClusterer" => candidate, "GoogleSearchSummarizer" =>
candidate)`, and for the other agent `"ReviewApprover"`, `"YoutubeSummarizer"` and
  `"WebPageSummarizer"`. The override lasts for the duration of the shadow `decide` call only.
  Without naming the sub-agents, `Tools::InkWebSearchTool#execute` (ink_web_search_tool.rb:17) and
  `ReviewApprover::Summarize#execute` (review_approver.rb:64-73) would keep running them on
  the prod OpenAI model and silently invalidate the whole comparison. S32 is then a one-line YAML PR
  filling in the two values; turning shadow off again is a revert of that PR.

  **Timing.** The shadow run must see the same world as the prod run it is being compared against. A
  shadow started only after the prod run has fully completed does not: for `InkClusterer`, by the
  time a follow-up checker (`CheckInkClustering::*`) has run, `execute_decision!` may already have
  called `approve!(agent: true)` and set `micro_cluster.macro_cluster_id` — after which the cluster's
  own ink embedding shows up inside tier 2 of the SAME agent's next retrieval at distance ~0 (self-
  match), corrupting any later shadow comparison; for `ReviewApprover`, the review has already been
  approved or rejected by the prod tool call (`ApproveReview#execute` / `RejectReview#execute` call
  `ink_review.agent_approve!` / `agent_reject!` directly, review_approver.rb:16-26 and :41-51;
  `InkReview#agent_approve!`/`#agent_reject!` are ink_review.rb:72-80 and :82-90), and
  `number_of_reviews` (`cluster.ink_reviews.live.size` at review_approver.rb:174, used inside
  `format_cluster_data` at :170, decisive in the SYSTEM_DIRECTIVE's ordered rules) has
  already changed. So: run the shadow `decide` SYNCHRONOUSLY, inline in the same prod worker
  invocation, sandwiched between the prod `decide` and the prod's `waiting_for_approval!` /
  `schedule_follow_up!` (or the prod tool write, for `ReviewApprover`) — never as a separately
  scheduled async job that could run after the state has moved on. Concretely:
  - `InkClusterer#perform` is, after S19 (`ink-decide-entry-point`), the shape
    `guards -> decide(agent_log:) -> waiting_for_approval! -> schedule_follow_up!` (`perform` at
    ink_clusterer.rb:180-205, `already_resolved?` at :279-292, `agent_log` at :173-178). Insert the shadow
    call immediately after the prod `decide` call and before `waiting_for_approval!`.
  - `ReviewApprover#perform` currently is `ink_review.ensure_youtube_metadata! -> ask!(user_prompt,
with: resolved_image_url) -> agent_log.update!(extra_data: ink_review.extra_data) ->
agent_log.waiting_for_approval!` (review_approver.rb:124-129). Run the shadow BEFORE the prod `ask!` call
    (i.e., before any tool has had a chance to write `ink_review.agent_approve!` /
    `agent_reject!`), reusing the same freshly-fetched `ink_review` state.
  - Spec requirement: assert the shadow's user prompt is byte-identical to the prod run's user prompt
    for the same owner (both agents build their prompt from the same instance state at the same
    point in time, so this is really an assertion that the shadow call happens before any prod
    mutation, not a prompt-formatting test).

  **Identity.** `InkClusterer::Shadow < InkClusterer` MUST override `agent_log` to always create (or
  find-by-its-own-name) a FRESH shadow log, because the inherited lookup
  (`micro_cluster.agent_logs.ink_clusterer.processing.first` /
  `.waiting_for_approval.first` chain, ink_clusterer.rb's `agent_log` method) would find the prod log
  that is, at that exact moment, sitting `processing` (mid-`perform`) and attach the shadow's
  transcript onto it — corrupting the prod transcript. The override looks like:

  ```ruby
  def agent_log
    @agent_log ||=
      micro_cluster.agent_logs.create!(
        name: self.class.name,
        transcript: [],
        state: AgentLog::REJECTED,
        rejected_at: Time.current,
        agent_approved: false,
        extra_data: {
          "shadow" => true
        }
      )
  end
  ```

  (name resolves to `"InkClusterer::Shadow"` automatically via `self.class.name`.) The log is
  **created already in a terminal state** with `extra_data["shadow"] = true`, exactly as the migration
  plan decides (docs/llm-migration-plan.md, P4) — not created `processing` and finalised later. The
  transcript is appended to that already-terminal row by `save_transcript`, which touches `transcript`
  and `usage`, never `state`. Two consequences worth stating: there is no reuse lookup at all, so the
  hazard of a second shadow run on the same micro cluster picking up the previous run's finished log
  and replaying its transcript (`build_chat` -> `restore_transcript`, ruby_llm_agent.rb:85-92 and :89)
  simply cannot arise — and micro clusters ARE re-clustered routinely (`reject_and_reprocess!`,
  app/controllers/admins/agents/ink_clusterer_controller.rb:80-87, `destroy_all` at :83), so that
  hazard would otherwise fire in normal operation; and a shadow log is never `processing`, so neither
  `RunFailedClusterJobs` nor `CleanUp`'s 3-hour name-agnostic sweep can ever see one. Do NOT use
  `find_or_create_by!(name:)` or the concern's `find_or_create_agent_log` shape here. `Shadow` must
  never call `perform` — it only ever calls `decide`, directly. `ReviewApprover::Shadow`'s inherited
  `find_or_create_agent_log(ink_review)` (from `RubyLlmAgent`,
  `@agent_log ||= owner.agent_logs.processing.where(name: self.class.name).first; @agent_log ||=
owner.agent_logs.create!(name: self.class.name, transcript: [])`) is already safe as-is, because
  it keys the lookup on `self.class.name`, which is already the distinct `"ReviewApprover::Shadow"`
  string for the subclass — no override needed there.

  **A shadow failure must never touch the prod run.** The shadow call runs INLINE inside the prod
  worker (see Timing above), so the hook wraps it in `rescue StandardError => e` — record
  `e.class.name` and `e.message` into the shadow log's `extra_data`, then SWALLOW — in addition to an
  `ensure` that records the finish (the log is already terminal from `create!`, so the `ensure` has no
  state transition left to make). An `ensure` alone does not stop the exception: it would propagate
  out of the prod worker before `waiting_for_approval!`/`schedule_follow_up!` (or, for
  `ReviewApprover`, before the prod `ask!`), and Sidekiq would retry the WHOLE prod run — re-paying
  the prod prompt for a shadow-side fault. The shadow is a measurement; it can never fail the thing it
  measures.

  **`ReviewApprover::Shadow` dry-run tools.** Its `tools` method returns dry-run replacements for
  `ApproveReview`/`RejectReview` — call them e.g. `Shadow::ApproveReview` / `Shadow::RejectReview` —
  that record the verdict into `agent_log.extra_data` (the SHADOW log's extra_data, never
  `ink_review.extra_data`, which the real tools mutate and which must stay untouched by the shadow)
  and then `halt`, mirroring the halting-tool pattern `InkClusterer`'s own decision tools already use
  (`AssignToCluster`/`CreateNewCluster`/etc., ink_clusterer.rb — `update_extra_data` then `halt`).
  Never call `agent_approve!`/`agent_reject!` from the shadow tools. `ReviewApprover` has no `decide`
  method today (its only entry point is `perform`, review_approver.rb:124-129), so this step DEFINES
  one on the subclass: `ReviewApprover::Shadow#decide` is `ink_review.ensure_youtube_metadata!`
  (idempotent) plus `ask!(user_prompt, with: resolved_image_url)` and NOTHING else — no
  `agent_log.update!(extra_data: ink_review.extra_data)`, no `waiting_for_approval!`. The shadow entry
  point calls `decide`, never `perform`, and `ReviewApprover::Shadow#perform` is overridden to raise
  `NotImplementedError` so `RunAgent` can never enqueue it by accident. It does NOT copy
  `ink_review.extra_data`, because that hash belongs to the prod run and the shadow must not
  read-then-write it. Keep `Summarize` exactly as the prod class defines it — its
  `ink_review.ensure_youtube_metadata!` call is idempotent (safe to call twice) and the prod run will
  already have called it earlier in the same worker invocation by the time the shadow runs, so no
  shadow-specific `Summarize` subclass is needed; any `YoutubeSummarizer`/`WebPageSummarizer` sub-
  agent invocations the shadow's `Summarize` triggers become CHILD agent logs of the SHADOW log (pass
  the shadow's own `agent_log`, not the prod one, into `Summarize.new(ink_review, agent_log)`).

  Store `prod_agent_log_id`, the candidate model id (read back from the override / from
  `chat.model.id` after the call), and the prod run's own decided action (only knowable after the
  prod run also completes — write it once, right after the prod side finishes, as an `extra_data`
  update on the already-terminal shadow log) into the shadow log's `extra_data`, so a later
  `bench:shadow_report` task can join shadow verdict vs. prod verdict vs. eventual human verdict by
  ID instead of guessing from owner and timestamp proximity.

  **Exclusions everywhere a name-agnostic query could otherwise pick up a shadow log:**
  - `CheckInkClustering::Human`'s `PreviousAgentLogs` tool
    (`micro_cluster.agent_logs.where.not(id: agent_log.id).order(:created_at)`, no name filter,
    app/agents/check_ink_clustering/human.rb:24-28, the query on :26) currently returns EVERY log
    of the micro cluster regardless of name. Add a name filter/exclusion here — either
    `.where(name: "InkClusterer")` or `.where.not("name LIKE '%::Shadow'")` — so the model reviewing a
    hand-over never sees a shadow transcript mixed into "previous logs of this cluster".
  - `delete_history` (`Admins::Agents::InkClustererController#reject_and_reprocess!` ->
    `cluster.agent_logs.destroy_all if params[:delete_history].present?`,
    app/controllers/admins/agents/ink_clusterer_controller.rb:80-87, the `destroy_all` at :83) DOES
    also delete shadow logs for that
    cluster when a human uses "delete history" — this is acceptable (it only loses shadow comparison
    data, never anything that affects a prod decision), so this is a documented behavior, not a bug
    to fix.
  - `AdminStats#micro_cluster_agent_review_count`
    (`AgentLog.ink_clusterer.waiting_for_approval.or(AgentLog.ink_clusterer.agent_processed).with_collected_inks.count`,
    app/models/admin_stats.rb:14-21) is scoped to `.ink_clusterer` (name `"InkClusterer"` exactly), so
    `InkClusterer::Shadow` rows — which never enter `waiting_for_approval` anyway — do not appear
    here; verify this with a spec rather than trusting it silently.
  - `app/views/admins/reviews/index.html.slim:67`
    (`ink_review.agent_logs.select { |l| l.name == "ReviewApprover" }.max_by(&:created_at)`) already
    filters by the EXACT name `"ReviewApprover"`, so `ReviewApprover::Shadow` rows are already
    excluded there with no code change needed — confirm with a view/request spec, don't just assume.

  `bench:shadow_report` (a new rake task under `lib/tasks/bench.rake` or similar) runs on the LOCAL
  machine against `PRODUCTION_READONLY_DATABASE_URL` — the same read-only URL S27's watch-week queries
  use, and the only place bench code ever runs (migration Decisions, "Bench execution | Local machine
  only, not CI"); there is no `fly ssh console` variant: it joins each shadow log to its prod log via
  `extra_data->>'prod_agent_log_id'`, reads the InkClusterer human verdict from the prod log's
  final `state` / `agent_approved` flag, and reads the ReviewApprover human verdict from
  `ink_reviews.approved_at`/`rejected_at` combined with `agent_approved: false` (meaning a human
  overrode the agent). The task is triggered manually — it does nothing automatically and requires no
  Sidekiq scheduling — and only produces meaningful output once S32 has filled in a candidate entry
  in the `shadow:` block (default: both values nil, so this whole PR ships enabled-nowhere).

- **Depends on.** S19-ink-decide-entry-point (the side-effect-free `decide(agent_log:)` shape both
  `InkClusterer` and the shadow subclass call), S04-llm-config-chat (the `LlmConfig.with_override`
  scoped-injection mechanism). S20-harness-core-ink is a soft dependency only (the
  `bench:shadow_report` task lives under the same `lib/bench/` tree the harness core establishes, but
  nothing here calls into the harness runner itself).
- **Why here.** Pure code, written and merged during the multi-hour backfill wait (S24) with zero
  runtime effect on prod (shadow mode stays off — the config injection this step relies on is not
  invoked by anything until S32 enables it after the chat-model pick, S30). Placing it here means the
  two-week shadow-run window (S32) is pure ops/config work with no code left to write.
- **Does not include.** Actually enabling shadow mode for any agent (that is S32, a config-only,
  non-code step). Adding shadow mode for any agent besides `InkClusterer` and `ReviewApprover`.
- **Definition of done.**
  - Specs, `InkClusterer::Shadow`: running the shadow produces zero side effects on the micro cluster
    or on any prod `AgentLog` row; with a prod `waiting-for-approval` `InkClusterer` log already
    present on the same micro cluster, running the shadow leaves that prod log's transcript, state,
    and `extra_data` completely unchanged; a shadow run that raises leaves NO `processing` shadow log
    behind (the log is terminal from `create!`) and, crucially, leaves the PROD run's
    `waiting_for_approval!`/`schedule_follow_up!` path (and, for `ReviewApprover`, the prod `ask!`)
    untouched and causes NO Sidekiq retry — assert the prod log still ends `waiting-for-approval` and
    the worker returns normally when the shadow raises; the shadow log is invisible to
    `already_resolved?`, invisible to the admin queue scope
    (`ink_clusterer_controller.rb:71-78`), invisible to `AdminStats#micro_cluster_agent_review_count`,
    and — extending `spec/workers/run_failed_cluster_jobs_spec.rb` (the "does not restart processing
    logs for other agent types" example at lines 46-55 already proves the pattern for an arbitrary
    other name; add one more example using the literal name `"InkClusterer::Shadow"`) — never
    restarted by `RunFailedClusterJobs`.
  - Specs, `ReviewApprover::Shadow`: the shadow's dry-run tools never call `agent_approve!` /
    `agent_reject!` and never mutate `ink_review.extra_data`; the shadow's prompt equals the prod
    prompt built from the same `ink_review` state; the admin reviews view
    (`spec/views/admins/reviews/index.html.slim_spec.rb` or an equivalent request spec) confirms a
    `ReviewApprover::Shadow` log is never selected as the displayed transcript.
  - Spec: `CheckInkClustering::Human`'s `PreviousAgentLogs` tool excludes shadow-named logs from its
    JSON output (create both a prod log and a shadow log on the same micro cluster; assert only the
    prod one appears).
  - `bench:shadow_report` task spec: given fixture shadow + prod + human-verdict rows, produces the
    expected joined comparison rows.
  - Spec: with NO shadow entry configured (the shipped default), a prod `InkClusterer#perform` makes
    exactly ONE LLM request and creates NO `InkClusterer::Shadow` `AgentLog` row — this is what proves
    the PR is inert on merge.
  - Spec: a second shadow run on a micro cluster that already has a TERMINAL `InkClusterer::Shadow`
    log creates a NEW log whose starting transcript is empty, and leaves the old log untouched.
  - Spec (Q14): a shadow `InkClusterer` run that triggers `search_web` sends the
    `GoogleSearchSummarizer` request to the CANDIDATE `api_base`/model — asserted on the WebMock
    request body — while the prod run in the same worker invocation used the configured OpenAI
    model.
- **Implementation notes.**
  - Prod entry points to hook: `RunInkClustererAgent#perform -> InkClusterer#perform`
    (app/workers/run_ink_clusterer_agent.rb) and
    `RunAgent.perform_async("ReviewApprover", ink_review.id)` (from
    app/workers/process_ink_review_submission.rb) -> `ReviewApprover#perform` (review_approver.rb).
  - Spec templates to extend: the `context "idempotency guard"` block at
    spec/agents/ink_clusterer_spec.rb:374 — add a case where only an
    `InkClusterer::Shadow` `waiting-for-approval`-equivalent (terminal) log exists on the micro
    cluster and confirm a fresh prod run still proceeds normally (i.e., a shadow log's mere presence,
    in whatever state, never blocks a prod run the way a same-named prod log would).
  - The token-usage graph (`Admins::GraphsController#agent_usage`,
    app/controllers/admins/graphs_controller.rb:94) groups by `name`, so `InkClusterer::Shadow` /
    `ReviewApprover::Shadow` show up as their own series automatically, with no graph code change;
    this is worth noting in the PR description so nobody is surprised by new series appearing once
    S32 turns shadow mode on.
  - Cost note for later (S31): once shadow mode is live, the shadow's own `search_web` sub-agent call
    (Q14: same candidate model as the shadowed agent) doubles the `GoogleSearchSummarizer` / Serper
    calls for every shadowed `InkClusterer` run — factor this into S31's cost estimate, not into this
    step's DoD.

- **Decisions applied.** Q14 (sub-agents — `GoogleSearchSummarizer` inside `search_web`,
  `YoutubeSummarizer`/`WebPageSummarizer` inside `Summarize` — run on the SAME candidate model as the
  shadowed agent under test; the shadow entry point sets `LlmConfig.with_override` for the shadowed
  class AND for the relevant summarizer classes together, for the duration of the shadow `decide`
  call only), Q2 (the override is the scoped, thread-safe, per-class temporary mechanism S04 built;
  this step is one of its two intended callers, the other being the bench harness).

### S26-hnsw-index-v2 — HNSW cosine index on `embedding_v2` for both tables: built by hand from a detached session, then a recording migration

- **Goal.** Once S24's backfill reports zero remaining `NULL` `embedding_v2` rows on both tables,
  build the two HNSW indexes THE DECIDED WAY: by hand, at a quiet hour, from a DETACHED session —
  never an interactive `fly console` and never inside a transaction — with
  `SET maintenance_work_mem = '1GB'` and DEFAULT index parameters (no custom `m` / `ef_construction`;
  the existing prod 1536-d indexes were built with defaults too — `pg_class.reloptions` is `NULL` for
  both today, confirmed on the read-only URL — so the plain, parameter-less `add_index` helper
  reproduces today's settings exactly, and there is no case in this migration for hand-tuned HNSW
  parameters). Afterwards, merge a recording migration so `structure.sql` matches what was actually
  built on prod:

  ```ruby
  class AddIndexToEmbeddingV2 < ActiveRecord::Migration[8.1]
    disable_ddl_transaction!

    def change
      add_index :ink_embeddings, :embedding_v2,
                using: :hnsw, opclass: :vector_cosine_ops,
                algorithm: :concurrently, if_not_exists: true
      add_index :pen_embeddings, :embedding_v2,
                using: :hnsw, opclass: :vector_cosine_ops,
                algorithm: :concurrently, if_not_exists: true
    end
  end
  ```

  (Rails' generated index name for `add_index :ink_embeddings, :embedding_v2` is
  `index_ink_embeddings_on_embedding_v2`, following the existing `index_ink_embeddings_on_embedding`
  naming at db/structure.sql:1908-1911 / :2062-2065 — the two new index-definition blocks will land
  alphabetically right after those, since `embedding` sorts before `embedding_v2`.) Combine the
  `algorithm: :concurrently` + `disable_ddl_transaction!` pattern from
  db/migrate/20260625120200_add_index_to_users_patreon_user_id.rb (a real, already-merged example of
  exactly this pattern in this repo) with the `using: :hnsw, opclass: :vector_cosine_ops` pattern from
  db/migrate/20250331124026_add_vector_index.rb (`add_index :pen_embeddings, :embedding, using: :hnsw,
opclass: :vector_cosine_ops` inside a `safety_assured do ... end` block — note that migration uses
  the NON-concurrent form and had to wrap it in `safety_assured` precisely BECAUSE strong_migrations
  (Gemfile.lock:541, in this repo since 2020) flags a non-concurrent `add_index` on an existing table;
  the new migration here uses `algorithm: :concurrently` instead, which strong_migrations accepts
  without `safety_assured`, and
  because `if_not_exists: true` makes it a no-op — not an error — against an index that was already
  built by hand). `if_not_exists: true` is the mechanism that makes "build by hand first, migration
  merges after" safe: when the migration runs (in CI against a fresh test DB, and whenever the release
  command runs against prod) it either builds the index itself (fresh DB, e.g. a new developer's local
  setup or CI) or silently confirms the by-hand index already exists (prod) — there is no window where
  the release command tries to redundantly rebuild a multi-hundred-MB index during a deploy.

  **Facts that justify the by-hand-first approach over letting a migration run inside the release
  command:** prod's `maintenance_work_mem` is 149 MB by default, but its config context is `user`, so
  it is settable per-session (`SET maintenance_work_mem = '1GB'` immediately before the `CREATE INDEX`
  statement — `maintenance_work_mem`'s `pg_settings.context` is `user`, so it is settable per
  session; this was verified from the read-only role `fpc_readonly`. Re-run
  `SET maintenance_work_mem = '1GB'; SHOW maintenance_work_mem;` in the detached session as the app's
  own role before starting the build, since grants can differ). Size the setting to the DB node, not just to "bigger is
  better": `shared_buffers` is only ~391 MB on the current node, so 1 GB is already asking for more
  than half the node's shared buffer allocation just for one maintenance operation — do not go higher
  without checking the node's actual RAM first. `max_parallel_maintenance_workers` is 2, and pgvector
  0.7.4 (prod's version — the bench DB runs 0.8.2 locally, a version mismatch to keep in mind when
  rehearsing) supports parallel HNSW builds, so the by-hand build can use both. The existing 1536-d
  indexes are 2,184 MB (`ink_embeddings`) and 1,336 MB (`pen_embeddings`) over 796,559 and 210,232
  vectors respectively — at 1024 dims (roughly 2/3 the byte width per vector) expect proportionally
  smaller new indexes, roughly ~1.5 GB (ink) and ~0.9 GB (pen), as a sizing sanity check while
  watching the build rather than a number to assert on. Rehearse the actual build duration on the
  bench DB — which under Q6 is refreshed only before major rounds (#1 at S22, #2 at S30) and therefore
  will NOT have a populated `embedding_v2` column when this step runs, so add it locally
  (`ALTER TABLE ink_embeddings ADD COLUMN embedding_v2 vector(1024)`, same for `pen_embeddings`) and
  fill it from the `bench_embeddings` table S23 built for the chosen candidate model — with the
  SAME `maintenance_work_mem` setting planned for prod — `EXPLAIN` proves nothing about build
  duration, only a timed rehearsal does — purely so the person running the detached prod build knows
  roughly how long to expect it to take (there is no release-command timeout to protect against here,
  since the migration itself only does `if_not_exists` work once the by-hand build has finished; the
  rehearsal exists for operational confidence, not to gate a go/no-go the way it would if the "let the
  release command build it" alternative had been chosen). If a `CONCURRENTLY` build fails partway
  (e.g. the detached session is killed, or a deploy runs concurrently and touches the same table), it
  leaves an INVALID index behind: `DROP INDEX CONCURRENTLY <name>;` that invalid leftover before
  retrying the `CREATE INDEX CONCURRENTLY` — do not let the later migration's `if_not_exists: true`
  paper over an invalid index, since `if_not_exists` only checks for existence-by-name, not validity,
  and an invalid index silently never gets used by the query planner.

- **Depends on.** S24-embedding-v2-backfill (must report zero remaining `NULL` rows on both tables
  before the index build starts — an HNSW index built while rows are still trickling in from the
  backfill is not wrong, but building it once, after the backfill is complete, avoids re-indexing
  churn and keeps the "how long will this take" rehearsal number honest).
- **Why here.** Strictly between the backfill and the read flip (S27); this step is isolated as its
  own PR/step specifically because it is the one operation in the whole embeddings migration whose
  TIMING on prod matters enough to require a human at a detached session watching it, rather than
  something a deploy's release command can safely run unattended.
- **Does not include.** Any change to `embeddings.read` (S27 flips that, only after both indexes here
  report valid). Dropping the OLD 1536-d indexes (S35, after dual-write is off and a watch week has
  passed).
- **Definition of done.**
  - Both new indexes report `pg_index.indisvalid = true` for `index_ink_embeddings_on_embedding_v2`
    and `index_pen_embeddings_on_embedding_v2` (query the read-only URL).
  - `structure.sql` regenerated inside the app container (matches the shape of the existing entries
    at db/structure.sql:1908-1911 and :2062-2065, with `_v2` appended to both the index name and the
    indexed column).
  - `EXPLAIN` on prod (read-only URL) against a sample nearest-neighbor query on `embedding_v2` shows
    `Index Scan using index_ink_embeddings_on_embedding_v2` (or the pen equivalent) — NOT a sequential
    scan — proving the planner actually picks the new index up once it exists (pgvector's `neighbor`
    gem emits `ORDER BY <col> <=> $1 LIMIT n`, which is what the planner needs to see to choose an
    HNSW index scan).
  - The by-hand build is done at a genuinely quiet hour (check recent traffic graphs / deploy
    history before picking the time) and the person running it stays with the detached session (or
    checks back on it) until both `CREATE INDEX CONCURRENTLY` statements report done, not just
    "started".
- **Implementation notes.**
  - Manual path, one detached session, run both statements back to back:
    ```sql
    SET maintenance_work_mem = '1GB';
    SET statement_timeout = 0;
    CREATE INDEX CONCURRENTLY index_ink_embeddings_on_embedding_v2
      ON ink_embeddings USING hnsw (embedding_v2 vector_cosine_ops);
    CREATE INDEX CONCURRENTLY index_pen_embeddings_on_embedding_v2
      ON pen_embeddings USING hnsw (embedding_v2 vector_cosine_ops);
    ```
    `fly console` is an ephemeral machine reached over SSH that runs `bin/rails console`
    (`fly.toml:8`); the prod image installs no `psql` client (`Dockerfile:118-120`), so there is no
    plain-SQL `fly console` shortcut here; a
    multi-hour statement running inside that interactive session is lost the instant the SSH
    connection drops. Instead run it DETACHED: `fly machine run <image> bin/rails runner <script.rb>`
    (a script that opens an `ActiveRecord::Base.connection.execute(...)` for each statement — outside
    any `ActiveRecord::Base.transaction` block, since `CREATE INDEX CONCURRENTLY` is rejected inside a
    transaction), or start a `tmux` session directly on a running machine and run `bin/rails runner`
    or a `psql`-equivalent from inside it so the session survives an SSH drop. Poll progress from a
    SEPARATE connection (the read-only URL is enough) with:
    ```sql
    SELECT indisvalid FROM pg_index
    WHERE indexrelid = 'index_ink_embeddings_on_embedding_v2'::regclass;
    ```
    (and the pen equivalent) — `false` or "relation does not exist" means still building or not yet
    started; `true` means done and valid.
  - Verification queries (read-only URL), run after both builds report `indisvalid = true`:
    ```sql
    SELECT indexrelid::regclass, pg_size_pretty(pg_relation_size(indexrelid)), indisvalid
    FROM pg_index
    WHERE indrelid IN ('ink_embeddings'::regclass, 'pen_embeddings'::regclass);
    ```
    and
    ```sql
    EXPLAIN SELECT id FROM ink_embeddings
    WHERE owner_type = 'MacroCluster'
    ORDER BY embedding_v2 <=> (SELECT embedding_v2 FROM ink_embeddings WHERE embedding_v2 IS NOT NULL LIMIT 1)
    LIMIT 200;
    ```
    which must show `Index Scan using index_ink_embeddings_on_embedding_v2` in its plan.
  - The bench DB is pgvector 0.8.2 (vs prod's 0.7.4), so treat any rehearsed duration as an
    order-of-magnitude estimate only. It has no `embedding_v2` column of its own at this point in the
    roadmap (Q6: refreshes happen only at S22 and S30), which is why the Goal says to add and fill the
    column there by hand from `bench_embeddings` before timing anything — an empty or absent column
    makes the rehearsal meaningless.
  - Raw SQL (as above) is the only way to set non-default `m`/`ef_construction` — not needed here,
    since the decision is explicitly default parameters, but keep this in mind if a future index
    tuning pass ever wants to deviate; that would still be raw SQL first, then a recording migration
    the same way this step does it.

- **Decisions applied.** Q30 (build by hand at a quiet hour from a detached session — not an
  interactive `fly console`, not letting the release command build it — with
  `SET maintenance_work_mem = '1GB'` and DEFAULT index parameters, then merge a migration that
  RECORDS the by-hand build with `if_not_exists: true` + `algorithm: :concurrently` +
  `disable_ddl_transaction!`), Q31 (the column being indexed is `embedding_v2`, permanently — there is
  no future rename step for this index to anticipate).

### S27-embedding-read-flip — Flip `read` to the new column/model with recalibrated cutoffs; drip paused for the flip day; watch for a week

- **Goal.** One config change: in `config/llm.yml`'s `embeddings:` block (S18/S24), set
  `embeddings.read: current` under `production:` and `development:` — **never** under `test:`, which
  stays `read: legacy` so the existing 1536-dim WebMock stubs
  (`spec/workers/fetch_embedding_spec.rb`, the `macro_cluster_spec.rb`/`pens/model_spec.rb` doubles)
  keep passing unchanged; this is an **implementer default**, since neither S18 nor S24's text pins the
  environment split explicitly, but it is the only choice consistent with "the test suite is not
  touched by this migration" (S04's own decided design for the chat config, applied here by analogy).
  In the SAME PR, write S23's picked per-table CUTOFFS, plus the carried-over `ef_search` values
  (200 ink / 1000 pen) unless S26's `EXPLAIN` showed otherwise, into whatever
  per-table sub-key shape S18 actually built under the `current` entry (S18's text leaves the exact
  key path — `cutoff:`/`ef_search:` sub-keys per entry, vs. named Ruby constants made
  config-driven — to its own implementer; read S18's merged code, don't guess the shape here) so the
  `current` entry carries ink and pen cutoffs calibrated for the new 1024-dim model rather than
  copies of the old `0.6`, with `ef_search` carried over deliberately rather than by oversight (S23
  has no index and therefore cannot pick one).

  This single config change is what flips **both** `embedding_search` methods
  (`MacroCluster.embedding_search`, app/models/macro_cluster.rb:105-109 for the `SET hnsw.ef_search`
  and query-embedding lines; `Pens::Model.embedding_search`, app/models/pens/model.rb:30-34 for the
  same), the public `PenModelsController#index` (app/controllers/pen_models_controller.rb:4, which
  calls `Pens::Model.embedding_search` under the hood — no code change needed there, it already goes
  through the model method), every pen/ink tool built in S10/earlier, AND the model used to embed the
  incoming search query itself — all four derive column and query-embedding model from `read` (S24's
  design). Flipping the COLUMN without the QUERY MODEL would make `nearest_neighbors` raise on every
  search (`neighbor` validates the query vector's dimension against the target column: a 1536-dim
  query vector against `embedding_v2 vector(1024)` raises immediately); flipping the MODEL without the
  COLUMN would silently compare vectors from two different embedding spaces and return garbage with no
  error — this is exactly why `read` is a single scalar that names one `embeddings:` entry supplying
  both, not two independent switches, and why S24's config validation raises at boot if `read` names a
  non-existent entry.

  `FetchEmbedding` (app/workers/fetch_embedding.rb, rewritten by S24) is **not touched by this step**:
  it keeps dual-writing both columns regardless of what `read` points at (dual-write is a separate
  scalar, `embeddings.dual_write`, already `true` since S24's post-merge runbook step 2) — this PR
  changes only which column and model are _read_, never which are written. Dual-write staying on is
  what makes this flip reversible: `git revert` this PR and both columns are still being kept in sync,
  so a flip-back loses nothing.

  **Watch signals for the week after the flip** (no dashboard exists for any of these; run them as
  ad-hoc queries against `PRODUCTION_READONLY_DATABASE_URL` or `fly ssh console`):
  - `InkClusterer`-vs-checker disagreement rate — the fastest signal, since the ink backlog is
    currently empty (0 unassigned `MicroCluster` rows with inks) and human verdicts on the checkers'
    663 pending decisions only trickle in on weeks the owner reviews. Query:
    `extra_data->>'follow_up_action'` (a reject action) vs. total, grouped by day, on `InkClusterer`
    logs created after the flip.
  - Human verdicts on the 663 checker decisions awaiting confirmation as they arrive (`agent_logs`
    `name='InkClusterer'`, `state IN ('approved','rejected')`, `agent_approved = true`,
    `owner_type='MicroCluster'`, owner has `collected_inks` — 663 verified on 2026-09-12; re-count
    before relying on the exact figure).
  - The pen drip's per-action approval rate (`PenVariantClusterer` logs, excluding S13's
    `extra_data.auto_rejection = "orphaned"`/`"empty_cluster"`-tagged rows) — watch for a step change
    around the flip boundary, not just the trend.
  - Spot checks of the public pen search (`GET /pen_models?q=<known model>`) and of `ReviewFinder`'s
    output — it uses `Tools::InkSimilaritySearchTool` (review_finder.rb:123), and
    `FetchReviews::ProcessWebPageForReview` caps its own concurrency specifically because of
    `embedding_search`'s cost (`sidekiq_throttle concurrency: { limit: 1 }, threshold: { limit: 1,
period: 30 }`, app/workers/fetch_reviews/process_web_page_for_review.rb:6-10) — a latency
    regression here would show up as `reviews`-queue backlog before anything else does.
  - Honeybadger — S05's model-not-found alert and S18's embeddings-side copy of it should stay silent
    through this flip, but NOT because the model is unchanged: this flip does change the
    query-embedding model (all four read paths derive column AND query-embedding model from `read`).
    They stay silent because the DO embedding model named by `embeddings.current` has already been
    exercised by S23's bench and S24's backfill. Any model-not-found here means the `current` entry
    itself is misconfigured.

- **Depends on.** S26-hnsw-index-v2 (both `embedding_v2` HNSW indexes must report `indisvalid = true`
  on the read-only URL before this flip — an `Index Scan` plan is what makes the flip safe to run at
  all; flipping `read` before the index exists would work correctly but every search would run a
  sequential scan over the full column, which on `ink_embeddings`' ~797k rows is slow enough to be its
  own incident).
- **Why here.** After this point every later chat bench round (S28-S30 on) sees the final retrieval
  layer the plan requires — a chat-model pick made against the OLD embeddings would be invalidated the
  moment the embedding model changes underneath it, which is why the whole embeddings half of the
  migration (S23-S27) runs before the second, DO-candidate chat bench round (S30).
- **Does not include.** Dropping the old `embedding` column or its indexes (S35-drop-old-embedding-column,
  after a full watch week here plus a chat round on the new embeddings); turning dual-write off
  (S34-embedding-dual-write-off, same gate).
- **Definition of done.**
  - In `fly console` (`bin/rails console` against prod), with SQL logging on (or `.to_sql` on the
    tier-1 relation before calling `.first`), `MacroCluster.embedding_search("<a known ink name>")`
    and `Pens::Model.embedding_search("<a known pen model>")` both reference `embedding_v2` in the
    generated SQL, not `embedding`.
  - A public `GET /pen_models?q=<known model>` request (from a browser or `curl`) returns results —
    proves `PenModelsController#index` works end-to-end through the flipped path, not just in a
    console.
  - The first `InkClusterer` log created after the flip has a plausible `ink_similarity_search` tool
    result in its transcript (spot-check by hand — this is not a scripted assertion, it's a sanity
    read of one real transcript).
  - Runbook entry recorded (in docs/llm-migration-plan.md, next to S04's rollback note): "flip back =
    one config edit (`embeddings.read: legacy`) + deploy, valid ONLY while `dual_write` is still true
    AND both the old 1536-dim and new 1024-dim HNSW index pairs still exist — i.e. any time before
    S35-drop-old-embedding-column merges. After S35, there is no flip-back; a regression found after
    that point requires re-adding the old column and re-backfilling it, not a revert."
  - Drip pause recorded in the pen plan and this roadmap: the exact day `PEN_CLUSTERING_QUEUE_DEPTH`
    was set to `0` and back to `10`, and the drip's per-action stats annotated with that boundary date
    so a before/after split is possible later (Q29).
  - The before/after cutoff and `ef_search` values for `MacroCluster` and `Pens::Model`, side by side,
    written into the PR description (not just the config diff — a reviewer should be able to read the
    old-vs-new numbers without cross-referencing S23's separate write-up).
  - Weekly watch numbers (the five signals above) recorded in the migration plan for each of the 7
    days after the flip.
- **Rollback.** `git revert` the config-edit PR and redeploy — valid exactly as long as the runbook
  entry above says (dual-write on, both index pairs present). No data is lost by a flip-back: dual-write
  never stopped, so the old column is still current.
- **Decisions applied.**
  - **Q29** — on the flip day: `flyctl secrets set PEN_CLUSTERING_QUEUE_DEPTH=0 -a
fountainpencompanion` (or stage it alongside the deploy) BEFORE merging the `read: current` PR, so
    no new pen decision is made on a half-flipped retrieval layer; merge the PR; the next day, set
    `PEN_CLUSTERING_QUEUE_DEPTH` back to `10` and run one manual `TopUpPenClusteringQueue.perform_async`
    from the console to refill the paused queue immediately rather than waiting for the next human
    approve/reject in the admin review page to trigger one — nothing schedules the top-up (S13 leaves
    it out of `sidekiq_schedule.yml` deliberately); record the exact boundary timestamp next to the drip's per-action statistics so a
    before/after comparison is possible. The ink side is NOT paused (InkClusterer has no
    equivalent queue-depth knob; its backlog is already empty, so there is nothing to pause).
  - **Q1** — the flip is a `config/llm.yml` PR like every other flip in this migration (S04's runbook
    mechanism), never a `flyctl secrets set` for a value; rollback is `git revert`, subject to the
    dual-write/index-pair window above.
- **Implementation notes.**
  - Watch-week queries, spelled out:
    - Checker disagreement:
      `SELECT date_trunc('day', created_at), count(*), count(*) FILTER (WHERE extra_data->>'follow_up_action' IN ('reject')) FROM agent_logs WHERE name = 'InkClusterer' AND created_at > '<flip timestamp>' GROUP BY 1 ORDER BY 1;`
    - Pending checker confirmations (663 on 2026-09-12; re-run before use):
      `SELECT count(*) FROM agent_logs WHERE name = 'InkClusterer' AND state IN ('approved','rejected') AND agent_approved = true AND owner_type = 'MicroCluster' AND EXISTS (SELECT 1 FROM collected_inks WHERE collected_inks.micro_cluster_id = agent_logs.owner_id);`
    - Pen drip approval per action, excluding CleanUp/empty-cluster auto-rejections:
      `SELECT extra_data->>'action', state, count(*) FROM agent_logs WHERE name = 'PenVariantClusterer' AND (extra_data->>'auto_rejection') IS NULL GROUP BY 1, 2;`
  - Do not touch `FetchEmbedding`, `BackfillEmbeddings`, or the `dual_write` scalar in this PR — this
    step is a pure read-side flip, and every write-side behavior (S24) is already live and unaffected.
  - If S18's cutoff/`ef_search` values ended up as named Ruby constants (`MacroCluster::SIMILARITY_CUTOFF`,
    `Pens::Model::SIMILARITY_CUTOFF`, and the two `HNSW_EF_SEARCH` constants, S09) made config-driven
    rather than moved wholesale into YAML, this step's "config change" may include a small code diff
    reading those constants from the resolved `embeddings.read` entry instead of a pure YAML edit —
    either way, the change is still one reviewable diff and the DoD's before/after values still apply;
    read S18's actual merged code before writing this PR to know which shape exists.

### S28-harness-checkers-review-export — Checker `decide` + bench, ReviewApprover cases (latest run, human-confirmed, consistent), export mode and rubrics for unlabelled agents

- **Goal.** Three independent pieces, splittable into three PRs (see Definition of done). All three
  reuse S20's runner/report/pricing code (`lib/bench/`, `Bench.isolate!`, `LlmConfig.with_override`,
  the per-case rolled-back transaction, the Wilson-interval reporting) unchanged — this step only adds
  exporters and one new agent-side method, never a second harness.

  **1. Checker `decide` + checker bench.** `CheckInkClustering::Base` (app/agents/check_ink_clustering/base.rb)
  needs a side-effect-free entry point exactly like S11's pen agent and S19's `InkClusterer` already
  have. Add:

  ```ruby
  def decide(parent_agent_log)
    self.micro_cluster_agent_log = parent_agent_log
    ask!(prompt)
    agent_log.reload.extra_data
  end

  private

  def prompt
    [clustering_explanation, micro_cluster_data, extra_context].compact.join("\n\n")
  end
  ```

  (`clustering_explanation` :78-81, `micro_cluster_data` :120-128, `extra_context` :74-76 — a no-op
  hook overridden only by `CheckInkClustering::Assign` to add `macro_cluster_data`, assign.rb:78-88 —
  are today assembled inline inside `perform`; extract them into the shared private `prompt` method
  above and have `perform` call it too, so there is exactly one place that builds the prompt.)
  `perform` becomes:

  ```ruby
  def perform
    return unless micro_cluster_agent_log

    if micro_cluster.collected_inks.present?
      decide(micro_cluster_agent_log)
      agent_log.waiting_for_approval!
      update_micro_cluster_agent_log!
      execute_decision!
    else
      reject_empty_micro_cluster!
    end
  end
  ```

  `decide` makes NO state transition and calls neither `waiting_for_approval!` nor
  `update_micro_cluster_agent_log!` (base.rb:83-94) nor `execute_decision!` (base.rb:96-110, which has
  REAL side effects: `InkClusterer.new(...).approve!(agent: true)` /
  `.reject!(agent: true)`, `RunInkClustererAgent.perform_async`, and `CheckInkClustering::Human` sends
  mail via `AdminMailer.agent_mail(...).deliver_later`, human.rb:9) — the bench must never reach
  `execute_decision!` for any checker case; calling `decide` alone is what guarantees that.
  `CheckInkClustering::Human` (human.rb) needs the identical extraction (its own `perform`, human.rb:42-53,
  duplicates the same shape without `update_micro_cluster_agent_log!`/`execute_decision!` — add the
  same `decide(parent_agent_log)` there too, calling `ask` not `ask!` — simply because that is what
  `Human#perform` does today (human.rb:47); `SendEmail` does halt (human.rb:10), so the loop still
  terminates. `Human#decide` must ALSO not call `micro_cluster_agent_log.approve!` (human.rb:49) —
  that line, which approves the PARENT InkClusterer log and is the one real state transition in
  Human's `perform`, stays in `perform`, after `decide` returns. `SendEmail#execute` calling
  `AdminMailer.agent_mail(...).deliver_later`
  DOES have a side effect even inside `decide` — accept this for Human specifically, since checker
  cases only reach a checker subclass when the FRESH leave-one-out run decided
  `assign_to_cluster`/`create_new_cluster`/`ignore_ink` per the mapping below; a bench case never
  actually instantiates
  `CheckInkClustering::Human`, so this caveat is dead code in practice but must not raise if triggered
  by mistake).

  Harness code (new file `lib/bench/checker_cases.rb`, required from `lib/tasks/bench.rake`):
  - **Exporter** `bench:export[CheckInkClustering]`: reads the SAME exported `InkClusterer` case set
    S20 already wrote to `bench/data/`. It needs three fields from that JSON, all present in S20's
    fixed case shape: `original_action`, `expected_action` (the `assign`/`create`/`ignore` label) and
    `expected_target_id` for assign cases. Do not re-derive a separate case list — a checker case is
    defined ONLY in terms of an `InkClusterer` case that already exists — and do NOT filter by the
    case's ORIGINAL action, nor record a subclass here. A checker case exists for EVERY exported
    `InkClusterer` case; the subclass is chosen at RUN time from the fresh leave-one-out log's own
    action (runner step 2), because the migration plan benches the checker on "run InkClusterer
    leave-one-out, feed the result to the checker", not on the historical verdict. A case is skipped —
    counted under "no checker case" — only when the FRESH run ends in `hand_over_to_human` (which
    yields no accept/reject verdict to score: `CheckInkClustering::Human` only emails,
    human.rb:45-49) or raises `RubyLlmAgent::DecisionNotReachedError`. The run-time mapping is the
    exact one `InkClusterer#schedule_follow_up!` uses today (ink_clusterer.rb:207-218):
    `assign_to_cluster -> CheckInkClustering::Assign`, `create_new_cluster -> CheckInkClustering::Create`,
    `ignore_ink -> CheckInkClustering::Ignore`.
  - **Dev/test split.** The checker case set and the `ReviewApprover` case set below are written with
    the SAME dev/test split S20 applies to the ink cases (migration P1: "Dev/test split of cases so
    later prompt tuning does not overfit"), so the post-migration prompt-tuning follow-up cannot
    overfit on them either.
  - **Runner** `bench:run[CheckInkClustering,<model>]`, inside the SAME per-case rolled-back
    transaction S20's ink runner already opens (this is a second pass over the runner, not a second
    transaction — checker cases are derived from the ink case the transaction is already set up for):
    1. Call `InkClusterer.new(micro_cluster.id, agent_log_id: fresh_bench_log.id).decide(agent_log:
fresh_bench_log)` exactly as S20 already does, producing the fresh bench log's `extra_data`
       (`action`, `cluster_id` if assign, `explanation_of_decision`) and transcript — this fresh log IS
       the "parent AgentLog" the checker bench builder persists; no separate persistence step is
       needed beyond what S20 already writes inside the transaction.
    2. Pick the checker subclass from the mapping above, using the FRESH log's own decided action (not
       the historical label) — this bench mode measures "does the checker agree with what THIS
       candidate ink model just decided," which may differ from the original historical action when
       benching a different ink candidate model.
    3. `checker = klass.new(fresh_bench_log.id)` then `checker_verdict = checker.decide(fresh_bench_log)`
       with the candidate injected through
       `LlmConfig.with_override("CheckInkClustering" => cfg, "GoogleSearchSummarizer" => cfg)` where
       `cfg = { model:, provider:, api_base:, api_key_env: }` — the summarizer MUST be named too
       (Q14), because `Tools::InkWebSearchTool#execute` instantiates `GoogleSearchSummarizer`
       (ink_web_search_tool.rb:17) and the tool is in `base_tools` (check_ink_clustering/base.rb:65-72),
       so without it a DO candidate would be benched with OpenAI-written search summaries. All four
       `CheckInkClustering::*` subclasses
       resolve to the ONE shared `"CheckInkClustering"` config key (S04), so overriding that one key
       overrides every subclass at once; this is also why the checker bench cannot independently pick
       a different candidate per subclass — Assign/Create/Ignore/Human always share one model.
    4. Expected verdict, computed from the INK log, not from the checker's own: read
       `ink_action = fresh_bench_log.reload.extra_data["action"]`, map it with the same table as step 2
       (`assign_to_cluster -> assign`, `create_new_cluster -> create`, `ignore_ink -> ignore`), then
       `expected = (mapped == label.action && (label.action != "assign" || fresh_bench_log.extra_data["cluster_id"] == label.expected_target_id)) ? "approve" : "reject"`.
       Score `expected == checker_verdict["action"]`. The two vocabularies are different and must not
       be compared directly: `CheckInkClustering::Base` stores only `"approve"`/`"reject"` in its own
       `extra_data["action"]` (base.rb:6-7, :112-118), the ink log stores
       `assign_to_cluster`/`create_new_cluster`/`ignore_ink` (ink_clusterer.rb:32-98, mapping at
       :207-218), and S20's exported `label.action` is `assign`/`create`/`ignore`.
       If the fresh ink run ends in `hand_over_to_human` or raises
       `RubyLlmAgent::DecisionNotReachedError`, skip the case and report it in a separate "no checker
       case" count.
    5. Roll back with the same enclosing transaction S20's runner already rolls back — no extra
       teardown needed since the checker's own log, like the ink fresh bench log, is created inside
       that same transaction.
  - Checker tools include `Tools::InkWebSearchTool.new(agent_log)` (base.rb:65-72, inside
    `base_tools`; the `InkWebSearchTool` line is :70), so S20's Serper/`GoogleSearchSummarizer`-summary record/replay cache applies here
    too with no new caching code — reuse it, keyed the same way (exact query string, `(query,
summarizer_model)` for the cached summary).
  - **Historical confusion matrix** (reported for free, no bench run needed, next to the leave-one-out
    checker bench — this is a real-prod-data query, not a bench-DB query): the checker's OWN verdict is
    stored back onto the PARENT `InkClusterer` log's `extra_data->>'follow_up_action'`
    (`update_micro_cluster_agent_log!`, base.rb:83-94) rather than being a first-class label anywhere
    else, so crossing it with the human's eventual verdict on that same parent log gives a real,
    strong label set — NOT the "weak labels" the migration plan's text describes. Query (verified on
    prod, 2026-09-12: 10,955 labelled decisions, 89.1% agreement, 859 "checker approved, human
    rejected" hard negatives):
    ```sql
    SELECT
      count(*) AS total,
      count(*) FILTER (
        WHERE (extra_data->>'follow_up_action' = 'approve' AND state = 'approved')
           OR (extra_data->>'follow_up_action' = 'reject'  AND state = 'rejected')
      ) AS agreement,
      count(*) FILTER (
        WHERE extra_data->>'follow_up_action' = 'approve' AND state = 'rejected'
      ) AS hard_negatives
    FROM agent_logs
    WHERE name = 'InkClusterer'
      AND agent_approved = false
      AND state IN ('approved', 'rejected')
      AND extra_data->>'follow_up_action' IS NOT NULL;
    ```
    Print this alongside the leave-one-out bench numbers in `bench:report`'s output for
    `CheckInkClustering`, clearly labelled as "historical, all checker models to date" so it is never
    confused with the leave-one-out figures for one specific candidate model.

  **2. ReviewApprover case exporter + runner** (new file `lib/bench/review_approver_cases.rb`).
  `ReviewApprover`'s labels live on `ink_reviews`, never on `agent_logs.state` (every
  `ReviewApprover` log sits at `waiting-for-approval` forever — `perform`, review_approver.rb:124-129,
  never transitions its own state; only the reviewed `InkReview` row's `approved_at`/`rejected_at`
  change).
  - **Exporter** `bench:export[ReviewApprover]`: `InkReview.manually_processed` (scope at
    ink_review.rb:23: `processed.where(agent_approved: false, auto_approved: false)` — a human
    explicitly decided, not the agent and not the periodic re-check), joined to the LATEST
    `ReviewApprover` log per review (`ink_review.agent_logs.where(name: "ReviewApprover").order(:created_at).last`
    — 10,230 total logs cover only 6,163-6,164 distinct reviews because 5,247 are duplicate re-runs
    from 2025-05-01/02, 688 reviews re-run 4x and 499 re-run 5x). Verified on prod, 2026-09-12: 5,817
    distinct reviews with a `ReviewApprover` log AND a human-confirmed verdict. That 5,817 IS the
    post-drop figure Q11's "~5,800-6,000 cases" names — the ~491 reviews whose `ReviewApprover` logs
    disagree with each other across re-runs are a subset of the 1,187 multi-log reviews (688 x 4 plus
    499 x 5) and were already excluded when 5,817 was measured. Re-derive the exact number at export
    time with the consistency rule stated explicitly — a review is "consistent" only if every one of
    its `ReviewApprover` logs recorded the SAME action — and record the final count in the PR; if it
    lands outside Q11's ~5,800-6,000 range, say so and why rather than silently shipping a different
    population. Label = the human's own final verdict
    (`approved_at.present?` -> `approve`, `rejected_at.present?` -> `reject`); expected verdict from a
    bench run = does the candidate model's tool call match that label.
  - **Runner** `bench:run[ReviewApprover,<model>]`, inside one rolled-back transaction per case:
    1. Reset the case review to QUEUED before running: `ink_review.update_columns(approved_at: nil,
rejected_at: nil, agent_approved: false, auto_approved: false, extra_data:
ink_review.extra_data.except("action", "explanation_of_decision"))` (use `update_columns` to
       skip callbacks/validations the same way S20's hide step does — there is no `before_save` on
       `InkReview` that would fight this, but skipping validations avoids re-triggering
       `validates :image, presence: true` etc. on a row that already has a value). This is necessary
       for two reasons stated in the v1 plan analysis and worth repeating in code comments: (a) `.live`
       (ink_review.rb:25, `approved.where(check_count: 0)`) feeds `number_of_reviews`
       (`cluster.ink_reviews.live.size`, review_approver.rb `format_cluster_data`) — leaving the case
       APPROVED would make it inflate its own cluster's review count relative to what the model saw at
       decision time; (b) `.manually_processed` (ink_review.rb:23) feeds the few-shot example queries
       (`approved_reviews_data`/`rejected_reviews_data`, both built from
       `InkReview.joins(:ink_review_submissions).order("RANDOM()").manually_processed`) — leaving the
       case processed risks it being sampled as its OWN few-shot example, handing the model the
       answer.
    2. `SELECT setseed(<a number derived deterministically from the case, e.g. review.id>)` on the
       SAME connection, immediately before calling `perform`, so `ORDER BY RANDOM()` in
       `approved_reviews_data`/`rejected_reviews_data` picks the identical five-per-bucket examples for
       EVERY model run against this case — otherwise a baseline-vs-candidate comparison would be
       comparing different few-shot contexts, not just different models. `setseed` takes a float in
       [-1, 1]; derive one deterministically, e.g. `(review.id % 1000) / 1000.0 * 2 - 1`.
    3. Call `ReviewApprover.new(review.id).perform` with the candidate injected via
       `LlmConfig.with_override("ReviewApprover" => cfg, "YoutubeSummarizer" => cfg, "WebPageSummarizer" => cfg)`
       — the two summarizers must be named too (Q14), because `ReviewApprover::Summarize#execute`
       instantiates them (review_approver.rb:64-73); benching a DO candidate whose summaries still come
       from OpenAI measures the wrong thing. Assert in a spec that the summarizer request goes to the
       candidate's `api_base`. The same applies in export mode below to `ReviewFinder`, whose own
       `Summarize` plus `Tools::InkSimilaritySearchTool` must be covered by one override naming every
       class involved.
       No `decide`-style refactor is needed for this agent — `perform` (review_approver.rb:124-129:
       `ensure_youtube_metadata! -> ask!(user_prompt, with: resolved_image_url) ->
agent_log.update!(extra_data: ink_review.extra_data) -> agent_log.waiting_for_approval!`) has
       no Sidekiq enqueue, and the only lock it takes is the `with_lock` inside
       `ink_review.ensure_youtube_metadata!` (ink_review.rb:131, called at review_approver.rb:125),
       which opens its own savepoint and is safe inside the surrounding bench transaction.
       `ApproveReview`/`RejectReview` just call `ink_review.update` plus
       `agent_approve!`/`agent_reject!` (review_approver.rb:16-26 and :41-51; ink_review.rb:72-90) —
       plain updates, all rolled back with the case.
    4. Read `ink_review.reload.extra_data["action"]` — `"approve_review"` or `"reject_review"` — as the
       candidate's verdict; compare to the case's human label.
    5. Roll back. A caveat worth documenting in the harness code and the PR: sibling reviews of the
       SAME macro cluster that were approved by a HUMAN after this decision was originally made (but
       before the bench case set was exported) still raise `number_of_reviews` relative to what the
       real historical decision saw — this is an accepted, documented imprecision, not something the
       harness works around.
  - **Vision.** `resolved_image_url` (review_approver.rb:151-153, `ResolveImageUrl.new(ink_review.image).perform`)
    means EVERY ReviewApprover case attaches an image (0 of the 5,817 case reviews have a blank
    `image` on prod), so every candidate model benched for this agent MUST be vision-capable (Q15) —
    the candidate list for `ReviewApprover` (and, in export mode below, `ReviewFinder`) is filtered to
    vision-capable DO models only; there is no prompt change to drop the thumbnail.
  - **Record/replay caches**, keyed and scoped exactly as follows (three independent caches, each keyed
    on something case-stable so re-running the SAME case set against a second candidate model reuses
    them instead of re-hitting the network):
    - `ResolveImageUrl.new(url).perform`'s HEAD request (app/operations/resolve_image_url.rb:9) — key
      on the exact `url` string; cache the resolved (possibly redirected/rewritten) URL or `nil`.
    - `Unfurler::Youtube::Comments`/`Captions` fetched inside `ensure_youtube_metadata!`
      (ink_review.rb:124-139) — key on the review's `you_tube_channel_id`/video id; 3,932 of the 4,539
      YouTube case reviews have `youtube_metadata_fetched_at IS NULL` on prod today (the historical
      human decisions on those reviews were made WITHOUT tags/comments/captions in the prompt at the
      time — a fact worth noting in the PR, since a re-run with the harness's cache now populated may
      shift a candidate's verdict on those specific cases relative to the historical human call,
      through no fault of the candidate model). Cache these once per review id so the ~100-case
      run (200 for the finalist only, Q16) doesn't re-hit YouTube for every candidate model.
    - `Unfurler.new(url).perform` for non-YouTube web pages — key on `url`.
      Serper is NOT involved in `ReviewApprover` at all (no web-search tool on this agent) — do not build
      a cache for it here; that cache is S20's, for `InkClusterer`/the checkers, and is reused as-is
      (see above).

  **3. Export mode + rubric files** for agents that have NO ground-truth label at all (their whole
  output is generative text/action, not a binary verdict): `GoogleSearchSummarizer` (7,511 prod logs),
  `YoutubeSummarizer` (2,694), `WebPageSummarizer` (1,947), `ReviewFinder` (13,889), `PenAndInkSuggester`
  (12,658), `InkBrandClusterer` (293 logs, 0 approved / 4 rejected — no usable labels at all). New file
  `lib/bench/export.rb`, task `bench:compare[<AgentClass>,<baseline_model>,<candidate_model>]`:
  produces one row per historical log with the BASELINE model's original output next to a fresh
  CANDIDATE-model run on the exact same input, for a human (the owner, in Claude Code, per the
  decision) to grade against a rubric file — no API judge.
  - **Replayable inputs** (verbatim, from the historical log's own transcript or the owner record — no
    re-derivation needed): the three summarizers' first user message is literally reconstructible —
    `GoogleSearchSummarizer#user_prompt` (google_search_summarizer.rb:59-65, needs the ORIGINAL
    `search_term` and `search_results` — cache the Serper call the same way S20's checker cache does,
    keyed on the exact query), `WebPageSummarizer#perform` (web_page_summarizer.rb:18, `ask(raw_html)`
    — needs the raw HTML, cached via `Unfurler`), `YoutubeSummarizer#prompt_text`
    (youtube_summarizer.rb:32-40, needs title/description/tags/comments/captions plus the thumbnail
    URL — cached via the same YouTube metadata cache as the ReviewApprover exporter above, reused, not
    rebuilt). `ReviewFinder` and `PenAndInkSuggester` are NOT verbatim-replayable the same way (their
    prompts assemble live state — candidate ink/pen lists, prior submissions — that has moved on since
    the historical run), so their export mode re-runs against CURRENT app state and compares behavior,
    not a byte-identical replay; document this distinction in the rubric files themselves so a grader
    does not expect determinism from those two.
  - `PenAndInkSuggester` needs the S04 injection to override its own class's config entry — it resolves
    to TWO different entries at runtime (`PenAndInkSuggester` / `PenAndInkSuggester.premium`, via
    `llm_config_key`), so the override must be applied for whichever entry name the specific user
    (patron or not) actually resolves to; export mode also needs a bypass of `can_perform?`'s daily-limit
    check (pen_and_ink_suggester.rb — the method gating `MAX_PER_DAY`/`MAX_PER_DAY_PATRON`) so repeated
    export runs for the same user across several candidate models in one sitting don't get throttled.
  - `ReviewFinder`'s output is not a single value but the `FetchReviews::SubmitReview` jobs it enqueues
    (drained from `Sidekiq::Worker.jobs` under `Bench.isolate!`'s fake mode, review_finder.rb:23) plus
    its `Done` tool's summary (review_finder.rb:30-45) — export mode records both: the list of
    submitted review candidates AND the final summary text, side by side for baseline vs. candidate.
  - `InkBrandClusterer`'s export mode records its `UpdateBrandCluster`/`CreateBrandCluster` writes
    (ink_brand_clusterer.rb `AddToBrandCluster`/`CreateNewBrandCluster` tool classes) — these DO write
    to the database, so wrap each export case in the same per-case rolled-back transaction pattern as
    every other bench case, even though there is no label to score against; the rollback exists here
    purely to make repeated export runs non-destructive to bench-DB state, not to hide ground truth.
  - **Rubric files**: one per exported agent, plain Markdown under `lib/bench/rubrics/` (e.g.
    `lib/bench/rubrics/google_search_summarizer.md`), each stating in plain language what "as good as
    or better than baseline" means for that agent's output — for `ReviewApprover`'s directive rules as
    a hint of what "decisive" looks like when writing the `ReviewFinder`/summarizer rubrics too:
    `number_of_reviews` and `is_youtube_short` are the ordering rules that most affect its own verdict
    (review_approver.rb's `SYSTEM_DIRECTIVE`, the ordered bullet list) — a summarizer rubric should
    likewise call out the specific facts a downstream consumer (a clusterer, `ReviewApprover` itself)
    actually needs extracted, not prose quality in general. The grader is a human (the owner) reading
    `bench:compare`'s output in Claude Code; there is no automated pass/fail here.
  - `SpamClassifier` is explicitly NOT exported (only 83 logs total on prod; the migration plan's own
    P3 note treats it as a cheap tier with spot checks only — do not build export-mode code for it in
    this step).

- **Depends on.** S20-harness-core-ink (the runner/report/pricing/record-replay infrastructure and the
  ink case set every checker case is derived from).
- **Why here.** Completes the harness before the first paid chat-model round (S30-chat-bench-round,
  which needs the checker bench, the ReviewApprover cases, and export mode all ready to grade
  candidates against); this step's work fits inside S27's one-week watch window (no dependency on the
  read flip's OUTCOME, only ordered after it because S27 is what makes S30's retrieval layer final —
  this step itself never calls `embedding_search` in a way that cares which column is live, since the
  checker's `InkWebSearchTool` calls Serper, not pgvector, and `ReviewApprover` never searches
  embeddings at all).
- **Does not include.** Running any candidate against these exporters for real money (S30 does that);
  the L2 pen agent or its case exporter (S29); any change to `InkClusterer`, `ReviewApprover`, or the
  checkers' PROD behavior (every code change here is a new method or a new `lib/bench/` file, never a
  change to `perform`'s existing side-effecting path apart from the mechanical extraction of `prompt`/
  `decide` described above, which is behavior-preserving by construction — `perform` calls `decide`
  then does exactly what it did before).
  **Bench-DB note carried from S27**: by the time this step runs, prod code (and the bench DB, once
  re-synced) reads `embedding_v2` by default. Point this step's OWN bench-process embeddings `read` at
  `legacy` for its smoke runs — the checker bench's `InkWebSearchTool` calls do not touch embeddings at
  all, but the ink case it wraps around still calls `MacroCluster.embedding_search` inside `decide`, so
  the smoke run needs a consistent, already-indexed embedding column to query; S30's own refresh is
  what makes `current` the bench DB's permanent default, so do not attempt that migration here.
- **Definition of done.**
  - Specs for `CheckInkClustering::Base#decide` (and `Human#decide`): no state transition, no
    `execute_decision!` call (assert via a spy or by checking no `InkClusterer#approve!`/`reject!` call
    was made and `RunInkClustererAgent.jobs` is empty after `decide` alone), `agent_log.transcript`/
    `usage` populated. A spec for the checker case builder mapping (assign/create/ignore ->
    the right subclass, hand_over_to_human/DecisionNotReachedError -> no case produced). A spec for the
    historical confusion-matrix SQL against factory-built `agent_logs` rows (four cells: agree-approve,
    agree-reject, checker-approved-human-rejected, checker-rejected-human-approved).
  - Specs for the `ReviewApprover` exporter's label rules (manually_processed + latest-log consistency
    check; a review with two disagreeing logs is excluded), the reset step (both `.live` and
    `.manually_processed` correctly exclude the reset case afterward), the `setseed` determinism (two
    runs of the SAME case, same seed, sample the identical five-per-bucket example ids), and the three
    record/replay caches (HEAD, YouTube metadata, `Unfurler`) each hit exactly once across two
    simulated candidate runs of the same case set.
  - A 10-case export-mode sample for ONE summarizer (e.g. `GoogleSearchSummarizer`) with baseline
    output only (candidate column left empty) is generated and checked by the owner for format and
    rubric fit; OR, if the owner wants the second column filled, one ~$0.10 candidate run against a
    cheap model is acceptable as the DoD's bar — either way this step does not require a full paid
    export run across all five/six agents (that is S30's job, or later, per-agent as needed).
  - Every new `lib/bench/*.rb` file has specs (Codecov project coverage stays green) and passes
    `prettier --check .`.
  - Can be split into three PRs, in this order: (a) checker `decide` + checker bench + historical
    matrix, (b) `ReviewApprover` exporter/runner with the three record/replay caches, (c) export mode +
    rubric files. All three land before S30 starts; none blocks S29 (the L2 agent), which depends only
    on S20.
- **Decisions applied.**
  - **Q11** — `ReviewApprover` cases: latest run per review, human-confirmed verdicts only
    (`manually_processed`), reviews whose logs disagree across re-runs dropped entirely. 5,817
    human-confirmed reviews verified on prod 2026-09-12, which is the post-drop figure inside Q11's
    stated ~5,800-6,000 range; re-derive it at export time and record the exact count.
  - **Q14** — the checker bench and `ReviewApprover`'s export-mode/bench sub-agents
    (`GoogleSearchSummarizer` inside `Tools::InkWebSearchTool`; `YoutubeSummarizer`/`WebPageSummarizer`
    inside `Summarize`) run on the SAME candidate model as the agent under test, via the per-class
    `LlmConfig.with_override` naming both the checker/agent class and the relevant summarizer class(es)
    together for the duration of one `decide`/`perform` call — the exact mechanism S25's shadow code
    also uses, applied here to the bench instead.
  - **Q15** — `ReviewApprover` (and `ReviewFinder` in export mode) keep the thumbnail; their candidate
    lists are filtered to vision-capable DO models only; no prompt change to drop the image is made
    anywhere in this step.
- **Implementation notes.**
  - Files to create: `lib/bench/checker_cases.rb`, `lib/bench/review_approver_cases.rb`,
    `lib/bench/export.rb`, `lib/bench/rubrics/*.md` (one per exported agent), specs under
    `spec/lib/bench/`. Files to modify: `app/agents/check_ink_clustering/base.rb` (extract `prompt`,
    add `decide`), `app/agents/check_ink_clustering/human.rb` (add its own `decide`), `lib/tasks/bench.rake`
    (new task entries requiring the three new files).
  - `agent_logs.state` carries NO verdict for `ReviewApprover` (every log sits `waiting-for-approval`
    permanently) — do not attempt to query `state` for this agent's labels anywhere in the exporter;
    the label is always on `ink_reviews`.
  - `InkReview.manually_processed` and `.live` (ink_review.rb:22-25) are the two scopes whose
    interaction with the reset step matters; re-read them before writing the reset code if anything
    here is unclear, since getting this wrong silently leaks the answer into the model's own context.
  - `Pens::Model.search`/embeddings are irrelevant to this entire step — nothing here is pen-side; the
    L2 pen agent's own exporter is S29, built on S20/S21's pen-specific code, not this step's.
  - Rollback if something here proves wrong after merge: every change is either a new `lib/bench/` file
    (revert trivially, zero prod callers) or the `prompt`/`decide` extraction on
    `CheckInkClustering::Base`/`Human` (behavior-preserving refactor — `perform`'s observable behavior
    is unchanged, so a revert here is also low-risk; verify with the FULL existing
    `spec/agents/check_ink_clustering/*_spec.rb` suite staying green, unmodified in its assertions,
    after the extraction).

### S29-pen-model-clusterer-agent — PenModelClusterer (L2) agent on the S01 DO model, tools with the create-tool duplicate check, `decide`, L2 case exporter; inert

- **Goal.** `app/agents/pen_model_clusterer.rb`, a new class `PenModelClusterer` including
  `RubyLlmAgent`, over owner `Pens::ModelMicroCluster` (L2's unit of work, exactly as
  `PenVariantClusterer`/S11 is over `Pens::MicroCluster` for L1 — "same shape",
  docs/pen-clustering-plan.md:164). Structured identically to S11: `perform = guards ->
decide(agent_log:) -> waiting_for_approval!`, with a side-effect-free `decide` entry point the L2
  case exporter (below) and any future shadow/bench work call directly. This step ships the agent
  INERT: nothing enqueues it in prod (that wiring — the trigger, `approve!`/`reject!`, the admin
  page — is S36-pen-model-clusterer-wiring).

  **There is no `MODEL_ID` constant (Q32).** Add a `PenModelClusterer` entry to `config/llm.yml`
  (S04) under `production:` and `development:`, pointing at the SAME DigitalOcean model S01's spike
  picked as the pen agents' starting model (S11 already added a `PenVariantClusterer` entry for it —
  this is a SECOND, separately-named entry with the identical `model:`/`api_base:`/`api_key_env:`/
  `assume_model_exists:`/`openai_use_system_role:` values, not a shared key, because L1 and L2 are
  benched and later re-picked independently — S30-chat-bench-round may pick a DIFFERENT model for L2
  than for L1, and that later config edit must not accidentally also move L1):

  ```yaml
  PenModelClusterer:
    provider: openai
    model: <the same model id S01's spike picked as the pen agents' starting model>
    api_base: https://inference.do-ai.run/v1
    api_key_env: DO_INFERENCE_TOKEN
    assume_model_exists: true
    openai_use_system_role: <whatever value S01's spike determined works on DO>
  ```

  `test:` resolves this class to the fixed OpenAI test default the same way every other agent's
  entry does (S04), so this class's specs stub the same literal
  `https://api.openai.com/v1/chat/completions` URL as every other agent spec, and assert the
  requested model through `LlmConfig.for("PenModelClusterer").model` (or whatever accessor S04
  defines), never a literal string.

  **Four halting decision tools**, nested inside `PenModelClusterer` exactly as `PenVariantClusterer`
  nests its own (S11) and `InkClusterer` nests its own (ink_clusterer.rb:32-98): `AssignToModel`,
  `CreateNewModel`, `Ignore`, `HandOverToHuman` — tool-call names `assign_to_model`, `create_new_model`,
  `ignore`, `hand_over_to_human` (the demodulized-and-underscored names these class names produce via
  `config/initializers/ruby_llm.rb:8-22`; these are the exact four names
  docs/pen-clustering-plan.md:165 lists). Copy `PenVariantClusterer::BaseTool` (S11, itself a copy of
  `InkClusterer::BaseTool`, ink_clusterer.rb:5-30, whose helpers live at :15-29) into a
  `PenModelClusterer::BaseTool` with the
  identical shape: `attr_accessor :model_micro_cluster, :agent_log`, a two-arg constructor, the same
  `missing_explanation?`/`missing_explanation_error` pair, and `update_extra_data(data)` storing
  `"action" => name` plus whatever the tool passes.

  Fixed `extra_data` keys, shared with S36 (apply/wiring) and any future admin page — the exact mirror
  of S11's L1 list: `action`, `model_id` (assign only), `msg`, `explanation_of_decision`,
  `manual_rejection_note`, `auto_rejection`. No derived tuple is stored: model attributes are DERIVED,
  not authored (pen plan, "variant and model attributes are derived, not authored"), so S36's
  `approve!` re-derives the most common `(brand, model)` at approval time exactly as S12 does for L1.

  - **`AssignToModel`**: `param :model_id, type: "integer", ...`, `param :explanation_of_decision, ...`;
    looks up `Pens::Model.find_by(id: model_id.to_i)`, returns the "please supply a valid id" error
    string if not found, otherwise `update_extra_data("model_id" => model.id, ...)` and halts. Mirrors
    `AssignToVariant` (S11) with `variant_id` -> `model_id`, `Pens::ModelVariant` -> `Pens::Model`.
  - **`Ignore`**: no params beyond `explanation_of_decision`; mirrors `IgnorePen` (S11) /
    `IgnoreInk` (ink_clusterer.rb:73-89) exactly. **Decided L2 ignore policy**
    (docs/pen-clustering-plan.md:340, 79): ignore a model micro cluster whose SIMPLIFIED MODEL text is
    really a LINE NAME (e.g. "Pilot Custom", "Sailor Shikiori" — these are product lines, not models;
    the actual model is one of several under that line) or really a MATERIAL description entered as
    the model (e.g. "Ensso Japanese Ebonite" — a material, not a model name). This is a narrow policy:
    do NOT ignore a model micro cluster just because it looks unusual or the model is obscure — an
    obscure-but-real model name is handed over to a human (`hand_over_to_human`), never ignored,
    because ignoring is permanent and a hand-over is not (docs/pen-clustering-plan.md:343-344). Write
    this into `SYSTEM_DIRECTIVE` as its own short section, distinct from and much narrower than L1's
    ignore policy (nib units, unidentified brands, clones/fakes, non-pen products — none of which
    apply at the model level, since by the time a `Pens::ModelMicroCluster` exists, L1 has already
    filtered those out of its own variants).
  - **`HandOverToHuman`**: no params, mirrors `ink_clusterer.rb:91-98` / S11's version exactly.
  - **`CreateNewModel` — has behaviour with no ink-side analogue, mirroring S11's `CreateNewVariant`
    for the collision check (Q20).** `pens_models` has a UNIQUE index on `(brand, model)`
    (db/structure.sql:2114, `index_pens_models_on_brand_and_model`), so a new `Pens::Model` row needs
    real, non-blank `brand`/`model` values at creation time — unlike `MacroCluster`, which is created
    with a throwaway UUID name and renamed later by `UpdateMacroCluster` (no uniqueness constraint on
    that name), a blank or UUID-shaped `Pens::Model` would either violate `NOT NULL` or collide with
    another equally-blank row. `execute(explanation_of_decision:)` takes NO brand/model params from
    the model — the same no-data-params shape `InkClusterer::CreateNewCluster` (ink_clusterer.rb:55-71)
    and S11's `CreateNewVariant` both have — and derives the mmc's own most-common brand/model tuple
    internally, using THAT for the collision check:
    ```ruby
    def execute(explanation_of_decision:)
      return missing_explanation_error if missing_explanation?(explanation_of_decision)

      tuple = model_micro_cluster.most_common_tuple
      existing = Pens::Model.find_by(tuple)
      if existing
        return "A model with this brand and model already exists: id #{existing.id}, " \
               "name '#{existing.name}'. Use assign_to_model(model_id: #{existing.id}) " \
               "instead of creating a duplicate."
      end

      update_extra_data(
        "msg" => "Creating new model for #{model_micro_cluster_str} (#{tuple[:brand]} #{tuple[:model]})",
        "explanation_of_decision" => explanation_of_decision
      )
      halt "Creating new model"
    end
    ```
    Returning a plain string (not calling `halt`) on collision sends this message back to the LLM and
    the loop continues — the model is expected to call `assign_to_model` next, exactly like S11's
    `CreateNewVariant`. **Implementer default:** `Pens::ModelMicroCluster#most_common_tuple` does not
    exist yet anywhere in the codebase; add it as a small new method mirroring
    `Pens::UpdateModel#best_attr_value`'s technique (app/workers/pens/update_model.rb:32-50: most
    common value among the underlying collected pens, longest string as the tiebreak) applied over
    `CollectedPen` rows reachable through this mmc's `model_variants -> micro_clusters -> collected_pens`
    chain — e.g. `CollectedPen.joins(pens_micro_cluster: :model_variant).where(pens_model_variants:
{ pens_model_micro_cluster_id: id })`, grouped by `brand`/`model` independently. This is only a
    DECIDE-TIME existence check, not the authoritative creation logic: S36's `approve!` is what
    actually calls `Pens::Model.create!` and handles the `RecordNotUnique` race (a bypassed or stale
    tool check) by refusing and rejecting the log, mirroring S12's rule for L1 exactly (Q20's second
    half). The derived tuple is NOT written into `extra_data` as a contract key — it may appear inside
    `msg` or the explanation prose, nothing more. S36's `approve!` RE-DERIVES the most common
    `(brand, model)` over the mmc's variants' collected pens at approval time (reusing
    `Pens::UpdateModel`'s `best_attr_value` logic), which is what S36 already says and what S12 does
    for L1: attributes are derived, not authored, so the freshest data wins. This tool does not create
    a `Pens::Model` row itself, same as `CreateNewCluster`/`CreateNewVariant` only stash intent in
    `extra_data`.

  **Lookup tools** (docs/pen-clustering-plan.md:165-167: "similarity search restricted to
  `Pens::Model` embeddings, `Pens::Model.search`, known brand, web search"):
  - **`Tools::PenModelSimilaritySearchTool`** (new, `app/agents/tools/pen_model_similarity_search_tool.rb`)
    wraps a NEW class method, `Pens::Model.model_embedding_search(query)` — TIER-1 ONLY (model
    embeddings, never variants or collected pens; today's `Pens::Model.embedding_search`, which S10's
    `PenSimilaritySearchTool` wraps for L1, is the FULL three-tier cascade and is the wrong tool for
    L2, which must never surface a model indirectly through one of its own variants' or collected
    pens' embeddings — that would defeat the whole point of testing whether the MODEL itself is
    findable). Add to `app/models/pens/model.rb`:
    ```ruby
    def self.model_embedding_search(query)
      return [] if query.blank?

      connection.execute("SET hnsw.ef_search = #{HNSW_EF_SEARCH}")
      entry = LlmConfig.embeddings_entry            # the resolved `embeddings.read` entry (S18/S24)
      query_embedding = EmbeddingsClient.new(entry.name).fetch(query)
      PenEmbedding
        .where(owner_type: "Pens::Model")
        .select(:id, :owner_type, :owner_id) # narrowed select, S09's tier-hygiene pattern
        .nearest_neighbors(entry.column, query_embedding, distance: "cosine")
        .includes(:owner)
        .order(:neighbor_distance)
        .first(200)
        .reject { |e| e.neighbor_distance > SIMILARITY_CUTOFF }
    end
    ```
    Do NOT hard-code `:embedding` or the client's default entry: this step lands after S27's read
    flip, so `embeddings.read` resolves to `current`/`embedding_v2`, and a literal `:embedding` would
    query the stale 1536-dim column with a 1024-dim vector. Copy the column/model resolution verbatim
    from `Pens::Model.embedding_search`'s tier-1 block as S24 rewrote it — read the merged code, use
    its real accessor names, do not copy the illustrative ones above. Reuse
    `Pens::Model::SIMILARITY_CUTOFF`/`HNSW_EF_SEARCH` (S09's constants, already on this class)
    and NEVER a literal `:embedding` column name or `0.6`/`1000` literal — whatever `embeddings.read`
    resolves to at call time (S24's config; by the time this step lands in the roadmap's order,
    S27's read flip has already merged, though this method makes no hard assumption about which
    column is live — it is written against the same config accessor every other post-S24 search
    method uses). Compute the count of model micro clusters per returned model in ONE grouped query
    (the same anti-N+1 technique S10's `PenSimilaritySearchTool` uses for variant counts):
    `Pens::ModelMicroCluster.where(pens_model_id: model_ids).group(:pens_model_id).count`. Render each
    result as `{id:, brand:, model:, distance:, model_micro_cluster_count:}`.
  - **`Tools::PenModelFullTextSearchTool`** (new, `app/agents/tools/pen_model_full_text_search_tool.rb`)
    wraps the EXISTING `Pens::Model.search(query)` (model.rb:20-28, ILIKE over
    `CONCAT(pens_model_variants.brand, pens_model_variants.model)` through the model's variants) —
    guard blank query the same way S10's `PenFullTextSearchTool` guards `Pens::ModelVariant.search`'s
    blank-returns-everything behaviour, cap the result (e.g. `.limit(20)`), render
    `{id:, brand:, model:, model_micro_cluster_count:}` using the same one-grouped-query technique.
  - **Known brand**: reuse `Tools::PenKnownBrandTool` (S10) UNCHANGED, constructed with the
    `Pens::ModelMicroCluster` instance in place of a `Pens::MicroCluster` — the tool only ever calls
    `.simplified_brand` on whatever it is given (`Pens::ModelMicroCluster` has its own
    `simplified_brand` column, same as `Pens::MicroCluster`), so this works via plain Ruby duck typing
    with zero code change to the tool. **Implementer default:** this checks the SAME thing L1's own
    `known_brand` call already checks (does an ASSIGNED L1 `Pens::MicroCluster` share this
    `simplified_brand`) — it does not check "is this brand already assigned to a `Pens::Model`" at the
    L2 level specifically. No separate decision was made distinguishing an L2-scoped known-brand
    check from L1's; reusing the tool unmodified is the simplest option consistent with that, and the
    signal (is this brand seen anywhere in the assigned pen hierarchy) is still meaningful at L2. If
    this later proves too noisy in practice, a stricter `Pens::ModelMicroCluster.where(simplified_brand:
..., pens_model_id: not nil).exists?` variant is a small follow-up, not a blocker here.
  - **`Tools::PenWebSearchTool`** (S10) reused unchanged, constructed with `agent_log` exactly as L1
    does.

  **System directive** (`SYSTEM_DIRECTIVE` constant, mirrors `PenVariantClusterer`'s heredoc
  structure, itself mirroring `ink_clusterer.rb`'s): explains the model micro cluster / model
  distinction (a `Pens::ModelMicroCluster` groups spellings of a brand+model pair the same way a
  `Pens::MicroCluster` groups spellings of a full pen at L1; a `Pens::Model` is the canonical
  brand+model row multiple model micro clusters can point at, exactly the way multiple `Pens::MicroCluster`
  rows point at one `Pens::ModelVariant`), the four actions, and the narrow ignore policy above.
  **Implementer default:** also copy S11's Q18 "an unknown brand may be a misspelling — double check
  spelling or search the web before concluding it's new" sentence into this directive too, for
  consistency with L1's tone (not a separately decided requirement for L2, but there is no reason for
  L2's guidance on the same `known_brand` tool to read differently from L1's).

  **User prompt**: the model micro cluster's own `id`, `simplified_brand`/`simplified_model`
  (mirrors `Pens::ModelMicroCluster.ordered`'s sort key, model_micro_cluster.rb:14), and for each of
  its `model_variants` (`has_many`, model_micro_cluster.rb:2-5): the variant's `#name`
  (brand+model+color+material+trim_color+filling_system joined, model_variant.rb:38-41) and its own
  `#collected_pens_count` (model_variant.rb:30-32) — this is a much shorter list than L1's per-cluster
  pen tuples (a model micro cluster typically has a handful of variants, not dozens of pen spellings),
  so no `PROMPT_TUPLE_CAP`-style truncation constant is needed here; **implementer default:** if a
  future model micro cluster with an unusually large variant count turns out to blow the prompt
  budget, add a cap then — nothing in today's data requires one at this step.

  **`decide(agent_log:)`** — copy S11's shape exactly, substituting `model_micro_cluster` for
  `micro_cluster`:

  ```ruby
  def decide(agent_log:)
    raise "chat already built" if @chat
    self.agent_log_id = agent_log.id
    @agent_log = agent_log
    ask!(user_prompt)
    agent_log.reload.extra_data
  end
  ```

  **`perform`**:

  ```ruby
  def perform
    return if already_resolved?

    if model_micro_cluster.model_variants.present?
      decide(agent_log:)
      agent_log.waiting_for_approval!
    else
      # Mirrors S11's Q19 empty-cluster guard at L1, applied by symmetry at L2 (no
      # separate decision names this case for L2, but the same race is possible here:
      # a human could unassign every variant from this mmc between the trigger firing
      # and this run executing).
      agent_log.update!(
        extra_data: (agent_log.extra_data || {}).merge(
          "auto_rejection" => "empty_cluster",
          "explanation_of_decision" =>
            "The model micro cluster has no variants in it. It is not possible to cluster an empty model micro cluster."
        )
      )
      agent_log.reject!
    end
  end
  ```

  No debounce (this agent has no real-time trigger yet — S36 wires the trigger behind
  `PEN_CLUSTERING_L2_ENABLED`, and even then the pen plan says L2 "is not limited by the L1 queue
  depth", docs/pen-clustering-plan.md:169, so there is nothing here for a debounce window to protect
  against).

  **Guards**: `already_resolved?` mirrors S11's three-check structure over `Pens::ModelMicroCluster`:
  already `ignored?`, already `pens_model_id.present?`, or has a `waiting_for_approval`/`processing`
  `PenModelClusterer` log.

  **`agent_log`**, written correctly from the start (no bare-`=` bug to avoid, same as S11):

  ```ruby
  def agent_log
    @agent_log ||= AgentLog.find(agent_log_id) if agent_log_id
    @agent_log ||= model_micro_cluster.agent_logs.pen_model_clusterer.processing.first
    @agent_log ||= model_micro_cluster.agent_logs.pen_model_clusterer.waiting_for_approval.first
    @agent_log ||= model_micro_cluster.agent_logs.create!(name: self.class.name, transcript: [])
  end
  ```

  Add `AgentLog.pen_model_clusterer` (`scope :pen_model_clusterer, -> { where(name:
"PenModelClusterer") }`, next to S06's `pen_variant_clusterer` scope, agent_log.rb) — S06
  deliberately left this scope out for S29 to add.

  **L2 case exporter** (new file `lib/bench/pen_model_cases.rb`, extending S21's pen-case harness
  code, required from `lib/tasks/bench.rake`; spec `spec/lib/bench/pen_model_cases_spec.rb`): over the
  `Pens::ModelMicroCluster` rows that are ASSIGNED and still have variants — 2,971 of 3,320 assigned
  today have variants (349 are the empty-assigned ones S06's `with_model_variants` scope filters, kept
  as human spelling rules under Q8) — label `assign` when the model has ANOTHER model micro cluster
  that still has variants (1,649 strictly-non-empty siblings today; 1,736 counting an empty-assigned
  sibling too, because empty assigned model micro clusters are kept as spelling rules (Q8), mirroring
  S21's identical L1 choice), else `create` (1,322 strictly, 1,235 under the Q8-consistent count — **derive the exact
  split at export time from the cleaned bench DB, not from these prod snapshot numbers, since it
  depends on which cleanup (S08) and Q8 counting rule is in effect when the exporter actually runs**).
  The 6 ignored model micro clusters are reported as their own small `ignore` cell (too few to
  stratify meaningfully) rather than dropped silently.

  There is a subtlety worth naming explicitly, and it decides the hide step below. `Pens::Model.search`
  and the (unused-here) tiers 2/3 of `Pens::Model.embedding_search` all join THROUGH variants, so a
  model whose only remaining model micro clusters are the EMPTY assigned ones has no variants to join
  through and is reachable only via its own model-level embedding (tier 1). Exactly 1,736 - 1,649 = 87
  cases are of that shape: labelled `assign` because Q8 counts an empty assigned sibling as a sibling,
  but with no non-empty sibling left once the case's own mmc is held out. Those 87 are a named
  stratum of their own and are reported separately — their model's derived name and embedding were
  built from the held-out mmc's pens alone and cannot be re-derived from anything, so scoring them
  alongside the rest would overstate assign recall. Do NOT hide their model embedding (that would make
  the correct answer unreachable by any of the four lookup tools and the case unanswerable); do NOT
  score them in the headline assign cell either. Derive the 87 at export time; the number is a
  2026-09-12 prod snapshot, not a constant.

  **Hide step**, inside the same per-case rolled-back transaction pattern S20/S21 already establish:
  1. `UPDATE pens_model_micro_clusters SET pens_model_id = NULL, ignored = false WHERE id = ?` — undo
     the ground-truth assignment, same as L1's hide step nulls `pens_model_variant_id`.
  2. **If no OTHER assigned model micro cluster of any kind — empty ones included — still points at
     this model** (a true "lonely-model" / `create` case): hide the model's own embedding,
     `UPDATE pen_embeddings SET embedding = NULL, embedding_v2 = NULL WHERE owner_type = 'Pens::Model'
AND owner_id = ?` (all 1,798 models have exactly one `pen_embedding` row today, 1 with a NULL
     vector already), and STOP. Do NOT call `Pens::UpdateModel` here: step 1 has already nulled the
     held-out mmc's `pens_model_id` and this branch's own condition says no other mmc points at the
     model, so `model.collected_pens` is necessarily empty (`Pens::Model` reaches pens only through
     `model_micro_clusters -> model_variants -> micro_clusters -> collected_pens`, model.rb:4-10) and
     `Pens::UpdateModel#perform` would return at update_model.rb:7 every single time — a guaranteed
     no-op followed by a wasted `FetchEmbedding` call that re-embeds unchanged stale content. There is
     nothing left to derive from; the NULLed embedding IS the hide.
     (The 87 cases named above — labelled `assign` but with only EMPTY assigned siblings left — do not
     take this branch, precisely because an empty assigned sibling still points at the model. They are
     reported as their own stratum instead, per the paragraph above.)
  3. **If OTHER model micro clusters WITH VARIANTS still point at this model** (the ordinary `assign`
     case): this is where the leak actually is, and this is where Q12's L2 re-derivation runs. The
     surviving model's `brand`/`model` and its embedding were derived by
     `Pens::UpdateModel#best_attr_value` (update_model.rb:32-50) from ALL its pens INCLUDING the
     held-out mmc's, so run `Pens::UpdateModel.new.perform(model.id)` (update_model.rb:5-12) and then
     `FetchEmbedding.new.perform("PenEmbedding", model.pen_embedding.id)` (fetch_embedding.rb:8-13)
     inside the same rolled-back transaction, so the model's derived name and vector reflect only the
     remaining mmcs' pens. Note `Pens::UpdateModel#perform` also fires
     `Pens::AssignBrand.perform_async` (update_model.rb:10), which is inert under `Bench.isolate!`'s
     fake Sidekiq. (Q12's over-sampling half is L1-ONLY, and the reason is recorded here rather than
     presented as something Q12 decided for L2: Q12's stated rationale is that "the pen L1 labelled
     set is 99% multi-pen micro clusters while the real backlog is 96% singletons", and that shape
     mismatch has no L2 counterpart — prod has 0 unassigned non-empty model micro clusters, so there
     is no L2 backlog whose shape the labelled set could fail to match. This step therefore builds no
     separate "assign/singleton" oversampling cell; only the re-derivation half of Q12 applies. If an
     assign-case-left-with-exactly-one-sibling stratum later turns out to matter, it is a small,
     symmetrical follow-up modelled on S21's assign/singleton cell.)
  4. Call `PenModelClusterer.new(model_micro_cluster.id, agent_log_id: fresh_bench_log.id).decide(agent_log:
fresh_bench_log)` with the candidate model injected through `LlmConfig.with_override("PenModelClusterer"
=> { model:, provider:, api_base:, api_key_env: })` when benching a candidate other than the S01
     starting model; the baseline round (this step's own smoke test, and S30's baseline row for L2)
     needs no override, since the config default already points at the S01 model.
  5. Roll back.

  Feedback hiding (any earlier rejected `PenModelClusterer` logs on the same mmc) mirrors S20/S21's
  `--with-feedback` convention exactly, once real L2 rejections exist (none do yet — this agent is
  inert until S36).

- **Depends on.** S04-llm-config-chat (`config/llm.yml` and `LlmConfig.with_override` must exist),
  S20-harness-core-ink (the runner/report/pricing/record-replay code this exporter reuses),
  S10-pen-tools (the tool base pattern and the two tools reused unmodified — `PenKnownBrandTool`,
  `PenWebSearchTool`), S06-pen-groundwork (`Pens::ModelMicroCluster has_many :agent_logs`,
  `owner_with_model_variants`/`with_model_variants` scopes), S11-pen-agent-decide (the exact `decide`/
  `perform`/`agent_log`/`BaseTool` template this step copies almost verbatim; also the reason
  `PROMPT_TUPLE_CAP`-style thinking is already established for pen agent prompts even though this
  step doesn't need its own cap), S21-harness-pen-cases (the pen exporter/hide-step code and
  transaction pattern this step's L2 exporter extends).
- **Why here.** S30-chat-bench-round is the first paid chat round to cover BOTH pen levels in one
  sweep (baselined against the S01 starting model for each), so the L2 agent — inert, safe to merge
  early — is built now so its case exporter exists before that round, exactly as S11/S21 did for L1.
  The wiring half (trigger, `approve!`/`reject!`, admin page, the full rejection cascade) waits for
  S36, after the model pick, mirroring the L1/L2 split the pen plan itself describes (build the agent,
  bench it, THEN wire it).
- **Does not include.** The trigger (`Pens::UpdateModelMicroCluster`'s currently-dead `return unless
cluster.pens_model_id` branch at app/workers/pens/update_model_micro_cluster.rb:7 stays exactly as
  it is — S36 adds the `else` branch), `approve!`/`reject!` and the `RecordNotUnique` collision
  handling at approval time (S36), the admin review page and its badge/filter marker (S36), any
  `PEN_CLUSTERING_L2_ENABLED` flag (S36 introduces it, defaulted off), `RunFailedClusterJobs` coverage
  for this agent's name (S36).
- **Definition of done.**
  - Specs in `spec/agents/pen_model_clusterer_spec.rb`, modelled section-by-section on S11's
    `spec/agents/pen_variant_clusterer_spec.rb` (itself modelled on `ink_clusterer_spec.rb`): agent_log
    creation/reuse/memoization; `perform` per action via `stub_request(:post,
"https://api.openai.com/v1/chat/completions")`; each tool's `.call` returning
    `RubyLLM::Tool::Halt` and its `extra_data` side effects; a dedicated `#decide` spec proving no
    state transition and no job enqueued while `transcript`/`usage` ARE populated; a config spec
    asserting the `PenModelClusterer` entry resolves to the DO settings in `production`/`development`
    and the test default in `test`; the empty-mmc guard spec (zero variants -> `auto_rejection ==
"empty_cluster"`, `reject!` called, no `waiting_for_approval!`); `already_resolved?` for each of
    its three cases.
  - `CreateNewModel` spec proves both branches: no existing `Pens::Model` with the derived tuple ->
    halts with `extra_data["action"] == "create_new_model"`; an existing `Pens::Model` matching the
    derived tuple -> returns the assign-hint string (asserted against a real `RubyLLM::Tool::Halt`
    NOT being raised) and leaves `extra_data["action"]` untouched. A spec for
    `Pens::ModelMicroCluster#most_common_tuple` itself (factory-built variants/collected pens with a
    clear plurality value).
  - `Tools::PenModelSimilaritySearchTool`/`Tools::PenModelFullTextSearchTool` specs mirroring S10's
    pattern (real factory rows for variant/count queries, `Pens::Model.model_embedding_search`/
    `.search` stubbed at that boundary, not lower; the one-grouped-query anti-N+1 assertion for the
    model-micro-cluster-count computation).
  - L2 case exporter/hide-step specs (bench-DB-free, real factories, mirroring S21's pattern): the
    `assign`/`create` label rule including the Q8 empty-sibling-counts-as-shared case; the hide step
    correctly hides the model's own embedding only in the true lonely-model case (no assigned mmc of
    any kind left), never when an empty assigned sibling remains and never in the multi-sibling case;
    the re-derivation call sequence (`Pens::UpdateModel.new.perform` then `FetchEmbedding.new.perform`)
    fires ONLY for assign cases that still have a variant-bearing sibling, and never for the
    lonely-model branch (where it would be a guaranteed no-op); the 87-case empty-sibling-only stratum
    is flagged and excluded from the headline assign cell; the 6 ignored rows reported as their own
    cell.
  - A 20-case smoke run of the L2 exporter and `decide` recorded against the bench DB, once the bench
    DB has been brought to the post-S27 shape (S28's own note about pointing the bench process's
    embeddings `read` at `legacy` for smoke runs applies here identically, until S30's own refresh).
  - Optional split: (a) the agent (tools, directive, `decide`/`perform`, config entry) as one PR, (b)
    the L2 case exporter as a second PR — either way both land before S30 starts.
- **Rollback.** Prod risk: none — nothing enqueues this agent, and merging it only adds a
  `config/llm.yml` entry, new tool files, a new agent file, and a new bench exporter file, none of
  which any existing prod path calls. `git revert` is trivially safe.
- **Decisions applied.**
  - **Q32** — no `MODEL_ID` constant; the agent is born as its own `config/llm.yml` entry pointing at
    the S01-picked DigitalOcean model, independently of `PenVariantClusterer`'s entry so a later L2
    model pick (S36) never accidentally moves L1's model too.
  - **Q20** — `CreateNewModel#execute` checks for an existing `Pens::Model` matching the mmc's derived
    most-common brand/model tuple and, if found, RETURNS a message telling the model to assign
    instead of halting — the same mechanism S11 uses for `CreateNewVariant`, applied at the model
    level. The corresponding approval-time collision (a race, or a bypassed tool check) is S36's
    `approve!` refusing and rejecting the log, mirroring S12's rule for L1 exactly.
  - **Q12** — the L2 analogue of the pen bench's re-derivation rule: for an `assign` case whose model
    still has a variant-bearing sibling, re-run `Pens::UpdateModel` inside the transaction and
    re-fetch the model's embedding before the agent's `decide` call sees it, so the model's derived
    name/embedding never leaks the held-out model micro cluster's own contribution. A true
    lonely-model (`create`) case has nothing left to derive from, so its hide is simply NULLing the
    model's own vector.
  - **Q8** — the 349 empty ASSIGNED model micro clusters are kept as human spelling rules (S06's
    `with_model_variants`/`owner_with_model_variants` scopes) and, per that same policy, count as
    "shared" siblings for the L2 exporter's `assign` label — a model with only empty-assigned
    siblings besides the held-out mmc is still labelled `assign`, not `create`.
- **Implementation notes.**
  - Files to create: `app/agents/pen_model_clusterer.rb`, `app/agents/tools/pen_model_similarity_search_tool.rb`,
    `app/agents/tools/pen_model_full_text_search_tool.rb`, `lib/bench/pen_model_cases.rb`,
    `spec/agents/pen_model_clusterer_spec.rb`, `spec/agents/tools/pen_model_similarity_search_tool_spec.rb`,
    `spec/agents/tools/pen_model_full_text_search_tool_spec.rb`, `spec/lib/bench/pen_model_cases_spec.rb`.
    Files to modify: `config/llm.yml` (new entry), `app/models/agent_log.rb` (new
    `pen_model_clusterer` scope), `app/models/pens/model.rb` (new `model_embedding_search` class
    method), `app/models/pens/model_micro_cluster.rb` (new `most_common_tuple` method),
    `lib/tasks/bench.rake` (new task entries).
  - Tool constructor pattern, mirrored from S11's assembly (`ink_clusterer.rb:294-304` /
    `pen_variant_clusterer.rb`'s `tools` method):
    ```ruby
    def tools
      [
        AssignToModel.new(model_micro_cluster, agent_log),
        CreateNewModel.new(model_micro_cluster, agent_log),
        Ignore.new(model_micro_cluster, agent_log),
        HandOverToHuman.new(model_micro_cluster, agent_log),
        Tools::PenKnownBrandTool.new(model_micro_cluster),
        Tools::PenModelSimilaritySearchTool.new,
        Tools::PenModelFullTextSearchTool.new,
        Tools::PenWebSearchTool.new(agent_log)
      ]
    end
    ```
  - Manual verification in dev after this PR merges (S36 has not merged yet, so there is no
    approve/reject path — this only confirms the decide half works end-to-end against the real DO
    API, exactly as S11's own manual check does): pick an assigned `Pens::ModelMicroCluster` id with a
    handful of variants on the dev copy, run `RunAgent.perform_async("PenModelClusterer", id)` from
    the Rails console, confirm the resulting `agent_log.state` is `"waiting-for-approval"` with a
    plausible `extra_data["action"]`.

### S30-chat-bench-round — Chat bench round(s): OpenAI baselines for the ink agents, the S01 model as the pen baseline, DO candidates; pick per agent; bench refresh #2

- **Goal.** Refresh the bench DB (a new dump now carries both `embedding`/`embedding_v2` columns and
  the restore rebuilds four HNSW indexes, so expect longer than S17's timings — this is bench refresh
  #2, the second of only two MAJOR refreshes (Q6); it exists purely to pick up the drip's newest
  labelled logs since S22's refresh #1). The in-place alternative — copy the picked embeddings model's
  `bench_embeddings` column into `embedding_v2` on the existing copy and build the HNSW index locally —
  saves the dump time but FORGOES the newest drip labels, which is the whole purpose of refresh #2;
  taking it therefore also requires re-exporting the pen and ink cases from
  `PRODUCTION_READONLY_DATABASE_URL` against the existing copy, under S17's runnable-case constraint
  (only owners already present in the copy can be run). Say which of the two was taken, and why. Verify with
  `EXPLAIN` that both `embedding_search` methods (`app/models/macro_cluster.rb:105-165`,
  `app/models/pens/model.rb:30-96`) hit the `embedding_v2` index, and print the effective embeddings
  config at task start so the bench process's `read` entry provably equals prod's (S18's
  `config/llm.yml` `embeddings:` block, `development:` section for the bench process; the config is
  file-based, so there is no ENV fallback to double-check (Q1)). Re-check the DO catalog (ids, prices, vision flags — the S01
  catalog can go stale between rounds) and update `lib/bench/pricing.rb` (the hand-maintained price
  table introduced in S20, keyed by the response `model` string written to `agent_log.usage["model"]`
  at `ruby_llm_agent.rb:130`; Q5 — there is no in-app usage-field change, this file is bench-only).
  Baselines and candidates, one `bench:run[<AgentClass>,<model>]` invocation per cell (S20's task
  spelling). `<model>` names a candidate; the runner resolves it into the config hash
  `candidate = { model:, provider:, api_base:, api_key_env: }` and applies it through
  `LlmConfig.with_override("<AgentClass>" => candidate) { ... }` — S04's mechanism, the same
  per-class hash shape S20 and S28 use.
  Candidate short list (migration plan P3, to be confirmed against the re-checked catalog): Claude
  Haiku 4.5, DeepSeek V4 Pro, Kimi K2.6, Qwen3.8-Max, GLM-5.3, plus Claude Sonnet 5 on a small subset
  as the cost/quality upper bound. If S01's spike narrowed this list, use S01's.
  - **Ink agents** (InkClusterer, `CheckInkClustering` (shared entry, all four decision types),
    ReviewApprover): re-run the OpenAI baseline (gpt-4.1 for InkClusterer/checkers, gpt-4.1-mini for
    ReviewApprover) fresh — the S22 baseline is invalid once embeddings changed underneath it in
    S23-S27 — then bench the DO candidate short list against it.
  - **Pen agents** (PenVariantClusterer L1, PenModelClusterer L2): the baseline column is the **S01
    starting DO model** for both (Q32; there is no OpenAI baseline for pen agents, they never ran on
    OpenAI), benched against the remaining DO candidates from the S01 short list. For L1 that model is
    also what prod has been running since S15, so a gap between the bench numbers and the drip's
    per-action stats (S15's Q27 recording) can only be population or label-rule drift, never the model
    — reuse S22's comparison method. For L2 the same model is the baseline by construction: the agent
    is inert until S36, so there is no prod traffic to compare against.
  - **Export-mode grading** (Claude Code, S20's export mode) for the agents with no automatic label:
    PenAndInkSuggester (both `PenAndInkSuggester`/`PenAndInkSuggester.premium` entries),
    GoogleSearchSummarizer, YoutubeSummarizer, WebPageSummarizer, ReviewFinder, InkBrandClusterer.
    SpamClassifier gets the cheap-tier pick plus spot checks, and nothing more — migration P3 decides
    exactly that for negligible-volume agents, and S28 explicitly does not build export-mode code for
    it, so there is no SpamClassifier export to grade here.
  - **Vision constraint:** THREE agents attach an image, not two — `review_approver.rb:126`,
    `review_finder.rb:108` and `youtube_summarizer.rb:21` are the only `ask(..., with:)` call sites in
    app/agents. Restrict all three candidate lists (including YoutubeSummarizer's, in export-mode
    grading) to DO models the S01 catalog marked vision-capable; do not bench or pick a non-vision
    model for any of them — it would error or silently drop the image, and YoutubeSummarizer is
    flipped in S31's wave 1 at 23.5 runs/day. Q15 keeps the thumbnail for the two review agents; the
    YoutubeSummarizer thumbnail was never in question. No prompt change.
  - **Sub-agent policy (Q14):** for every bench cell above whose agent calls a sub-agent
    (`GoogleSearchSummarizer` inside `search_web` for InkClusterer/`CheckInkClustering`/both pen
    agents; `YoutubeSummarizer`/`WebPageSummarizer` inside ReviewFinder and ReviewApprover's
    `Summarize` tool), the sub-agent runs on the **same candidate model** as the agent under test —
    wrap the whole `decide`/`ask` call for that cell in
    `LlmConfig.with_override("InkClusterer" => candidate, "GoogleSearchSummarizer" => candidate) { ... }`
    (with `candidate` the config hash defined above) (S04's scoped-override API; the runner from S20/S25 already threads overrides through, S25
    proved the same pattern for shadow mode) so sub-agent calls inside the same cell are not silently
    left on gpt-4.1-mini.
  - **Acceptance bar and cap (Q16):** the bar has two halves and BOTH must hold. (a) **Cost per run
    <= the agent's current cost per run**, computed from `lib/bench/pricing.rb` (the migration plan's
    original cost clause, which Q16 refines but does not delete). (b) **Quality**: point estimate
    within 1 pp of baseline (2 pp for ReviewApprover) **and** overlapping Wilson confidence intervals;
    either the interval doesn't overlap or the point estimate is more than the pp bar away → fail
    regardless of the other test. For the export-graded agents, which have no automatic label, (b)
    becomes "graded quality >= baseline" from the owner's Claude Code reading. Pick the CHEAPEST
    candidate that clears the bar.
    Budget ≈ $30/round: ReviewApprover averages ~21k prompt tokens/run before `Summarize` sub-calls
    (WebPageSummarizer runs ~34k tokens), so ~100 cases per candidate (200 only for the finalist once
    picked) and two or three candidates for the checkers keeps ReviewApprover from consuming the whole
    round; InkClusterer and the checkers have >9k labelled cases so the sampled subset, not the full
    set, is what's benched per round.
  - One or two rounds total. **Implementer default** for when a second round is warranted: the first
    round's per-agent picks disagree with each other (e.g. a candidate passes InkClusterer but fails
    ReviewApprover) enough that a narrower short list would plausibly change the outcome.
- **Depends on.** S27 (final embeddings live), S28 (checker `decide` + bench harness, ReviewApprover
  cases, export mode), S29 (PenModelClusterer L2 agent exists so one round covers L1 and L2 together),
  S21 (pen L1 bench cases).
- **Why here.** Strictly after the read flip (migration plan rule: embeddings must be final before
  chat models are compared, or a later embeddings change invalidates the pick) and after both pen
  agents exist (S11 L1 since S15, S29 L2), so no second pen-only round is needed. It is also the gate
  for the backlog (S41): nothing above today's inflow scale runs until a model choice is confirmed
  here (for pens the S01 model already runs at drip volume; this round only confirms or replaces it).
- **Does not include.** Any prod change. No config file is edited in this step — S31 (ink wave 1),
  S33 (pen L1 config PR if the pick differs from S01's), S36 (pen L2 config PR), S37 (ink final
  cutover) apply the picks.
- **Definition of done.**
  - A per-agent table (models compared, Wilson interval per model, point-estimate delta vs baseline,
    cost per run, pass/fail against the Q16 bar) recorded in `docs/llm-migration-plan.md`, with the
    round date(s) and the pgvector 0.7.4 (prod) vs 0.8.2 (dev/bench) caveat noted next to the numbers
    (carried over from S22/S23).
  - Picks written down per agent: for the ink agents this becomes S31/S37's config-flip target; for
    the pen agents, either "confirmed: keep S01's model" or "replaced with `<model>`" plus the exact
    `config/llm.yml` diff S33/S36 will apply. Write the pen result into
    `docs/pen-clustering-plan.md` decision 6 as well (S01 rewrote that decision to "born on the DO
    model the spike picked"), so decision 6 never goes stale.
  - The S05 runbook table (`docs/llm-migration-plan.md`, "Runbook" heading) gets its ink rows filled
    in now: for every ink agent, the picked model plus a named manual-replacement model from this
    round's short list (the runner-up), so the alert added in S05 has a concrete fallback the moment
    S31/S37 flip.
  - `lib/bench/pricing.rb` is up to date with this round's catalog snapshot (ids, price in/out,
    vision flag) — S31/S37's flip PRs and S33/S36's tuning read this file, not the S01 spike notes.
- **Implementation notes.**
  - Pre-flight: assert no `processing` bench logs leak into prod counts (the bench uses a separate
    database and Redis DBs, set up in S17) and print the effective per-agent config (provider, model,
    api_base, embeddings column/model) at the start of every `bench:run` invocation — copy the
    pattern S20 already built for the ink baseline runs.
  - The bench process's `config/llm.yml` settings live in the `development:` section (Q1: file-based,
    not ENV, so there is nothing extra to carry in `.env.local` for the bench to pick up the right
    `embeddings.read` entry).
  - Cost arithmetic: `AgentLog.where(name: <agent>, ...).sum` token counts times
    `lib/bench/pricing.rb`'s per-model price, not any `agent_logs.usage` cost field (none exists,
    Q5).
  - Wilson interval sizing: ~100 cases per candidate gives a Wilson half-width of roughly ±6-7 pp at
    85-90% agreement (±7.0 pp at 0.85, ±6.0 pp at 0.90, z=1.96), so a 1 pp difference is not resolvable at that n — the bar is deliberately "point
    estimate within 1 pp AND overlapping intervals," not "n large enough to prove <1 pp"; run 200
    cases only for a finalist that needs a tighter number.
- **Decisions applied.** Q32, Q5, Q6, Q14, Q15, Q16, Q1.

### S31-chat-cutover-wave-1 — Config-flip PRs for the low-risk ink agents (summarizers, SpamClassifier, PenAndInkSuggester, then ReviewFinder, InkBrandClusterer); multi-PR/ops activity

- **Goal.** A series of XS config-flip PRs, each editing one `config/llm.yml` entry to point at the
  S30 pick and each with its own watch window, so this row is a multi-PR activity like S15 rather
  than one PR: GoogleSearchSummarizer, YoutubeSummarizer, WebPageSummarizer, SpamClassifier,
  PenAndInkSuggester (both the plain entry and the `PenAndInkSuggester.premium` entry) first;
  spot-check outputs via `agent_logs`; then ReviewFinder and InkBrandClusterer. This wave is
  **ink-side only** — the pen agents have been on DigitalOcean since S15 (L1) and S13's worker went
  live before any of these flips, so there is no pen cutover in this wave or any other (Q32): no pen
  agent's own `config/llm.yml` entry is edited here. One flip does reach the pen agents indirectly —
  `GoogleSearchSummarizer` is also the `search_web` sub-agent of `PenVariantClusterer` (S10's
  `PenWebSearchTool`) and of `PenModelClusterer`, so record its merge date as a boundary in the
  per-action pen drip statistics exactly as S33 records a pen model change, and do not compare drip
  numbers across it. PenAndInkSuggester and
  SpamClassifier are not placed in any wave by the plans (migration P5 names
  summarizers → ReviewFinder/InkBrandClusterer → ReviewApprover/InkClusterer; migration P3 says
  unlabelled/low-volume agents "switch to the cheap tier pick, spot check outputs"); wave 1 is this
  roadmap's placement. PenAndInkSuggester's two entries are two separate PRs, not one: the free-tier
  entry first, then `PenAndInkSuggester.premium` — which flips LAST of this wave's first tranche and
  gets a 7-day watch window rather than 10 spot-checked outputs, because it is a user-facing patron
  feature and the third-largest token consumer (1.76M prompt tokens per 14 days). That placement is
  settled here, not left open; deferring the premium entry to S37 is listed in section 6 as an
  optional variation, not a fork inside this step.
  Sub-agent facts (unchanged from the concern's structure): only GoogleSearchSummarizer is the
  `search_web` sub-agent of InkClusterer and `CheckInkClustering::*`
  (`app/agents/tools/ink_web_search_tool.rb:17`, used by `ink_clusterer.rb:303` and
  `check_ink_clustering/base.rb:70`) — flipping it here means InkClusterer itself is still on OpenAI
  (until S37) but its `search_web` calls go to DO immediately, so this is the **first DO traffic
  inside an InkClusterer run**, ahead of the shadow (S32). YoutubeSummarizer and WebPageSummarizer are
  sub-agents of ReviewFinder (`review_finder.rb:59,62`) and of ReviewApprover's `Summarize` tool
  (`review_approver.rb:67,71`). Flipping them in this wave changes ReviewApprover's inputs before its
  shadow (S32) and its own flip (S37): either keep the Youtube/WebPage summarizer flips staged so the
  shadow's baseline doesn't move mid-run, or accept that the shadow measures
  ReviewApprover-on-candidate against prod-on-candidate-summaries with identical DO-produced
  summaries on both sides — the Q14 policy (sub-agents run on the same candidate as the agent under
  test, in bench and in shadow) makes this the expected, not accidental, comparison.
  For wave-1 agents the replay path of an in-flight transcript is a Sidekiq retry — **Sidekiq default
  25 retries** (Q4 is deferred: no retry-budget change ships anywhere in this migration;
  `app/workers/run_agent.rb`, `classify_user.rb`, `schedule_pen_and_ink_suggestion.rb`,
  `fetch_reviews/process_web_page_for_review.rb`) — or the worker restart at deploy (`fly.toml`
  `kill_timeout 120s`, `config/sidekiq.yml` `:timeout: 90`), both of which resume the `processing` log
  through `find_or_create_agent_log`/`restore_transcript` (`ruby_llm_agent.rb:57,173`).
  `RunFailedClusterJobs` covers only `InkClusterer` and `PenVariantClusterer` processing logs, never
  these wave-1 agents' own logs — a stuck wave-1 log relies on the Sidekiq retry or the deploy
  restart, not a janitor requeue. Replay of OpenAI-shaped transcripts on DO is therefore relied upon
  for every flipped agent (S01 item 3 verified both directions before this wave started). Pre-flight
  is information only: merge in a quiet hour, `AgentLog.processing.where(name: <agent>).count` before
  and right after the deploy, and for any hit watch that log's next attempt in Honeybadger for
  `RubyLLM::BadRequestError`/`RubyLLM::Error` raised from restore_transcript-shaped requests during
  the first hour. After each flip watch Honeybadger (`config/honeybadger.yml:42-43`
  `attempt_threshold: 3`; honeybadger-6.9.1 `plugins/sidekiq.rb:100-111` notifies when
  `retry_count + 1 >= 3`, i.e. on the 4th execution; the Sidekiq Web retry set shows first failures
  immediately) and the token graph. The S05 "model not found" alert is already live for every agent
  going into this wave; its runbook table (`docs/llm-migration-plan.md`, "Runbook" heading) names the
  replacement model per flipped agent, filled in by S30 — no separate alert PR is needed here.
- **Depends on.** S30 (the per-agent picks and the filled-in runbook rows), S05 (the alert is already
  live).
- **Why here.** Low-risk agents first, as the migration plan orders; GoogleSearchSummarizer on DO is
  also the first DO traffic inside InkClusterer runs, ahead of the shadow.
- **Does not include.** InkClusterer, the checkers (`CheckInkClustering::*`), the ReviewApprover model
  itself (all three flip in S37). No pen agent (Q32).
- **Definition of done.** Each flip has a one-line rollback in the runbook: `git revert` the
  `config/llm.yml` PR and merge (Q1 — every flip is a file edit, never a raw Fly secret change, so
  rollback is always a revert, never a "which secret did we set" guess). Per agent, the first 10
  outputs or 7 days (whichever comes first) read in `agent_logs` (prod, last 14 days at spike time:
  SpamClassifier 5 runs, InkBrandClusterer 19, WebPageSummarizer 38 — so one day is not enough for
  three of the seven agents, size the watch window accordingly);
  `AgentLog.where(name: X).order(:created_at).last(5).map { _1.usage["model"] }` shows the DO
  response model string (written at `ruby_llm_agent.rb:130`); Honeybadger errors for the agent
  workers and the Sidekiq retry set not above the previous week's count.
- **Implementation notes.**
  - Rollback caveat: a flip-back replays DO-issued tool-call ids against OpenAI for any `processing`
    log; S01 item 3 verified both directions, so the runbook line is "revert and merge, or let
    in-flight logs finish (or reject them) before flipping back" — no code change is needed to make
    rollback safe, only the timing note.
  - Each PR is scoped to exactly one `config/llm.yml` entry so a single revert cannot re-break a
    sibling agent's already-settled flip — including `PenAndInkSuggester` and
    `PenAndInkSuggester.premium`, which are two entries and therefore two PRs.
- **Decisions applied.** Q32, Q33, Q1, Q4.

### S32-shadow-run — Enable shadow mode for InkClusterer and ReviewApprover for about two weeks

- **Goal.** Turn shadow mode on. This is a one-line-per-agent `config/llm.yml` PR and nothing else:
  S25 shipped the code with the switch off, so the only edit here is filling in the `shadow:` block
  S25 added inside `shared:`. It maps agent class name -> the name of the candidate CHAT ENTRY to
  shadow with, and `null` means off:
  ```yaml
  shadow:
    InkClusterer: do_candidate # the entry name S30 picked
    ReviewApprover: do_candidate
  ```
  If the candidate is not already an entry, add it alongside the per-class chat entries
  (`provider: openai`, `api_base: https://inference.do-ai.run/v1`, `model: <S30 pick>`,
  `api_key_env: DO_INFERENCE_TOKEN`, `assume_model_exists: true`). S25's inline hook reads the block,
  returns immediately when the value is nil, and otherwise opens ONE
  `LlmConfig.with_override("InkClusterer" => candidate, "GoogleSearchSummarizer" => candidate) { ... }`
  block — and the ReviewApprover equivalent naming `YoutubeSummarizer` and `WebPageSummarizer` too
  (Q14: every sub-agent runs on the **same candidate** as the shadowed agent, so the shadow's
  comparison is candidate-agent-with-candidate-sub-agents against
  prod-agent-with-whatever-sub-agents-prod-is-currently-using). Turning shadow off again is a revert
  of this PR. Watch the first day for side effects:
  no shadow log appears in the admin review queue, no double checker runs, no `ink_reviews` writes,
  `agents` queue latency and `RunInkClustererAgent` run duration stay normal — an inline shadow doubles
  the occupancy of the concurrency-1 slot shared with `CheckInkClustering::*`, and a run over 15
  minutes trips `RunFailedClusterJobs`/`lost_job_threshold` (mechanics explained in full in S13's pen
  worker text: `sidekiq-throttled` releases the slot after `lost_job_threshold` regardless of any
  requeue, so a genuinely slow shadow run and a crashed one are told apart only by this timeout, not by
  the requeue itself). Then let it run about two weeks while S33-S36 are built. Cost: at most the two
  agents' current two-week spend (~$5-10 at today's volume: InkClusterer 33.5 runs/day, 2.14M prompt /
  62k completion tokens per 14 days; ReviewApprover 8.6 runs/day, 2.90M / 18k) — the S30 acceptance bar
  already requires the pick to cost <= current per run — because the shadow's `search_web`/`Summarize`
  sub-agent calls double GoogleSearchSummarizer, Youtube and WebPage summarizer runs (and Serper
  queries) for the period. Run `bench:shadow_report` weekly (built in S25, runs against prod data).
  Note the shadow doubles InkClusterer transcript volume for the period (`agent_logs` is 1 GB today,
  almost all transcripts) and appears as its own line in the admin token graph.
- **Depends on.** S25 (the shadow code itself: the shadow entry point, the distinct log name/terminal
  state so shadow logs never enter the human queue or block `already_resolved?`, and the sub-agent
  override plumbing), S30 (the candidate pick). S31 (the ink wave-1 flips) is a **soft** dependency,
  not a hard one: ideally the shadow starts after the summarizer flips have settled for a few days,
  because Youtube/WebPage summarizers feed ReviewApprover and the shadow's "prod" side would otherwise
  be measured against a moving baseline mid-run — but Q14 already puts the shadow's sub-agents on the
  same candidate model in both bench and shadow regardless of what prod's summarizers are currently
  running on, so starting the shadow before S31 finishes compares the intended combination, not a
  broken one; it just makes the "prod" comparison term shift partway through the two weeks if S31
  flips a summarizer mid-shadow. Prefer sequencing after S31 when the calendar allows it; do not block
  on it.
- **Why here.** The decided guard against bench/prod drift for the two highest-impact agents
  (InkClusterer, ReviewApprover) before their final cutover (S37).
- **Does not include.** Any decision applied by the shadow — shadow runs never touch `ink_reviews`,
  never move a `MicroCluster` or `InkReview` state, and never appear in the human review queue.
- **Definition of done.** Two weekly reports recorded, each giving (a) candidate-vs-prod-decision
  agreement with a Wilson interval (~470 InkClusterer and ~120 ReviewApprover shadow runs over two
  weeks: about ±4 pp at n=470), and (b) candidate-vs-human agreement on the n human verdicts available
  (expect ~40 for InkClusterer, since of 384 logs in the last 14 days only 40 carry a human verdict and
  344 were checker-decided; ~120 for ReviewApprover via `ink_reviews`). The go/no-go for S37 (the final
  ink cutover) is "no drift": the shadow agreement interval overlaps the bench agreement interval for
  the same model (from S30), not the 1 pp acceptance bar, which is not resolvable at this n.
- **Implementation notes.**
  - Day-one side-effect queries:
    `AgentLog.where(name: "InkClusterer::Shadow").waiting_for_approval.count == 0`, the count of
    `AgentLog.where("name LIKE 'CheckInkClustering::%'")` per parent unchanged vs the previous day, and
    `InkReview.where("updated_at > ?", shadow_start).where(agent_approved: true).count` matching the
    prod ReviewApprover run count (i.e. the shadow added zero approvals).
  - The shadow ReviewApprover's `Summarize` tool spawns YoutubeSummarizer/WebPageSummarizer child logs
    under the shadow log via `find_or_create_agent_log(parent)` (`youtube_summarizer.rb:26`,
    `web_page_summarizer.rb:23`); the Q14 override and S25's identity/naming rule for shadow logs cover
    these children too — verify a sample of shadow parent logs actually has DO-model child logs, not
    OpenAI ones, before trusting the weekly report.
  - Cost from data, not from an in-app usage field (Q5):
    `AgentLog.where(name: [shadow names]).where("created_at > ?", start).sum("(usage->>'prompt_tokens')::bigint")`
    times the `lib/bench/pricing.rb` price for the candidate model (kept current by S30).
- **Decisions applied.** Q14, Q5.

### S33-pen-directive-tuning — Pen model config change if S30 picked a different model; tune the PenVariantClusterer directive against the bench; raise the queue depth once the Q27 bar is met

- **Goal.** Three things, in this order: items 1 and 2 are each their own PR; item 3 is an ops action
  (a Fly secret plus one console call), not a PR:

  1. **Model boundary, only if S30 changed the pick.** Under Q32 the pen agents have run on the S01
     starting DO model since S11/S15 merged; S30's chat bench round rebenches `PenVariantClusterer`
     against the full DO candidate list with that model as the baseline column. If S30 picked a
     different model, the **first** PR of this step is a one-line `config/llm.yml` change under the
     `PenVariantClusterer` entry (`model:`, and `api_base:`/`provider:` only if the new model needs a
     different endpoint — same file S04 built, same entry S11 added). Merge it, then **record the merge
     date as a boundary in the drip's per-action approval-rate series** (the same weekly SQL S15's DoD
     introduced): every number before that date is on the old model, every number after is on the new
     one, and the tuning rounds below run only against the final model. If S30 kept the S01 model, skip
     this PR entirely and go straight to tuning.
  2. **Directive tuning.** Using the drip's rejection notes (typed by hand since S15) and the
     round-0/round-1 failure transcripts (S22, S30), iterate the private `system_directive` method and
     the `description "..."` strings of the inner `RubyLLM::Tool` classes in
     `app/agents/pen_variant_clusterer.rb` (built in S11; `app/agents/ink_clusterer.rb` is the shape to
     read) against the bench **dev split**, on the final model (from item 1) and the
     final embeddings (`embedding_v2`, live since S27's read flip). Check the **test split** once per
     accepted change, one PR per change — prod stays at 100% human review throughout, so each merge only
     changes what the human reviewer sees; because the directive change auto-deploys on merge (master
     branch), **the merge date is itself a boundary in the drip's per-action approval-rate series**, same
     as item 1's model change, and both boundaries go in the same table in the pen plan so a reviewer can
     tell which merge caused which shift.

     Tuning rounds are **minor** (Q6): do **not** refresh the whole bench DB copy from prod for this.
     Instead, before each round, pull only the drip's newest rejected `PenVariantClusterer` logs — the
     hard negatives, identified by a non-blank `manual_rejection_note` — directly from
     `PRODUCTION_READONLY_DATABASE_URL` and merge them into the existing bench copy's case set (the same
     mechanism S17 built for minor refreshes: export via the read-only URL, write into `bench/data/`,
     no `pg_dump`/restore into `fountainpencompanion_bench`). Q6 grants only "re-export cases from the
     existing copy", so the limit this creates must be respected and recorded: only clusters that
     already exist in the current bench copy can be re-exported as RUNNABLE cases; prod-side rejections
     on clusters created after refresh #1/#2 supply labels but have no bench-DB rows to run against and
     are deferred to the next major refresh. Keep the rejected-try feedback toggle off
     for these hard-negative cases (Q10's default: `--with-feedback` stays unused here) so the human's
     own rejection note is never leaked back into the case the agent is graded on — that would let the
     agent "cheat" by echoing the note instead of reasoning about the pens.

     Run `bench:run[PenVariantClusterer,<final model>]` (S20's task, dev split) once per candidate
     directive edit, and once more on the test split for any edit that improved the dev split. Record,
     for every merged change: dev-split numbers before/after, test-split numbers (when run), the merge
     date, and the drip's per-action approval rate for the window since the previous merge — all in the
     pen plan's tuning table (new table if S30 didn't already start one for the model comparison).

  3. **Raise the queue depth.** The gate is exactly what Q27 says and nothing more: the depth is raised
     when **the bar the owner set at the end of S15 is met** (recorded there as the Q27 decision,
     alongside its two candidate yardsticks). The two checks below are the implementer's RECOMMENDED
     EVIDENCE to put in front of the owner, not a second gate Q27 imposes:
     - the bench **test split**, on the final model/directive/embeddings, measured against the bar
       (state the split size next to the number — the harness caps ReviewApprover-style
       rounds around 100-200 cases (Q16), but the pen L1 case pool from S21 is larger; use whatever the
       test split actually contains and report the Wilson interval, don't assume n=100);
     - the **live drip**, per action, over a recent window (at least the two weeks since S15, refreshed
       to the most recent weeks if tuning ran long), measured against the same bar with roughly 100
       decisions per action (Wilson interval about ±8 pp at n=100 — state the actual n achieved, don't
       just cite the target).

     Once the bar is met, raise `PEN_CLUSTERING_QUEUE_DEPTH` above 10 to a value the OWNER picks and
     record it — no decision or plan line fixes a post-raise number (Q28 fixes only the starting 10);
     25 is this step's working value, an implementer default, not a decided one. Run
     `flyctl secrets set PEN_CLUSTERING_QUEUE_DEPTH=<new depth> -a fountainpencompanion`
     (restarts every machine, same as S15's depth-10 flip; do it at a quiet hour, or `--stage` it and
     let the next deploy pick it up — a staged secret does NOT take effect, and the depth is NOT
     raised, until that deploy runs, so only proceed once the machines are actually on the new value)
     and, in `fly console`, `TopUpPenClusteringQueue.perform_async` once. Nothing schedules the top-up
     on a cron: it is enqueued only by a human approve/reject (S14), by a finished
     `RunPenClustererAgent` run's `ensure` block, or by `CleanUp::RejectAgentLog` on an orphaned pen
     log (all S13). Right after a depth raise every existing slot is parked in `waiting-for-approval`,
     so none of those fires — hence the same manual kick S15 used. Record the
     date of the raise next to the bar it satisfied. If the bar is not met after a reasonable number of
     tuning rounds, stop: further tuning beyond the target is the pen plan's declared
     out-of-scope follow-up, not this step's job — do not keep iterating indefinitely waiting for a
     number that may never arrive; report the gap and let the owner decide whether to proceed at depth 10
     or adjust the bar.

- **Depends on.** S30 (chat bench round: the model pick, or confirmation the S01 model stands), S22
  (round-0 failure transcripts as tuning input), S15 (the Q27 bar the owner set at the end of the drip's
  first two weeks; this step cannot raise the depth before that bar exists).
- **Why here.** Tuning after both the embeddings (S27) and the chat model (S30) are final means the
  directive is tuned exactly once, against the numbers that will actually run in prod. It is also the
  step that unblocks S38 (pen checkers): the checkers only make sense once L1's own approval rate is
  good enough that auto-approval is worth measuring.
- **Does not include.** The checker agents themselves (S38). Any new trigger or queue-depth-independent
  volume increase (S40/S41). Tuning past the point the bar is met.
- **Definition of done.**
  - For each merged directive change: dev-split and test-split numbers before/after, the merge date, and
    the drip's per-action approval rate for the window since the previous merge, all recorded in the pen
    plan's tuning table.
  - If item 1 ran (a model change): its merge date recorded as its own boundary in the same drip
    statistics table S15 introduced, separate from any directive-change boundary.
  - Depth raised with `flyctl secrets set PEN_CLUSTERING_QUEUE_DEPTH=<new depth> -a fountainpencompanion`,
    the new depth and the date recorded, and the bar it satisfied (which of the two S15 yardsticks, or the
    owner's chosen value) named explicitly next to the record — not just "the bar was met".
  - `TopUpPenClusteringQueue.perform_async` run once from `fly console` after the raise, confirmed to have
    enqueued the expected number of new `RunPenClustererAgent` jobs (the new depth minus whatever was
    already in flight at depth 10) via Sidekiq Web.
- **Decisions applied.** Q32 (prod and bench run the same DO model throughout this step; a picked
  model change from S30 is its own boundary-marking PR before tuning starts, not a parallel-track
  comparison), Q27 (the depth raise is gated on the bar the owner set at the end of S15, checked against
  both the bench test split and the live drip, with the minimum sample size stated next to each check),
  Q6 (tuning rounds are minor refreshes — rejected drip logs pulled from
  `PRODUCTION_READONLY_DATABASE_URL` into the existing bench copy, no full bench-DB re-dump), Q10
  (rejected-try feedback stays hidden by default for these hard-negative cases, so the human's own
  rejection note is never fed back to the agent being graded on it).
- **Implementation notes.**
  - Mechanics: cases and the dev/test split live in gitignored `bench/data` (the pen split is built by
    S21, on the harness S20 built); run
    `bench:run[PenVariantClusterer,<final model>]` on the dev split per iteration and once on the test
    split per accepted change (task names from S20).
  - Target arithmetic: with depth 25 and roughly ten decisions per review batch, the per-action approval
    rate needs about 100 decisions per action before it is meaningfully compared to the Q27 bar (Wilson
    interval about ±8 pp at n=100); state the minimum n achieved next to every number reported, not just
    the target.
  - The tuning table in the pen plan should carry one row per merged PR (model-boundary or
    directive-edit), each with: date, what changed, dev-split before/after, test-split before/after (when
    run), and the drip window's per-action approval rate since the previous row — this is the same shape
    S15's weekly SQL produces, just keyed by merge date instead of calendar week.
  - Do not confuse this step's "minor round" bench refresh (drip rejections only) with S22's or S30's
    "major round" full bench-DB refresh (S17's tooling) — if a full refresh is genuinely needed here
    (e.g. the drip has accumulated enough new labelled clusters that a fresh dump would materially change
    the case pool), that is a deviation from the decided cadence and should be called out explicitly
    rather than done silently.

### S34-embedding-dual-write-off — Turn dual-write off (YAML default), `ignored_columns` for the old vector, specs to 1024 dims

- **Goal.** After the watch week following the read flip (S27) has elapsed and a chat bench round has
  run on the new embeddings (S30) without surprises, on one day and in this order:

  1. **Flip `embeddings.dual_write` to `false`.** This config lives in `config/llm.yml` (added by S24
     alongside `embeddings.legacy`, `embeddings.current` and `embeddings.read`) — it is a YAML value, not
     an ENV var or a Fly secret, so the flip is a one-line PR editing the default under `production:`
     (and `development:`, so local dev stops dual-writing too) plus a deploy. There is no
     `flyctl secrets set` step here at all (that branch only existed in the plan when the flag was
     ENV-backed; Q1 settled the config format as YAML-in-repo, so every flip in this whole migration,
     this one included, is a `git`-reviewable PR). This is safe for the READ column only because S24
     wrote `FetchEmbedding`'s rule against `embeddings.read` rather than against a fixed column name:
     with `read: current` (set by S27) and `dual_write: false`, the worker still writes
     `embedding_v2` on every organic save — it just stops writing the old column. Drain before you
     go further: after merging, wait until the `low` Sidekiq queue holds
     no `FetchEmbedding` or `BackfillEmbeddings` jobs (Sidekiq Web) before doing step 2 — a job still
     writing the old column when `ignored_columns` lands would raise on every attempt.
  2. **Same PR, or the very next one:** add `self.ignored_columns += ["embedding"]` to `InkEmbedding`
     (`app/models/ink_embedding.rb:2`, currently `has_neighbors :embedding`) and to `PenEmbedding`
     (`app/models/pen_embedding.rb:2`, same line shape). Change both `has_neighbors` declarations to
     `has_neighbors :embedding_v2` only — drop `:embedding` from the neighbor call entirely, since an
     ignored column cannot be written or validated through ActiveRecord (neighbor 1.2.0's
     `has_neighbors(*attribute_names, ...)`, `model.rb:3`, validates dimensions per attribute at `:42-57`;
     leaving `:embedding` in the neighbor list while it is also `ignored_columns` would validate an
     attribute ActiveRecord no longer knows how to read).
  3. **Delete the dual-write branch in `FetchEmbedding#perform`** (`app/workers/fetch_embedding.rb`,
     currently 22 lines: `sidekiq_throttle concurrency: { limit: 4 }`, `sidekiq_options queue: "low"`,
     `model.update!(embedding: fetch_embedding)`). An `ignored_columns` entry makes
     `update!(embedding: ...)` raise `ActiveModel::UnknownAttributeError` immediately — so this step is
     not optional cleanup, it is required by step 2: deploying `ignored_columns` while
     `FetchEmbedding` still tries to write the old column would make every job on `low` raise and retry
     (25 attempts, Sidekiq default) until `sidekiq.attempt_threshold: 3` in `config/honeybadger.yml`
     fires. Rewrite the worker to write only the `current` entry's column (`embedding_v2`) through the
     `current` embeddings config (the same explicit-entry client S18/S24 built) — the legacy write and
     the `dual_write` conditional both disappear; there is nothing left to branch on. Keep the same
     `sidekiq_throttle`/`sidekiq_options` lines untouched.
  4. **Update specs to 1024 dims and the new test default.** `spec/workers/fetch_embedding_spec.rb`
     (today: stubs `https://api.openai.com/v1/embeddings` with body
     `{model: "text-embedding-3-small", input: "content"}` and a 1536-float response, asserts
     `embedding.reload.embedding == vector`, lines 3-19) is rewritten to stub the **DO embedding model's**
     endpoint (whatever S23 picked and S24's `embeddings.current` entry names) with a 1024-float response,
     and assert `embedding.reload.embedding_v2 == vector` — this file becomes **the only spec stubbing
     `/v1/embeddings`**. What changes in the `test:` config here is narrow and must be stated exactly,
     because S39 edits the same entries later: this PR repoints ONLY the embeddings test entry's
     `model` and `api_base` at the picked DO model (and the single `/v1/embeddings` stub in this spec
     file), while that entry's `api_key_env` stays `OPEN_AI_EMBEDDINGS` until S39 changes it to
     `DO_INFERENCE_TOKEN`. The chat test defaults (S04's `test:` section) are untouched here and stay
     on OpenAI in both `api_base` and `api_key_env`; do not conflate
     the two — an ink/pen agent spec that stubs `https://api.openai.com/v1/chat/completions` is unaffected
     by this change. Update `spec/lib/embeddings_client_spec.rb` (built/renamed in S18) to expect 1024-float
     vectors and the DO request body. Update the real-vector specs from S09/S24 (the `InkEmbedding`/
     `PenEmbedding` model specs proving per-attribute dimension validation) so every fixture vector is
     1024 floats, and add `spec/factories/ink_embeddings.rb` if S24 has not already added it. Today
     only `spec/factories/pen_embeddings.rb` exists — FOUR lines, an EMPTY `factory :pen_embedding do
... end` with no attributes at all; callers pass `owner:` and `content:` explicitly (see
     spec/workers/fetch_embedding_spec.rb:6). Mirror exactly that empty shape; do NOT declare a
     polymorphic `owner` association in the factory, since FactoryBot cannot resolve one without a
     concrete type.
  5. **Merge.** From here on nothing reads or writes the old `embedding` column, so `OPEN_AI_EMBEDDINGS`
     is no longer read by any code path (it is still a live Fly secret and config entry — retiring the
     secret itself is S39's job, gated on this step being deployed). Neighbor 1.2.0 selects
     `column_names` in `nearest_neighbors` (confirmed at the gem's `model.rb`), so ignored columns are
     excluded from any future neighbor query automatically — no change is needed at the six
     `nearest_neighbors` call sites in `macro_cluster.rb:123,132,143` and `pens/model.rb:38,48,67` beyond
     what S24/S27 already did (those already point at `embedding_v2`; this step does not touch them
     again).

- **Depends on.** S27 (a week elapsed since the read flip, so the watch numbers exist), S30 (a chat bench
  round has run on the new embeddings without surprises — this step is not gated on any pen-side decision,
  only on the ink/embeddings watch).
- **Why here.** First half of the strong_migrations-safe drop of the old column (S35 does the actual
  `DROP COLUMN`); the hard prerequisite for retiring the OpenAI embeddings key (S39). Merging this PR is
  the point where S27's "flip back = one config change" stops being true — after `ignored_columns` lands,
  a rollback needs both a config revert **and** a re-embed of every row touched since dual-write stopped,
  because `FetchEmbedding` no longer writes the old column on every pen/ink save. Prod risk is `medium*`
  for exactly that reason: this PR changes prod behaviour on merge (auto-deploy), and a botched ordering
  (step 2 before step 1's queue-drain check) makes every embedding save fail.
- **Does not include.** The `DROP COLUMN` itself and the HNSW index removal (S35, next deploy). Any
  rename of `embedding_v2` (Q31: it keeps this name forever — there is no future step that revisits this).
- **Definition of done.**
  - Pre-flight, run against `PRODUCTION_READONLY_DATABASE_URL` before merging step 2:
    `SELECT count(*) FROM ink_embeddings WHERE embedding_v2 IS NULL` and the same for `pen_embeddings`
    both return 0 (otherwise some rows would be left with neither vector once the old column stops being
    writable) — if either is nonzero, run one more `BackfillEmbeddings` sweep (S24's self-chaining worker)
    before proceeding. Also confirm Sidekiq Web shows the `low` queue empty of `FetchEmbedding` and
    `BackfillEmbeddings` entries at the moment `dual_write` flips.
  - Full suite green on 1024-dim fixtures throughout.
  - `grep -rn ":embedding\b\|embedding:" app lib` returns nothing except the cache-key line in
    `app/lib/embeddings_client.rb` (`"embedding:#{digest}"`), which is a Rails.cache key and not an
    attribute reference. Separately, `grep -rn 'ignored_columns' app/models` returns exactly the two
    lines in `ink_embedding.rb` and `pen_embedding.rb` (the literal written there is
    `self.ignored_columns += ["embedding"]`, which matches neither half of the first pattern).
  - `grep -rn "nearest_neighbors(:embedding," app` returns nothing: all SIX call sites
    (`app/models/pens/model.rb:38,48,67` and `app/models/macro_cluster.rb:123,132,143`) already read
    `:embedding_v2` from S24/S27; this grep is a regression check, not new work.
  - Runbook entry in the pen/migration plan's "Runbook" section (the heading S05 seeded): rollback after
    this step = `git revert` the PR (restores `has_neighbors :embedding, :embedding_v2` and the dual-write
    path in `FetchEmbedding`) **and** re-embed every `ink_embeddings`/`pen_embeddings` row whose
    `updated_at` is later than the moment dual-write was switched off, through the old `legacy` model —
    give `BackfillEmbeddings` a `column:` parameter for this if it does not already take one from S24, or
    accept stale old vectors for that window. State explicitly: "re-enable dual-write alone does not
    restore the old column's data" — this is not a symmetrical flip like S27's read flip was.
- **Decisions applied.** Q1 (the flip is a one-line PR to the YAML default, never an ENV var or a
  `flyctl secrets set` step — there is no ENV-backed branch to consider here at all), Q31 (the column
  stays `embedding_v2` forever; nothing in this step anticipates or prepares for a rename — the "if Q31 =
  (b)" branch from the v1 text does not apply and is not written here).
- **Implementation notes.**
  - Ordering matters and is the whole risk of this step: flip the config (1) → confirm the queue is
    drained → land `ignored_columns` and rewrite `FetchEmbedding` together in the same deploy (2+3) —
    never deploy `ignored_columns` first while a stray dual-writing job could still be in flight.
  - Because `ignored_columns` and the `FetchEmbedding` rewrite are tightly coupled (one cannot ship
    without the other), do not split them into separate PRs the way S24's runbook split the dual-write
    flip from the backfill start — land them together.
  - The spec for `FetchEmbedding` should assert only one HTTP call is made per run (the legacy call is
    gone entirely, not merely skipped) — a lingering "and no request to text-embedding-3-small" assertion
    is a good regression guard against accidentally leaving old code behind.

### S35-drop-old-embedding-column — Drop the old HNSW indexes and `embedding` columns after a backup point check; the column stays `embedding_v2`

- **Goal.** Confirm a DO managed-Postgres backup / PITR point exists and note its retention window in
  the PR (S00 recorded how to check this: the DO control panel; after the window elapses the old 1536-dim
  vectors are gone for good, and a rollback at that point means a full re-embed through OpenAI — whose
  keys are still present at this point in the plan, since S39 retires them only after this step). Then a
  migration:

  - `disable_ddl_transaction!` at the top of the migration class (required because
    `algorithm: :concurrently` cannot run inside a transaction).
  - `remove_index :ink_embeddings, name: "index_ink_embeddings_on_embedding", algorithm: :concurrently, if_exists: true`
    and the equivalent for `pen_embeddings`
    (`name: "index_pen_embeddings_on_embedding"`) — these are the two HNSW indexes still present in
    `db/structure.sql` (`index_ink_embeddings_on_embedding` and `index_pen_embeddings_on_embedding`, both
    `CREATE INDEX ... USING hnsw (embedding public.vector_cosine_ops)`, at `db/structure.sql:1911` and
    `:2065`).
  - `safety_assured { remove_column :ink_embeddings, :embedding, if_exists: true }` and
    `safety_assured { remove_column :pen_embeddings, :embedding, if_exists: true }` (the table is
    `pen_embeddings`; there is no `pens_embeddings`) — strong_migrations 2.8.0's `checks.rb:412-441`
    always raises on a bare `remove_column` (needs `safety_assured`) and `checks.rb:443-462` separately
    requires `algorithm: :concurrently` on `remove_index`; both guards apply here, hence the two different mitigations in the same migration.
  - `DROP COLUMN` takes an ACCESS EXCLUSIVE lock. `config/initializers/strong_migrations.rb` sets
    `StrongMigrations.lock_timeout = 10.seconds` at `config/initializers/strong_migrations.rb:3` and
    does NOT set `lock_timeout_retries`, so the gem default of 0 retries applies: ONE failed lock
    acquisition aborts the release command. A running public pen search (`PenModelsController`, covered
    by S09's request spec) holding a read lock on the table can make the DDL miss its lock window.
    Mitigate either by merging at a quiet hour — pick it the way S26 did, by checking recent traffic
    graphs and deploy history first; neither S15 nor S27 records a fixed low-traffic window — or by
    setting `StrongMigrations.lock_timeout_retries` for this deploy. If the release command's migration
    step fails on the lock, it is safe to simply re-trigger the release: every statement here is
    idempotent via `if_exists: true`, so a partial prior run cannot corrupt state.
  - Remove `ignored_columns` from `InkEmbedding`/`PenEmbedding` in the **same PR** as the `remove_column`
    migration (Rails' release command runs `db:migrate` before the new code boots, per `fly.toml`'s
    `release_command = 'bundle exec rake db:migrate db:seed'`, so the column is already gone by the time
    the ignored-columns line would otherwise still be needed — leaving it in place afterward is dead
    code, not a safety net).
  - What this frees: the two HNSW indexes (roughly 3.5 GB combined: 2,184 MB ink + 1,336 MB pen, from
    `pg_relation_size(indexrelid)` on the read-only URL) are freed immediately on `DROP INDEX`. The
    roughly 8.2 GB of old-vector TOAST storage (ink ~6,376 MB + pen ~1,822 MB, from
    `pg_relation_size(reltoastrelid)`) is **not** freed by `DROP COLUMN` alone — PostgreSQL only marks the
    column dropped in the catalog; existing tuples keep their TOAST pointers until the table is physically
    rewritten. **Decided: accept the dead space** (section 4: "the ~8.2 GB of old-vector TOAST stays
    until a table rewrite; S35 records the decision") — autovacuum and normal table growth reclaim it
    opportunistically. The other two are fallbacks, taken only if disk pressure forces them; whichever
    is actually taken is recorded in the PR:
    - `VACUUM FULL ink_embeddings; VACUUM FULL pen_embeddings;` off-peak — reclaims the space immediately,
      but takes an ACCESS EXCLUSIVE lock for the entire rewrite (blocking `embedding_search` and the
      public pen search meanwhile), needs free disk roughly equal to the table's current size, and
      rebuilds the `embedding_v2` HNSW index at whatever `maintenance_work_mem` the session has (unlike
      S26's by-hand build, this happens inside whatever session runs the `VACUUM FULL`, so set
      `maintenance_work_mem` there too if you want the same fast rebuild).
    - `CREATE EXTENSION pg_repack` via the DO console (present in `pg_available_extensions` but not
      currently installed) and repack the tables online — avoids the long exclusive lock, at the cost of
      needing roughly double the table's disk space temporarily and being a manual, un-migrated operation
      (record exactly what was run and when, since it leaves no trace in `structure.sql`).
    - Accept the dead space and let normal autovacuum/table growth reclaim it opportunistically over
      time — this is the decision, not one of three open options; the two above are the fallbacks if
      disk pressure makes a rewrite necessary.
  - The column keeps its name, `embedding_v2`, forever (Q31: there is no rename step anywhere in this
    plan, and no "S34b" of any kind exists — do not schedule one, do not leave a TODO for one).

- **Depends on.** S34 (deployed: dual-write off, `ignored_columns` live, specs on 1024 dims).
- **Why here.** Irreversible past the backup window, so it runs only after both the read-flip watch week
  (S27) and a full chat bench round on the new embeddings (S30, transitively required by S34) have shown
  no reason to go back to the old column.
- **Does not include.** Any rename (Q31 — permanently out of scope, not deferred).
- **Definition of done.**
  - `structure.sql` regenerated inside the app container (`docker-compose exec app bin/rails
db:schema:dump` — the project sets `config.active_record.schema_format = :sql` at
    `config/application.rb:30`, so this is the task that writes `db/structure.sql`; `bin/rails
db:migrate` regenerates it too. `db:structure:dump` does NOT exist in Rails 8. Never hand-edit it,
    never run the dump on the host.
  - `grep -c 'vector(1536)' db/structure.sql` is 0.
  - `grep -c 'index_ink_embeddings_on_embedding\b' db/structure.sql` is 0 (and the same for the pen
    index name).
  - Full suite green, with the S24 dimension specs (narrowed to 1024 dims in S34) now exercising only
    the 1024-dim column (there is no
    1536-dim path left anywhere to accidentally exercise).
  - Index sizes before/after recorded in the PR (expect the roughly 3.5 GB combined drop from the two
    HNSW indexes).
  - The TOAST-reclaim decision (`VACUUM FULL`, `pg_repack`, or accept) recorded in the PR alongside the
    backup point and its PITR retention window.
- **Decisions applied.** Q31 (the column stays `embedding_v2` forever — the "if Q31 = (b), schedule a
  further rename step" branch from the v1 text does not apply; no rename ever happens). The backup /
  PITR check is not Q30 (which covers only the by-hand HNSW build): it is the S00 prerequisite item
  "DB backup check" (section 1, row 0), whose recorded procedure this step follows.
- **Implementation notes.**
  - Evidence queries against the read-only URL:
    - Before: `SELECT pg_size_pretty(pg_relation_size(indexrelid)) FROM pg_stat_user_indexes WHERE indexrelname IN ('index_ink_embeddings_on_embedding','index_pen_embeddings_on_embedding')`.
    - After: `SELECT attname, attisdropped FROM pg_attribute WHERE attrelid='public.ink_embeddings'::regclass AND attnum>0`
      (expect a row like `........pg.dropped.3........ | t` for the dropped column — the attribute stays
      in the catalog, invisible to ordinary queries, until a rewrite) and
      `SELECT pg_size_pretty(pg_relation_size(reltoastrelid)) FROM pg_class WHERE relname='ink_embeddings'`
      (expect this to stay roughly unchanged, around 6.4 GB, unless the `VACUUM FULL`/`pg_repack` option
      was taken).
  - Because this migration and the `ignored_columns` removal ship together, there is a short window
    between "the PR merges" and "the release command finishes" during which running application code
    (old Puma/Sidekiq processes, before they restart) still references `ignored_columns`-excluded
    `:embedding` reads that no longer matter (the column read simply returns nothing useful, never an
    error, since ActiveRecord already stopped selecting it in S34) — no special handling is needed for
    this window beyond the normal Fly deploy sequencing.
  - Sanity-check `PenModelsController`'s public search (covered by S09's request spec) and
    `embedding_search` right after the deploy finishes, since these are exactly what a lock-timeout
    collision during the migration would have blocked.

### S36-pen-model-clusterer-wiring — L2 approve/reject (collision refusal), trigger with guards behind PEN_CLUSTERING_L2_ENABLED, admin page + badge/filter marker, RunFailedClusterJobs, full cascade

- **Goal.** `PenModelClusterer#approve!`/`reject!` (assign -> `pens_model_id` +
  `Pens::UpdateModelMicroCluster`; create -> `Pens::Model.create!(brand:, model:)` seeded with the
  most common (brand, model) over the mmc's variants' collected pens, reusing the `best_attr_value`
  logic from `Pens::UpdateModel` (app/workers/pens/update_model.rb:32-50; `pens_models.brand`/`.model`
  are NOT NULL, db/structure.sql:961-962, and `Pens::UpdateModel#perform` returns early when
  `model.collected_pens.empty?`, update_model.rb:7, so the model must be created with real values and
  linked to the mmc before it can re-derive anything), then `mmc.update!(pens_model_id:)` and
  `Pens::UpdateModelMicroCluster.perform_async(mmc.id)` (runs UpdateModel -> AssignBrand and the
  embedding). On create, `approve!` rescues `ActiveRecord::RecordNotUnique` by REFUSING the approval
  and REJECTING the log, exactly like the stale-approval rule (Q20) — never by silently finding the
  existing model and assigning to it. Fix the `retried = false`-inside-`begin` bug in
  `Pens::UpdateModel#update_attributes!` (update_model.rb:18-30, the local is reassigned inside the
  rescued block so a second `RecordNotUnique` would `retry` forever instead of raising) while touching
  that code.
  Trigger: `Pens::UpdateModelMicroCluster#perform` enqueues
  `RunPenClustererAgent.perform_async("PenModelClusterer", cluster.id)` when `pens_model_id` is nil.
  Gotcha: that method today is `cluster = Pens::ModelMicroCluster.find(id); return unless
cluster.pens_model_id; Pens::UpdateModel.perform_async(cluster.pens_model_id)` — the existing guard
  at app/workers/pens/update_model_micro_cluster.rb:7 returns early in EXACTLY the case the new branch
  needs, so appending to the body produces dead code that never fires (and test case (1) below would
  fail with no hint why). Put the new branch BEFORE it: `if cluster.pens_model_id.nil? then <guards +
enqueue>; return; end`, followed by the unchanged `Pens::UpdateModel.perform_async` path. The branch
  runs when
  `PEN_CLUSTERING_L2_ENABLED` is on (own boolean flag, `ENV.fetch("PEN_CLUSTERING_L2_ENABLED",
"false")`, default off — see the roadmap's "Resolved without asking" list) and the guards pass: skip
  ignored, skip model micro clusters with no variants, skip when a log is in flight
  (`agent_logs.where(name: "PenModelClusterer", state: [processing, waiting-for-approval]).exists?`,
  mirroring ink_clusterer.rb:279-290; the worker runs on every collected-pen save through
  `UpdateModelVariant -> AssignModelMicroCluster`, not only when L1 creates a variant). As for inks, a
  handed-over mmc re-runs on the next pen save in it (approved logs do not block). **Decided: L2 has
  NO hand-over exclusion.** Q23's exclusion is scoped to the L1 TOP-UP refill, and L2 has no top-up —
  it is not queue-limited (pen decision 2) and every L2 decision is human-reviewed, so a re-run on a
  handed-over mmc costs one cheap decision a human sees anyway. Do not add a latest-log hand-over
  guard here. The shared `RunPenClustererAgent`
  slot means L1 and L2 never run concurrently, which keeps the Sidekiq thread budget unchanged (Q35).
  Race fix in `Pens::AssignModelMicroCluster#perform` (app/workers/pens/assign_model_micro_cluster.rb:7,
  unique index db/structure.sql:1722, pre-existing): wrap `find_or_create_by!` in
  `rescue ActiveRecord::RecordNotUnique` and retry once with `find_by!(cluster_attributes)`.
  The cross-level rejection cascade (Q21) is decided as fact: "destroy the now-empty model micro
  cluster, reject any L2 log on it, re-run the model update or destroy an empty model". The
  implementation refines the ORDER — this refinement is the roadmap's, not Q21's own wording:
  rejecting an approved L1 create first REJECTS any in-flight (`processing`/`waiting-for-approval`)
  `PenModelClusterer` log on the mmc — so the L2 review queue and the dashboard count drop
  immediately — and THEN destroys the now-empty model micro cluster, which also destroys those log
  rows through the `has_many :agent_logs, as: :owner, dependent: :destroy` S06 added (copied from
  app/models/micro_cluster.rb:6). Said plainly: Q21's "reject any L2 log" leaves no surviving row —
  the rejection is there to make the queue and the dashboard correct at that instant, and the row is
  then deleted with its owner, which is why the spec asserts
  `AgentLog.where(name: "PenModelClusterer", owner_id: mmc_id).none?` afterwards. Q37's "keep all
  agent_log history" is about not TRIMMING logs, not about surviving the cascade delete of a cluster
  that no longer exists. Finally it either re-runs
  `Pens::UpdateModel` on the model (if it still has other model micro clusters/pens) or destroys the
  model when it is left empty. The objects involved: `Pens::AssignModelMicroCluster` does
  `find_or_create_by!` then `model_variant.update!(model_micro_cluster:)`; `Pens::ModelVariant
belongs_to :model_micro_cluster` is optional with no `dependent:` (model_variant.rb:9-12);
  `Pens::ModelMicroCluster has_many :model_variants, dependent: :nullify` (:2-5) — destroying a variant
  never touches the mmc on its own, so the cascade must do it explicitly in `PenVariantClusterer#reject!`
  (S12) or in a small shared helper it calls.
  Admin controller reuses the S14 partial, `AdminStats#pens_model_micro_cluster_agent_review_count`
  (waiting + processing, consistent with S14's L1 count; ink template app/models/admin_stats.rb:14-21).
  Both the rendered relation AND the count apply `.owner_with_model_variants` (S06's L2 twin of
  `owner_with_collected_pens`), applied AFTER any `.or(...)`, exactly as S14 requires for L1 — Q8 keeps
  the 349 empty ASSIGNED model micro clusters in the database and requires filtering them out of every
  query and count
  and a sibling span in app/views/admins/dashboards/show.html.slim:44; `RunFailedClusterJobs` gains a
  `PenModelClusterer` branch dispatching to the same worker (extend the S13 spec). L2 React marker and
  guidance logs mirror S16's L1 shape exactly: `PensModelMicroClusterSerializer` gains
  `pending_agent_log` and `handed_over` attributes: `pending_agent_log` = a
  `processing`/`waiting-for-approval` `PenModelClusterer` log exists; `handed_over` = the cluster's
  **LATEST** `PenModelClusterer` log is `approved` with
  `extra_data->>'action' = 'hand_over_to_human'` — the same latest-log semantics as S16's L1 pair
  (Q26), computed over `PenModelClusterer` logs. L2 has no `TopUpPenClusteringQueue` exclusion to
  reuse, so write the scope on `Pens::ModelMicroCluster` next to S16's L1 equivalent and the `pens-model-micro-clusters` React list shows the same
  badge and the same two filters as S16's `pens-micro-clusters` list;
  `Admins::Pens::ModelMicroClustersController#update`/`#unassign` write the synthetic REJECTED guidance
  log the same way S14 does for L1 — but through an L2 helper of this step's own, NOT S12's:
  `model_micro_cluster.agent_logs.create!(name: "PenModelClusterer", state: AgentLog::REJECTED,
rejected_at: Time.current, agent_approved: false, extra_data: { "action" => "assign_to_model",
"model_id" => previous_model_id }` / `{ "action" => "ignore" })`. S12's helper hard-codes
  `name: "PenVariantClusterer"`, and reusing it here would stamp L1-named logs onto
  `Pens::ModelMicroCluster` owners, polluting every by-name L1 query (S13's depth count and
  `handed_over_to_human_ids`, S14's queue relation and presenter population) with rows of the wrong
  owner type. (Today `#update`
  enqueues `UpdateModelMicroCluster`, :35, and
  `#unassign` enqueues only `UpdateModel(old)`, :44; make `#unassign` also enqueue
  `UpdateModelMicroCluster` so the agent re-runs with the guidance, matching the L1 behaviour.) Not
  queue-limited (pen decision 2), every decision human-reviewed — there is no L2 checker (that is
  S38's L1-only scope).
  If S30 (chat-bench-round) picked a different chat model for `PenModelClusterer` than the model S01
  started it on, this PR is also where the `config/llm.yml` entry for `PenModelClusterer` is updated
  to that pick (Q32); record the merge date as a boundary the way S33 records its own model-pick
  boundary for L1.
- **Depends on.** S29 (agent), S14 (partial, guidance-log pattern), S13 (dispatch pattern), S12 (L1
  reject path it extends).
- **Why here.** Volume is zero today (prod: 0 unassigned, non-ignored model micro clusters with
  variants), so the model choice is irrelevant for cost and the step simply fills the two-week shadow
  wait (S32); the cascade decision is needed before L1 creates are approved at scale.
- **Does not include.** Checkers for L2 (S38 covers L1 checkers only; there is no L2 checker in this
  roadmap).
  **`reject!` (L2), the mirror of S12's L1 contract** (pen plan P3: "same shape as P1"): an approved
  `assign` is reversed by nulling `pens_model_id` and re-running `Pens::UpdateModel` on the OLD model;
  an approved `create` destroys the created `Pens::Model` if this mmc is the only one pointing at it
  (otherwise it only unassigns); an approved `ignore` sets `ignored: false`. `reject!` returns the
  model micro clusters to re-run (this one plus any freed by destroying a model), filtered to drop
  variant-less ones. A rejected log carrying a `manual_rejection_note` feeds the next attempt exactly
  like `processed_tries_data` does at L1.
- **Definition of done.** Specs for guards, race, cascade, approve/reject (including all three
  `reject!` branches and the note-feedback path), admin, serializer; flag off
  by default, then set on; the first N decisions (whenever L1 creates a new brand+model) reviewed by
  hand. Split if wanted: (a) approve!/reject! + cascade + specs, (b)
  trigger/guards/race/RunFailedClusterJobs + admin + serializer marker.
- **Decisions applied.** Q21 (full cross-level cascade), Q20 (create-collision refusal, same rule as
  L1), Q22 (a refused approval is a plain rejection — no tag, no stats work, no React auto-reject
  hook), Q26 (L2 marker = badge + the same two filters as L1, shipped in this same PR since there is no
  separate "drip" gate for L2), Q32 (chat model for `PenModelClusterer` is a `config/llm.yml` entry from
  S29 on; any change from the S30 pick lands here as a config-only PR).
- **Implementation notes.**
  - Test cases: (1) `Pens::UpdateModelMicroCluster` with `pens_model_id` nil and flag off enqueues
    nothing; flag on enqueues exactly one `RunPenClustererAgent` job with
    `["PenModelClusterer", id]`; (2) ignored mmc, mmc without variants, mmc with a
    waiting/processing `PenModelClusterer` log each enqueue nothing; (3) `Pens::AssignModelMicroCluster`
    when `find_or_create_by!` raises `RecordNotUnique` once assigns the existing mmc; (4) `approve!`
    for a create when `(brand, model)` already exists (simulate the race by stubbing `create!` to raise
    `RecordNotUnique`) rejects the log and leaves no new `Pens::Model` row, asserting the same shape as
    S12's L1 collision-refusal spec; (5) cascade: L1 create approved -> variant -> mmc -> L2 assign
    approved -> L1 rejected: assert the mmc row is gone,
    `AgentLog.where(name: "PenModelClusterer", owner_id: mmc_id).none?` (the cascade delete follows the
    rejection — do not assert a surviving `rejected` row, `dependent: :destroy` removes it), and the
    model is either re-derived (still has pens elsewhere) or destroyed (left with none); (6)
    `RunFailedClusterJobs` restarts a stale `PenModelClusterer` log through the pen worker and still
    ignores other names; (7) the L2 dashboard count counts waiting + processing consistently with S14's
    L1 count; (8) serializer spec: `pending_agent_log` and `handed_over` attributes match the same
    truth table as S16's L1 serializer spec; (9) request spec per React filter
    (`pending=true`/`handed_over=true`) on the model-micro-clusters index action.
  - Smoke path on the dev copy: S08 deletes the 69 empty unassigned mmcs and prod has 0 non-empty
    unassigned ones, so pick an assigned mmc on the dev copy, `update!(pens_model_id: nil)` there, then
    run `Pens::UpdateModelMicroCluster.new.perform(id)` with the flag on and Sidekiq inline; never on
    prod.

### S37-chat-cutover-final — Flip InkClusterer and ReviewApprover after shadow results, CheckInkClustering::* on the bench result

- **Goal.** If the shadow report (S32, run for about two weeks) meets S32's go/no-go criterion — "no
  drift": the shadow agreement interval overlaps the bench agreement interval for the same model (from
  S30), NOT the 1 pp acceptance bar, which is not resolvable at this n — flip InkClusterer and
  ReviewApprover; flip CheckInkClustering::*
  on the S30 bench result alone (they were never shadowed, per the decision "Shadow phase: InkClusterer
  and ReviewApprover"), ideally a few days after InkClusterer so a regression can be attributed to one
  agent. Remove the shadow config in the same PR as the flip — the `shadow:` block lives in
  `config/llm.yml` (S25/S32), so removing it is part of the flip PR and never a Fly secret edit (after the flip the prod
  model is the candidate, so an un-removed shadow entry would run the candidate twice per cluster).
  Pre-flight as in S31, made implementable: merge in a quiet hour (prod data: fewest InkClusterer runs
  02:00-08:00 UTC; hourly peaks at 11:00 and 20:00-23:00 UTC), re-run
  `SELECT id, name FROM agent_logs WHERE state='processing'` on the read-only URL right after the
  deploy finishes, and for any hit watch that log's next attempt in Honeybadger; the S01 replay check
  is the real safety net. Watch for a week with three SQL-backed numbers, each compared with the same
  window before the flip (not with all-time figures): (1) InkClusterer human approval = `agent_logs`
  name='InkClusterer', state in ('approved','rejected'), agent_approved=false, created_at > flip; (2)
  checker agreement = `extra_data->>'follow_up_action'` vs final state on those logs (the ink view's
  formula, index.html.slim:29-39); (3) ReviewApprover agreement, whose verdicts live in `ink_reviews`,
  not `agent_logs.state` (95% over the last 90 days) — the query, inlined here because the prod data
  check is a scratchpad document the implementer does not have:
  `SELECT l.extra_data->>'action', CASE WHEN r.approved_at IS NOT NULL THEN 'approved' WHEN r.rejected_at IS NOT NULL THEN 'rejected' ELSE 'pending' END, r.agent_approved, r.auto_approved, count(*) FROM agent_logs l LEFT JOIN ink_reviews r ON r.id = l.owner_id WHERE l.name = 'ReviewApprover' AND l.created_at > '<flip timestamp>' GROUP BY 1, 2, 3, 4`,
  restricted to human-confirmed rows (`agent_approved = false AND auto_approved = false`). The owner must clear the post-hoc review queue for (1) and (2) to have an n (prod,
  last 30 days: 699 agent-processed vs 297 human-processed InkClusterer logs; 663 checker decisions
  await human confirmation). Exclude the shadow logs' distinct names from these statistics.
  There is no pen agent to flip in this step: under Q32 the pen stack (L1, and L2 once S36 wires it) has
  been running on DigitalOcean since the drip started in S15, and there is no later pen cutover
  anywhere in this roadmap — this step is ink-only.
- **Depends on.** S32 (two weeks of shadow results), S31 (wave-1 cutover already shipped and settled).
- **Why here.** Last migration prod change for the ink agents, gated on shadow evidence as decided.
- **Does not include.** Key retirement (S39).
- **Definition of done.** InkClusterer, ReviewApprover and the four `CheckInkClustering::*` on DO per
  the config; a week of the three
  numbers recorded; rollback = flip back via `git revert` + merge (OpenAI keys still present until
  S39; a flip-back replays DO tool-call ids against OpenAI, which S01 item 3 verified, otherwise the
  runbook says "processing logs are left to fail and be re-run").
- **Decisions applied.** Q32 (no pen agent is flipped here; the pen stack has been DO-only since S15,
  so this step's scope and dependencies drop every pen reference v1 carried), Q1 (the flip is a
  `config/llm.yml` PR; rollback is `git revert` + merge, not a secret edit).
- **Implementation notes.**
  - `SELECT name, count(*) FROM agent_logs WHERE state='processing' GROUP BY 1` (expect none for the
    flipped agent) and
    `SELECT usage->>'model', count(*) FROM agent_logs WHERE name='InkClusterer' AND created_at > now() - interval '1 day' GROUP BY 1`
    to prove traffic moved.

### S38-pen-checkers — CheckPenClustering::{Assign,Create,Ignore,Human} behind PEN_CLUSTERING_CHECKERS_ENABLED, follow-up dispatch, auto-approval, admin percentages

- **Goal.** Copy `CheckInkClustering::*` with pen tools and prompt (fix the misnamed `Ignore` tool
  classes `ApproveClusterCreation`/`RejectClusterCreation` in the copy, app/agents/check_ink_clustering/ignore.rb:2,24
  — for the pen `Ignore` checker they should be named for what they approve/reject, e.g.
  `ApproveIgnore`/`RejectIgnore` — renaming the classes also renames the TOOL CALLS, because
  `config/initializers/ruby_llm.rb:8-22` demodulizes and underscores the class name and there is no
  `def name` anywhere in app/agents/check_ink_clustering/ (S03), so the directive text and the
  `tool_calls` fixtures in the copied `ignore_spec.rb` must use `approve_ignore`/`reject_ignore`; no
  `def name` override is needed). The copy needs the dispatch that makes a checker run at all, which
  no earlier pen step created: `PenVariantClusterer#schedule_follow_up!` (copy of
  ink_clusterer.rb:207-232: `assign_to_variant -> CheckPenClustering::Assign`,
  `create_new_variant -> ::Create`, `ignore_pen -> ::Ignore`, `hand_over_to_human -> ::Human`; writes
  `extra_data[:follow_up_agent]`; enqueues
  `RunPenClustererAgent.perform_async(checker_class_name, agent_log.id)` so the checker shares the L1
  throttle slot as inks do; `RunPenClustererAgent#perform(klass, *)` dispatches by class name like
  `RunInkClustererAgent`), gated by `PEN_CLUSTERING_CHECKERS_ENABLED` read as
  `ENV.fetch("PEN_CLUSTERING_CHECKERS_ENABLED", "false")` (same stub convention as S13): the ink code
  calls `schedule_follow_up!` unconditionally after every decision (ink_clusterer.rb:190-191) and
  master auto-deploys, so a literal copy would start auto-approving pen decisions the moment the PR
  merges; when the flag is off, the log stays `waiting-for-approval` for the human exactly as in S15.
  Four substitution points beyond tools and prompt text: `micro_cluster_data`
  (app/agents/check_ink_clustering/base.rb:120-128 uses `all_names`, `all_names_as_elements`, `colors`,
  which `Pens::MicroCluster` lacks: use the S06 tuple helper, the same one S11's prompt-building code
  uses); `micro_cluster.collected_inks.present?` -> `collected_pens.present?` in TWO places —
  app/agents/check_ink_clustering/base.rb:30 (`Base#perform`) and
  app/agents/check_ink_clustering/human.rb:45 (`Human#perform`, which overrides `perform` and repeats
  the guard; miss it and `CheckPenClustering::Human` raises `NoMethodError` on a `Pens::MicroCluster`
  at run time); Assign's
  `extra_context` (app/agents/check_ink_clustering/assign.rb:91
  `MacroCluster.find(extra_data["cluster_id"])`) -> `Pens::ModelVariant.find(extra_data["variant_id"])`
  plus its parent `Pens::Model` name and its sibling variants (the pen plan: the agent must see that
  Safari Petrol and Safari Dark Lilac are siblings; the ink Assign only shows the macro cluster's
  names, assign.rb:80-88); Human's PreviousAgentLogs unchanged
  (app/agents/check_ink_clustering/human.rb:24-28, needs S06's `agent_logs` association on the pen
  models). The empty-cluster branch `reject_empty_micro_cluster!` (base.rb:53-63) keeps the ink SHAPE
  exactly — the CHILD log is annotated (`"action" => "reject"` plus the explanation) and finalised
  with `approve_by_agent!`, the parent is annotated, then `micro_cluster_agent_log.reject!` — and adds
  ONE thing for Q19 consistency: merge `"auto_rejection" => "empty_cluster"` into the PARENT
  `PenVariantClusterer` log's `extra_data` BEFORE `reject!`. The parent is where the tag has to go:
  S14's presenter population is the latest 500 manually processed `PenVariantClusterer` logs minus
  rows with `extra_data->>'auto_rejection'`, so a tag on the child would exclude nothing (child logs
  are named `CheckPenClustering::*` and are already outside that by-name population). With the parent
  tagged, the single `auto_rejection` filter covers S11's marker log, S13's `CleanUp` orphan
  rejections and this branch alike.
  Child logs live under the parent; the verdict is copied to the parent's `follow_up_*` fields;
  `execute_decision!` calls `PenVariantClusterer.new(micro_cluster_id, agent_log_id: parent.id).approve!(agent: true)`
  / `reject!(agent: true)` (S12's method signatures; the ink `execute_decision!` is base.rb:96-110,
  with the `approve!` call at :98-100). `execute_decision!`
  treats a refused approval (S12's collision-refusal / stale-approval path) as the plain rejection it
  already is (Q22): no extra tag, no stats-exclusion work, no special flash handling — it just becomes
  a rejected checker log like any other. On a checker reject, re-run the owning micro cluster directly
  through `RunPenClustererAgent`. This one direct enqueue is the decided exception to the pull-based
  rule, and its bound is what makes it safe: the rejection frees exactly the one waiting slot this
  enqueue re-fills, so it cannot overshoot `PEN_CLUSTERING_QUEUE_DEPTH`. Everything else goes through
  the queue: the sibling clusters `reject!` returns are DISCARDED, exactly as S14's controller
  discards them, and one argument-less `TopUpPenClusteringQueue.perform_async` is enqueued — nothing
  is "handed to" that worker, it takes no cluster argument; the siblings simply become eligible again
  at the next priority-ordered refill. (The ink checker re-enqueues every returned cluster directly,
  base.rb:106-108, bypassing any gate — the pen copy must not, so S13's depth cap still holds.) The
  pen copy of `schedule_follow_up!` (ink_clusterer.rb:207-232) has the same rule applied to its `else`
  branch: where the ink version does `agent_log.destroy; RunInkClustererAgent.perform_async(...)` for
  a log with no `extra_data`, the pen version destroys the log and enqueues one argument-less
  `TopUpPenClusteringQueue.perform_async` instead — that path frees no slot of its own, so a direct
  re-enqueue there WOULD overshoot the cap.
  `CheckPenClustering::Human` copies the ink behaviour exactly (Q34(i)): it emails hello@ and approves
  the parent log with `agent_approved: false` (same as `CheckInkClustering::Human`), but — unlike the
  ink version, which leaves its own child log sitting in `waiting-for-approval` forever (245
  `CheckInkClustering::Human` logs on prod, 0 in any other state) — the pen copy also finalises its own
  child log with `agent_log.approve_by_agent!` — `agent_approved: true`, because no human reviewed
  the CHILD (app/models/agent_log.rb:51-53), as opposed to the PARENT, which gets the plain
  `approve!` and its `agent_approved: false` (agent_log.rb:47-49) that Q34(i) requires. Getting these
  two the wrong way round pollutes the `manually_processed` scope (agent_log.rb:32) that Q25(i)'s
  presenter population is built on, so assert both flags in a spec. With this, `CheckPenClustering::Human`
  logs do not pile up unresolved the way the ink ones did.
  Depth: no change to S13's by-name waiting+processing count (agent-approved parents leave the waiting
  state via `AgentLog#approve_by_agent!`, app/models/agent_log.rb:51-53; checker children are parked
  `waiting-for-approval` for good under name `CheckPenClustering::*`, so the by-name count already
  excludes them by construction). Review queue: no relation change is needed — S14 already ships
  `@agent_logs` as waiting + processing `.or(AgentLog.pen_variant_clusterer.agent_processed)` with
  `.owner_with_collected_pens` applied AFTER the `.or`, and the `agent_processed` branch was put there
  for exactly this moment. What changes here is that the branch finally has rows: agent-decided parents
  SHOW on the human review page for spot checks, and those spot checks
  feed the "correct auto review" percentages. `@queue_length`, the page title and
  `AdminStats#pens_micro_cluster_agent_review_count` keep counting waiting + processing only (Q24(ii)).
  Update S14's request-spec assertion accordingly: with one waiting, one processing and one
  `agent_processed` log, `queue_length == 2` while three logs are listed. The S14
  partial/controller must honour `follow_up_agent`/`follow_up_done` for the 3-second refresh
  (controller:6-13) and treat a rejected child as done (`CleanUp` rejects a stuck checker child after
  3 h but leaves the parent waiting with `follow_up_done` false, which would otherwise refresh the page
  forever). "Correct auto review" percentages are computed via the S14 presenter (the same one that
  already reads the latest 500 manually processed logs, Q25(i)).
  Checker chat config: `CheckPenClustering::Base` gets ONE shared
  `config/llm.yml` entry named `CheckPenClustering` (via `llm_config_key`, the same mechanism
  `CheckInkClustering::Base` uses for its four subclasses), pointed by default at the **S01-picked pen
  starting model** — the same DigitalOcean model `PenVariantClusterer` and `PenModelClusterer` run on.
  Q32 is explicit that pen agents run on the S01 spike's pick, and nothing assigns the ink checkers'
  S30 result to the pen checkers. The ink checkers' S30 pick is one CANDIDATE in this step's own
  checker bench round below (the task shape is similar), not the default.
  Enable once S33 (pen-directive-tuning) shows a stable, tuned approval rate that clears the Q27 bar the
  owner set at the end of S15; then raise the depth so throughput is bounded by the checker's rejection
  rate rather than by human capacity. Optional split: agents PR, then wiring/UI PR.
- **Depends on.** S33 (tuned L1 directive AND the Q27 bar met), S28 (checker `decide` and bench
  pattern), S30 (supplies the ink checkers' pick as a bench candidate — not this entry's default); S31 is an informational
  dependency only (by the time this merges, `search_web`'s `GoogleSearchSummarizer` sub-agent already
  runs on DO for the flipped ink agents, so there is nothing special to wire for the pen checkers'
  own `search_web` calls), and S30 is likewise informational here rather than a source of this entry's
  default — it supplies one candidate for the checker bench round, not the starting model. There is NO
  dependency on S37 (chat-cutover-final): under Q32 the pen stack
  has been DO-only since S15, so the v1 cost preference that scheduled the checkers after the final ink
  cutover ("every new call is on the cheap model") no longer applies — this step's only real gate is
  the Q27 bar. Contingency: if the Q27 bar is not yet met when S37's post-flip watch week starts, build
  S42 (pen-brand-clusterer) in that week instead and slide this step to after S39 (retire-openai-keys).
- **Why here.** Fills S37's watch week when the Q27 bar is already met by then (S33 measured it); it is
  what removes the human bottleneck before the backlog drain (S41). Only worth building once the
  tuned, DO-model approval rate is measured — not once OpenAI is gone, since the pen agents never ran
  on OpenAI.
- **Does not include.** The real-time trigger (S40).
- **Definition of done.**
  - Specs per the ink checker template (spec/agents/check_ink_clustering/assign_spec.rb: parent log
    built by hand at the top; `expect_any_instance_of(PenVariantClusterer).to receive(:approve!).with(agent: true)`
    as at :190; reject path returning clusters at :254-260; create_spec.rb and ignore_spec.rb same
    layout; human_spec.rb stubs AdminMailer; do not add `WebMock.reset!`, the RSpec/WebMock integration
    already resets between examples); flag off -> no `RunPenClustererAgent` job for a checker; reject
    with 3 returned clusters -> 1 `RunPenClustererAgent` job (the owning cluster) + 1 argument-less
    `TopUpPenClusteringQueue` job (the siblings are DISCARDED, not passed to it); presenter
    spec with fixture logs (approved+approve, approved+reject, rejected+reject) yields the expected
    percentages and the page renders without NaN when a row has no follow-up data; a config spec that
    `CheckPenClustering::Assign`/`Create`/`Ignore`/`Human` all resolve to the one shared
    `CheckPenClustering` entry via `llm_config_key`.
  - A bench run of the pen checker cases with the criterion written down: cases = `PenVariantClusterer`
    leave-one-out result (S21 exporter) + expected verdict = whether it matches today's state (S28's
    pattern: `decide`, stop after `ask!`); default/baseline model = the S01-picked pen model this
    step's `CheckPenClustering` entry points at, with the ink checkers' S30 pick as one candidate; report
    correct-verdict rate per action and hard-negative recall for each DO candidate; there is no OpenAI
    baseline for this bench, by design — the pen agents never ran on OpenAI (Q32) — record that
    explicitly rather than framing it as a gap. This bench run is a MINOR round (Q6): no fresh bench-DB
    refresh, re-export cases from the existing copy.
  - Prod risk: low at merge, medium at the `flyctl secrets set PEN_CLUSTERING_CHECKERS_ENABLED=true`
    that enables it (which itself restarts every machine, same as any Fly secret change).
- **Decisions applied.** Q1 (the four `CheckPenClustering::*` checkers share ONE `config/llm.yml` entry,
  `CheckPenClustering`, via `llm_config_key`, the same mechanism the ink checkers use), Q32 (no
  dependency on the final ink cutover; the pen stack has been DO-only since S15, so the checkers' gate
  is the Q27 bar, not a cost preference; the `CheckPenClustering` config entry points at the
  S01-picked pen model, like every other pen agent), Q27 (the enable gate is the
  bar the owner set at the end of S15 and confirmed tuned/met in S33), Q34 (Human checker copies the ink
  email+approve-parent behaviour but finalises its own child log; `RunFailedClusterJobs` DOES restart
  stuck pen checker runs), Q24 (agent-decided parents show on the review page for spot checks but do not
  count toward depth), Q22 (a refused approval inside `execute_decision!` is a plain rejection, no
  tag), Q19 (the empty-cluster branch matches S11's marker-log/auto-rejection behaviour), Q35 (the
  single Sidekiq worker stays as is; watch `agents` queue latency; revisit when S41's drain starts).
- **Implementation notes.**
  - `RunFailedClusterJobs`'s checker branch must dispatch
    `RunPenClustererAgent.perform_async(log.name, log.owner_id)` where `owner_id` is the **parent
    AgentLog id** (checker logs are owned by the parent log via
    `find_or_create_agent_log(micro_cluster_agent_log)`, base.rb:41), unlike the L1 branch which passes
    the micro cluster id; spec both shapes so the two branches are never confused.

### S39-retire-openai-keys — Remove `OPEN_AI_*` everywhere

- **Goal.** In this order, after S37's watch week has elapsed (S39 removes S37's rollback path):
  (0) confirm the S22 and S30 OpenAI baseline tables are recorded in `docs/llm-migration-plan.md`
  (S33's tuning table is a separate, non-baseline artefact), because after this step
  the bench can compare DO candidates only (the plan accepts this: "baseline rerun uses the existing
  OpenAI key during the bench only"); (1) merge the code/CI/`.env` PR that removes `OPEN_AI_TOKEN` and
  `OPEN_AI_EMBEDDINGS` placeholders from `.env`, their entries from `.github/workflows/ci.yml`, and any
  alias code S04/S18 still had to keep alive while OpenAI was an active provider. Two `config/llm.yml`
  edits are real work in THIS step, not something an earlier step already did:
  (1a) DELETE the `embeddings.legacy` entry (added in S18 with `api_key_env: OPEN_AI_EMBEDDINGS`),
  together with any `dual_write` key that still references it. S34 turned off its last WRITER and says
  in its own text that the entry is still there and that retiring it belongs to this step; after the
  deletion `EmbeddingsClient` resolves only `current`/`read`.
  (1b) REPOINT the `test:` section: S04 deliberately kept every class resolving to
  `https://api.openai.com/v1` with `api_key_env: OPEN_AI_TOKEN` (and the embeddings test entry at
  `OPEN_AI_EMBEDDINGS`) so the 173 literal WebMock stubs keep working, and S04's DoD therefore said
  "no new CI env var is needed". That is now reversed: change the test entries' `api_key_env` to
  `DO_INFERENCE_TOKEN`, add `DO_INFERENCE_TOKEN: test` to `.github/workflows/ci.yml`'s env block and
  `DO_INFERENCE_TOKEN=xxx` to `.env`. Keep the test `api_base` at `https://api.openai.com/v1` so NO
  stub changes anywhere — only the key NAME changes, and WebMock never checks the key's value. This is
  not optional: `RubyLLM::Chat.new` -> `Provider#ensure_configured!` raises
  `RubyLLM::ConfigurationError` ("Missing configuration for OpenAI: openai_api_key") inside
  `build_chat` when the resolved key is nil (and `Configuration#openai_api_key=` treats `""` as nil),
  so deleting the CI values while the test entries still name them turns every agent spec red.
  Then verify the two
  `agent_token_env_var` overrides that exist today at
  `spec/agents/concerns/ruby_llm_agent_spec.rb:32,81` are gone — S04 deletes `agent_token_env_var`
  itself (`app/agents/concerns/ruby_llm_agent.rb:106-108` today) as part of moving key lookup into
  `config/llm.yml`, so by S39 these two spec overrides should already be absent; this step's DoD
  re-checks it rather than deleting it itself; confirm the auto-deploy is healthy after merge; (2)
  `flyctl secrets unset OPEN_AI_TOKEN OPEN_AI_EMBEDDINGS -a fountainpencompanion` (this itself restarts
  every machine and is the "deploy after removal"; if a code path still read an old name, the failure
  would be at request time via `ENV.fetch(name, nil)`, and Honeybadger would report a Sidekiq failure
  only on the 3rd attempt — `config/honeybadger.yml:42-43`'s `sidekiq: attempt_threshold: 3`); (3)
  trigger one agent run from `fly console` (any agent, e.g. `RunAgent.perform_async("SpamClassifier",
id)`) and confirm a fresh `agent_log` with `usage["model"]` equal to the DO response model string;
  `flyctl secrets list -a fountainpencompanion` shows only `DO_INFERENCE_TOKEN` among the LLM-related
  secrets (plus whatever else S00's inventory listed). DO becomes the only LLM provider in prod. Open a
  docs PR marking the migration complete, with a one-line "Development setup" note in
  `docs/llm-migration-plan.md` (or the project README, whichever the plan-doc agent picked as the
  canonical spot) naming `DO_INFERENCE_TOKEN` as the one key every developer must put into
  `.env.local` — no repo file documents `.env.local` keys today, so this is new text, not an edit.
  Revoke the OpenAI dashboard key only after the definition of done below passes, not before.
- **Depends on.** S37 (all chat agents are on DO after the final ink cutover — nothing reads an OpenAI
  key for chat any more), S34 (dual-write off: until then the old `embedding` column was still being
  written through OpenAI's `text-embedding-3-small`, so `OPEN_AI_EMBEDDINGS` was still live), S00
  (`DO_INFERENCE_TOKEN` already exists as a Fly secret and in every developer's `.env.local` since S00;
  this step only removes the two OpenAI names, it creates nothing).
- **Why here.** Only safe once nothing reads an OpenAI key; deliberately its own step because the
  judges found the key retirement scheduled before dual-write was off in an earlier draft.
- **Does not include.** Anything else. No pen-side change: the pen agents never held an OpenAI key
  (Q32), so there is nothing pen-related to remove here.
- **Definition of done.**
  - `git grep -n OPEN_AI -- ':!docs/'` returns nothing (tracked files only), and
    `grep -n 'legacy' config/llm.yml` returns nothing, while `FetchEmbedding` still makes exactly one
    HTTP call per run (the dual-write path is already gone from S34; this confirms the entry removal
    did not leave a second writer behind). CI is green with `DO_INFERENCE_TOKEN: test` as the only LLM
    env var. `docs/llm-migration-plan.md`
    keeps the old names as history (the historical "Keys" section the plan-doc agent wrote in S00-S04's
    review). The untracked `.env.local` may still hold a stray `OPEN_AI_TOKEN`/`OPEN_AI_EMBEDDINGS` line
    in a checkout that has not pulled and re-read the new docs note — that is a per-developer cleanup,
    not a blocker, but the DoD requires the note to exist so any developer hitting a missing-key error
    can self-serve.
  - CI green (the `OPEN_AI_TOKEN`/`OPEN_AI_EMBEDDINGS` lines are gone from `ci.yml`'s env block; every
    spec that used to stub against a literal OpenAI token env value must not reference it — grep
    `spec/` for `OPEN_AI` too, not just app code).
  - The post-`flyctl secrets unset` restart starts cleanly (`flyctl status -a fountainpencompanion`
    shows all machines healthy; `flyctl logs -a fountainpencompanion` has no boot-time `KeyError`/
    `ENV.fetch` crash) and one real agent run lands on DO (task (3) above) within the same session.
  - The two `agent_token_env_var` spec overrides are confirmed absent from
    `spec/agents/concerns/ruby_llm_agent_spec.rb` (grep for the string; if they somehow survived S04,
    delete them here and note it as an S04 cleanup miss).
  - Rollback if step (2) or (3) fails: `flyctl secrets set OPEN_AI_TOKEN=<value> OPEN_AI_EMBEDDINGS=<value> -a fountainpencompanion`
    restores both secrets immediately (Fly does not retain secret values once unset, so the owner must
    have the values ready — e.g. copied from a password manager — before running the `unset` in task
    (2)); the code-side PR is reverted with `git revert` + merge, same as every other config-flip step
    in this roadmap (S04's runbook note).
- **Implementation notes.**
  - Baseline hits in the codebase as of 2026-09-14, before S04/S18 land (these are what S04 and S18
    change; this step is the final sweep after they and S34/S37 have already run): `.env:5-8` (four
    `OPEN_AI_*` placeholder lines, including the two misnamed `OPEN_AI_PEN_AND_INK_SUGGESTION` and
    `OPEN_AI_SPAM_CLASSIFIER` that Q3 already retires in S04), `.github/workflows/ci.yml:16-19` (same
    four names in the test env block), `app/agents/concerns/ruby_llm_agent.rb:98-108`
    (`access_token`/`agent_token_env_var`, replaced by S04's `config/llm.yml`-driven lookup),
    `app/lib/embeddings_client.rb:28-30` (`access_token`, replaced by S18),
    `spec/agents/concerns/ruby_llm_agent_spec.rb:32,81` (the two `agent_token_env_var` overrides, dead
    once S04 removes the method they override).
  - By the time S39 runs, S04 and S18 have already removed the `agent_token_env_var` method and the
    `Rails.env.development?` branches; what remains for THIS step to delete is only the two ENV VAR
    NAMES themselves (`OPEN_AI_TOKEN`, `OPEN_AI_EMBEDDINGS`) wherever they still appear as literal
    strings — the `.env`/`.env.local` placeholder lines, the `ci.yml` env block, and (if it slipped
    through) any `api_key_env: OPEN_AI_TOKEN` left in a `config/llm.yml` entry that should already have
    been repointed at `DO_INFERENCE_TOKEN` by S37/S34.
  - Grep to run before opening the PR: `git grep -rn "OPEN_AI" -- '.env' '.github/' 'config/' 'app/' 'spec/'`
    — every hit found should be one this PR deletes; anything else found is a bug from an earlier step
    that this step's author should flag to the owner rather than silently patch (it means an earlier
    step's DoD was not actually met).
- **Decisions applied.** Q3 (the one surviving key name is `DO_INFERENCE_TOKEN`; `OPEN_AI_TOKEN` and
  `OPEN_AI_EMBEDDINGS` are the two names removed here; the misnamed per-agent names disappeared back in
  S04), Q32 (there is nothing pen-side to remove — the pen agents were never issued an OpenAI key).

### S40-pen-realtime-trigger — `Pens::UpdateMicroCluster` enqueues the L1 agent with the 30 s debounce and a run-time cap check

- **Goal.** `Pens::UpdateMicroCluster` (`app/workers/pens/update_micro_cluster.rb`, `perform` at lines
  5-10 today) gains the trigger with an explicit branch order: `if pens_model_variant_id ->
Pens::UpdateModelVariant.perform_async; elsif ignored? -> return; elsif collected_pens.exists? ->
perform_in agent`. This order matters: an ink-style `return if cluster.ignored?` placed FIRST (the
  shape at `app/workers/update_micro_cluster.rb:12`) would stop `Pens::UpdateModelVariant` propagation
  for the 1 prod row that is ignored **and** assigned — pens-domain.md finding I19: "Ignored L1
  clusters still get `UpdateMicroCluster` enqueued by the controller
  (`admins/pens/micro_clusters_controller.rb:43`), which is a no-op without a variant. Unlike inks
  (`app/workers/update_micro_cluster.rb:12` returns on `ignored?`), the pens worker does not check
  `ignored`, so an ignored cluster that also has a variant (possible via two PUTs) still propagates."
  Keep that propagation working by checking `pens_model_variant_id` first, and only then `ignored?`.

  Define `PenVariantClusterer::DEBOUNCE_WINDOW = 30.seconds` (mirrors `InkClusterer::DEBOUNCE_WINDOW` at
  `app/agents/ink_clusterer.rb:125`) and call
  `RunPenClustererAgent.perform_in(PenVariantClusterer::DEBOUNCE_WINDOW, "PenVariantClusterer", cluster.id)`
  from the worker's `else` branch (the ink call shape at `app/workers/update_micro_cluster.rb:19`, using
  the pen agent's own worker class from S13 in place of `RunInkClustererAgent`).

  `PenVariantClusterer` (built in S11/S12, this step only adds to it) gains three guard behaviours —
  two copied from `InkClusterer`, which S11 deliberately left out because the drip (S15) never needed
  them (nothing re-touched a cluster fast enough to matter at hand-review pace; the real-time trigger
  changes that), and one that enforces Q23 on this new path:
  1. `recent_activity?` — `micro_cluster.collected_pens.maximum(:updated_at)&.> DEBOUNCE_WINDOW.ago`
     (mirrors `InkClusterer#recent_activity?` at ink_clusterer.rb:274-276). Call it inside `perform`
     right after `already_resolved?` returns false and BEFORE `agent_log` is touched at all (the ink
     ordering at ink_clusterer.rb:180-185: `return if already_resolved?` then `if recent_activity? ...
return`), so a skipped run never creates or finds an `agent_log` row. Note the CONTRAST with Q19,
     which is the opposite rule and must not be confused with this one: an empty-cluster skip DOES
     write a terminal marker log tagged `auto_rejection: "empty_cluster"` (S11) — the debounce skip
     and the Q36 cap skip below write no log at all. Do not "unify" the two. On a hit, re-enqueue with the same `perform_in(DEBOUNCE_WINDOW, ...)` call and return.
  2. The "newer collected pens than the waiting log" clause of `InkClusterer#already_resolved?`
     (ink_clusterer.rb:279-291, specifically the final line
     `micro_cluster.collected_inks.where("updated_at > ?", latest.updated_at).none?`) — S11 built the
     pen `already_resolved?` without this clause because nothing re-touched a `waiting_for_approval`
     cluster during the drip. Add it now: a `PenVariantClusterer` log that is `waiting_for_approval`
     does NOT block a fresh run if a `collected_pen` on the cluster was updated after the log's
     `updated_at` — otherwise a pen edited after the agent already asked for approval would sit stale
     until a human reviews the outdated decision, and the real-time trigger (which fires on every pen
     save via `Pens::AssignMicroCluster`) makes that collision routine instead of rare.
  3. The hand-over exclusion (Q23) — required here for the same reason: an approved
     `hand_over_to_human` log is TERMINAL, so neither S11's waiting-log guard nor clause 2 blocks a
     re-run, and any later save of a pen in a handed-over cluster would re-run the agent. That defeats
     Q23, which excludes such clusters from being worked again "until a human assigns or ignores them
     in the React app". Skip the run when `Pens::MicroCluster.handed_over_to_human_ids` (S13's single
     shared definition, also read by S16) contains this cluster, so the real-time trigger and the
     top-up read the identical exclusion and cannot drift.

  Q36 (decided): add a run-time cap check inside `PenVariantClusterer#perform` (**Implementer
  default:** next to `already_resolved?`/`recent_activity?`, so all skip logic lives in one place;
  the worker would also be legal), evaluated after the guards above and before `agent_log` is touched.
  When the human review queue is at capacity — S13's by-name count of `waiting_for_approval` +
  `processing` `PenVariantClusterer` logs, against the SAME single reader S13 defined: call
  `TopUpPenClusteringQueue.depth` (or extract S13's counting query into
  `TopUpPenClusteringQueue.queue_full?`) rather than re-reading ENV here. If it is read inline it must
  be the identical call `ENV.fetch("PEN_CLUSTERING_QUEUE_DEPTH", "0").to_i` — STRING default `"0"`,
  which means an unset var leaves the trigger inert in development and test, and which is also what
  S13's spec stub convention matches on (`allow(ENV).to receive(:fetch).with("PEN_CLUSTERING_QUEUE_DEPTH", "0")`).
  A default of `10` would both make the trigger fire locally and silently miss that stub. (Same env
  var S15 set to 10 per Q28, and that S33 raises once the Q27 bar is met — S33's working value is 25,
  an implementer default, not an owner-set number.) When at capacity — the run skips WITHOUT creating any log and
  leaves the cluster for the next top-up refill (S13's `TopUpPenClusteringQueue`). Document the
  consequence explicitly in code comments and in the runbook: the top-up's refill order is "pen count
  desc then random" with no brand priority (S13), so once the trigger is live, a cluster skipped here
  competes with the whole backlog at the next refill and — until S41 changes the ordering for its own
  stages — new singletons arriving through the trigger never jump ahead of the existing backlog.

- **Depends on.** S38 (pen checkers exist and are wired in; the plan places the real-time trigger after
  the checker so new pens flowing in through it are decided without growing the human backlog — a run
  that reaches a verdict the checker can auto-approve never touches the human queue at all), S07 (CSV
  import routing — this landed many steps earlier and its one-off re-save already ran inside S08; there
  is nothing left to wait for here, unlike the conditional v1 phrasing).
- **Why here.** Turns the pull-based drip (hand review at a fixed queue depth, topped up by cron/admin
  action) into steady-state automation: every pen save is now capable of triggering an L1 decision
  within 30 seconds, not just the ones the top-up happens to pick.
- **Does not include.** The backlog (S41) — the ~96.7k unassigned MICRO CLUSTERS that predate this
  trigger (about 102k pens behind them) are drained separately, through the top-up mechanism, not
  through this real-time path.
- **Definition of done.**
  - Debounce spec and guard specs (see the spec list below).
  - A day of inflow observed in prod with the Q36 behaviour holding: record how many trigger runs were
    skipped for being at the cap (a Honeybadger breadcrumb or a log line naming
    `micro_cluster_id`/current depth is enough instrumentation — no new metric system needed) and
    confirm none were silently lost (a skipped cluster must still show up at a later top-up; verify by
    picking a handful of skipped ids and checking they eventually got a `PenVariantClusterer` log).
  - Runbook hazard list (put this in `docs/pen-clustering-plan.md` under a new "Operational hazards"
    heading, and cross-reference the model-not-found runbook S05 added to
    `docs/llm-migration-plan.md` — the two runbooks live in different files): every code path that enqueues
    `Pens::UpdateMicroCluster` is now a trigger for an agent run, not just a variant-count refresh:
    - `Pens::AssignMicroCluster` — runs on every pen save (create or edit), the highest-volume path.
    - The admin PUT, `Admins::Pens::MicroClustersController#update` (lines 40-44 today), including an
      un-ignore: after this step, un-ignoring a cluster from the admin UI becomes an agent run instead
      of a silent no-op. Note the ordering hazard this exposes: if a human just wrote a guidance note
      while un-ignoring (S14's synthetic guidance-log flow in
      `Admins::Pens::MicroClustersController#update`; the identical comment already exists on the ink
      side at `app/controllers/admins/micro_clusters_controller.rb:47` and `:71`, immediately before
      `UpdateMicroCluster.perform_async`), that note must be persisted BEFORE this PUT
      enqueues the worker, or the agent could run before the human's context is saved — this mirrors an
      identical comment already in the ink admin code and must be checked, not assumed, for the pen
      controller.
    - `PenVariantClusterer#approve!`'s `after_commit` hook (added in S12, following `InkClusterer#approve!`
      at `ink_clusterer.rb:248-268`, whose two `after_commit { UpdateMicroCluster.perform_async(micro_cluster.id) }`
      calls are at :256 and :260) — an approved ASSIGN or CREATE re-enqueues. An approved hand-over
      does not: the ink hand-over branch is a bare `micro_cluster.touch` (ink_clusterer.rb:264) with no
      enqueue, and Q23 removed even that from the pen version, so S12's hand-over branch flips the log
      state and nothing else.
    - The reject-cleanup path (S12) — rejecting an approval that had already assigned/created can
      re-touch sibling clusters, each of which re-enqueues.
    - `RefreshPens` (the run-by-hand admin button; `config/sidekiq_schedule.yml:18-21`, `enabled: false`
      today) — running the argument-less form (`RefreshPens.perform_async` with no ids) becomes a mass
      trigger of up to ~97k agent runs, bypassing the top-up's ordering and the depth cap's intent (each
      of those runs still individually respects the Q36 cap, so it will not flood the review queue, but
      it WILL burn through checker/agent worker capacity for however long ~97k jobs take). State plainly
      in the runbook: never run the argument-less `RefreshPens` while the trigger is live; if a mass
      re-save is ever needed again, batch it explicitly (`RefreshPens.perform_async(ids)` in controlled
      batches, the pattern `SaveCollectedPen` and S07/S08 already use) and expect it to compete with
      whatever else is running.
  - Spec list — EXTEND the existing `spec/workers/pens/update_micro_cluster_spec.rb` (21 lines, 2
    examples at :4-20: "does nothing if no model variant was assigned" and "schedules the model
    variant update job if model variant assigned"). Keep both and add the negative assertions and new
    cases below; do not create or overwrite the file:
    - assigned cluster (`pens_model_variant_id` present) → enqueues `Pens::UpdateModelVariant`, does
      NOT enqueue `RunPenClustererAgent` (keep the existing "schedules the model variant update job"
      example, add the negative assertion).
    - unassigned, unignored, with collected pens → enqueues exactly one `RunPenClustererAgent` job with
      args `["PenVariantClusterer", cluster.id]`, scheduled `DEBOUNCE_WINDOW.from_now`. Copy the case
      structure from `spec/workers/update_micro_cluster_spec.rb:6-35` and use the ink matcher from
      `spec/agents/ink_clusterer_spec.rb:536-538`:
      `expect(RunPenClustererAgent.jobs.last["at"]).to be_within(2).of((Time.current + PenVariantClusterer::DEBOUNCE_WINDOW).to_f)`.
      MANDATORY in `spec/agents/pen_variant_clusterer_spec.rb`: add
      `before(:each) { CollectedPen.update_all(updated_at: 1.hour.ago) }` at the top, mirroring
      `spec/agents/ink_clusterer_spec.rb:78` ("Age inks past the debounce window so the agent runs
      immediately during tests") — without it, every S11/S12 example starts failing the moment
      `recent_activity?` lands, because factory-built pens are seconds old. Then add a
      `context "debounce"` block modelled on `spec/agents/ink_clusterer_spec.rb:521-550`.
    - ignored AND assigned (the I19 case) → still enqueues `Pens::UpdateModelVariant` (the ordering
      fix); does NOT enqueue `RunPenClustererAgent`.
    - ignored, unassigned → enqueues nothing.
    - empty cluster (no collected pens) → enqueues nothing (mirrors S11's empty-cluster skip, but at the
      worker level this is just "collected_pens.exists? is false").
    - `PenVariantClusterer#recent_activity?` spec: a cluster with a `collected_pen` updated within the
      last 30 seconds → `perform` re-enqueues itself via `perform_in` and creates NO `agent_log` row.
    - `PenVariantClusterer#already_resolved?` spec: a cluster with a `waiting_for_approval` log whose
      `updated_at` predates a `collected_pen`'s `updated_at` → `already_resolved?` returns false (a
      fresh run is allowed); the same cluster with no newer pen update → `already_resolved?` returns
      true.
    - Q36 cap spec: with `PEN_CLUSTERING_QUEUE_DEPTH` stubbed to a small number and that many
      `waiting_for_approval`/`processing` `PenVariantClusterer` logs already present, a new trigger run
      creates NO `agent_log` and does not call `ask!`/`decide` at all (stub or spy on whatever the
      internal decision method is called after S11/S12 land, to prove the LLM is never invoked when
      capped — this is a cost-safety assertion, not just a log-count assertion).
- **Decisions applied.** Q36 (the run-time cap check: skip without a log, leave the cluster to the next
  refill, no separate "queue is full" state), Q35 (no change to Sidekiq concurrency or a dedicated
  worker slot here — the single throttled worker from S13 stays; queue latency under real-time load is
  watched, not solved, in this step; revisited only when S41's drain starts).

### S41-pen-backlog-drain — Drain the L1 backlog in priority order on the DO model (small code + months of running); unknown-brand singletons last

- **Goal.** Enqueue the backlog in stages under the pending cap (`PEN_CLUSTERING_QUEUE_DEPTH`, the same
  cap S40's real-time trigger respects). S13's `TopUpPenClusteringQueue` top-up order is "pen count desc
  then random" with no brand criterion, so stages 2 and 3 need one of two code changes (pick one, both
  are size M):
  - a `Pens::MicroCluster.known_brand` scope added to `TopUpPenClusteringQueue`, backed by the SAME
    definition S10's `Tools::PenKnownBrandTool` already uses (Q18: an EXISTS query — "does this
    cluster's `simplified_brand` occur among already-ASSIGNED `pens_micro_clusters`" — not the
    prod-data-check "definition C" that was floated in the original plan and counted brand spellings
    from `pens_brands`/`pens_models` instead). Reusing S10's exact scope means the tool's own
    known/unknown judgment and the drain's stage split can never disagree with each other — that
    agreement is the point of Q18, not just a code-reuse convenience. **Re-count the stage sizes with
    this scope at drain time**, not from the historical numbers below: the two definitions produce
    different splits (prod-data-check's own comparison table showed "known" ranging from 73,475 to
    80,397 out of 96,711 non-empty unassigned clusters depending on which of three tried definitions
    was used; S10's is closest to definition A, ~80,397 known / ~16,314 unknown, measured 2026-09-14,
    before months of drip and drain activity moved rows between stages).
  - or a separate enqueue loop that re-implements the SAME depth check outside
    `TopUpPenClusteringQueue` — never bypassing the cap: the drain is gated by
    `PEN_CLUSTERING_QUEUE_DEPTH` exactly like the top-up and S40's trigger (pen plan P5: "still gated
    by the pending cap"). Simpler to reason about in isolation, at the cost of duplicating S13's
    counting query — which S40's trigger also consults — so prefer the scope option above unless the
    implementer finds a concrete reason not to.

  The mechanism that keeps refilling for weeks is also code (a one-time `fly console` `loop { sleep }`
  is not viable for a months-long drain) — but check before building anything: S13's
  `RunPenClustererAgent#perform` ALREADY calls `TopUpPenClusteringQueue` from an `ensure` block after
  EVERY run, not only empty or errored ones, and S38 dispatches the checkers through that same worker
  class. So a checker run that auto-approves a parent frees the slot and then hits the same `ensure`,
  and the queue refills itself. **Verify this end-to-end on the first stage-1 batch** (one L1 run plus
  one checker run should leave the queue at depth). Only if that chain proves lossy — e.g. a checker
  process killed before `ensure` — add a `config/sidekiq_schedule.yml` cron entry
  `top_up_pen_clustering_queue`, every 5 minutes, `enabled: false` outside the drain window, following
  the existing `enabled: false` pattern already used for
  `refresh_pens`/`refresh_inks`/`refresh_ink_clusters` at `config/sidekiq_schedule.yml:10-21`. The
  schedule file is read at Sidekiq boot, so flipping `enabled:` needs a deploy.

  Stages (prod counts as of 2026-09-14; **re-count at drain time** — the drip and any real-time trigger
  activity from S40 have been consuming multi-pen clusters continuously since S15):
  1. The ~~4,094 multi-pen clusters (~~$30 total with the checker at Haiku-class prices: two LLM calls per
     decision — the L1 agent plus the checker — plus occasional web-search sub-agent calls; note the
     pen plan's cost table is per-agent-run only and does not include the checker call, so double it as
     a rough estimate).
  2. Singletons with a known brand under S10's `KnownBrand` definition (~69,822 by the original
     definition-C estimate, likely higher — closer to ~76-80k — once re-measured with S10's actual
     scope (Q18); ~$500 with the checker at the original estimate, scale the estimate with the
     re-measured count).
  3. The unknown-brand singletons (~22,911 by the original estimate, likely lower once re-measured;
     ~$160-200 with the checker), run ONLY after S42 (`PenBrandClusterer`, L3) is live and watched for
     hand-over rate (Q38): **stop the stage early if hand-overs dominate** — there is no fixed
     threshold decided; the owner watches the running hand-over percentage against the multi-pen and
     known-brand stages' rates and calls it if stage 3 is clearly worse. The reason stage 3 must wait for
     S42: L2 creates from these produce `pens_models` rows whose `brand` string matches no `pens_brands`
     row, and `PenModelsController#show` redirects to `pen_brands_path` whenever `@model.pen_brand` is
     nil (`app/controllers/pen_models_controller.rb:8-11`), so pens drained in stage 3 stay publicly
     invisible until L3 (S42) or a one-at-a-time manual brand-page assignment gives them a brand.

  Preconditions before starting: Q23's hand-over exclusion is implemented in the top-up (S13 —
  `TopUpPenClusteringQueue` already excludes clusters whose latest `PenVariantClusterer` log is an
  approved `hand_over_to_human`) and hand-over/excluded counts are reported per stage as the drain runs
  (a handed-over cluster is otherwise re-selected at the next refill and, at 97k-run scale, would burn
  budget re-deciding the same clusters repeatedly if the exclusion were missing — it is not, this is a
  verification, not new code). Q37 (decided: keep all `agent_log` history, no trimming, transcripts stay
  in every bench dump) means there is no retention-rule precondition to build before the singleton
  stages — the growth estimate below is informational only, not a blocker.

  Expected duration: `RunPenClustererAgent` (S13, `sidekiq_options retry: 2`) shares its throttled
  worker slot with the checker (both dispatched through the same worker class per S38); Q35 accepts the
  single worker as-is for now, so decisions/day ≈ 86,400 / (agent_seconds + checker_seconds). The
  33-42 second figure used below for a `CheckInkClustering` run is an ESTIMATE, not a measured prod
  number — measure it from the first stage-1 batch, but measure the right thing. `approved_at -
created_at` is TIME TO APPROVAL (queue wait plus checker or human review), not run duration, and a
  single human-spot-checked log approved hours or days later dominates the median. Restrict it to the
  checker path:
  `SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (approved_at - created_at))) FROM agent_logs WHERE name = 'PenVariantClusterer' AND agent_approved = true AND approved_at IS NOT NULL`
  — and even then it still includes the Sidekiq queue wait, so state that when recording it.
  Alternatively, measure throughput directly: terminal `PenVariantClusterer` logs per day over the
  stage-1 batch. Recompute from whichever measured figure is used. At 33-42 s per run, with the pen L1 agent similar in shape,
  expect roughly 1,000 decisions/day and roughly 97 days to drain the whole backlog at the single
  worker's limit of 1 — every downstream number here moves with that measurement. Revisit the concurrency question only if the drain proves too slow in practice —
  Q35 explicitly defers the "raise the pen worker limit or give the checker its own throttle slot"
  question to when the drain starts, i.e. now; if the owner wants it faster, that is a small follow-up
  PR to `RunPenClustererAgent`'s `sidekiq_throttle` config, not part of this step's scope.

  Watch, throughout: cost per run against the price table (S20/S30's hand-maintained pricing, keyed by
  the response `model` string), checker rejection rate per stage, and `agent_logs` table growth (Q37:
  roughly 97k rows × (≈5 KB agent transcript + ≈3 KB checker transcript + ≈5 KB per web search call) ≈
  1.3-2.5 GB over the whole drain — informational, no cleanup job is built for it). Stop a stage early
  if the checker's approval rate drops noticeably below the multi-pen stage's rate; that is a signal the
  model is guessing on data it has not seen the shape of, not a hard rule with a number attached.

- **Depends on.** S38 (the checker exists — makes million-decision-scale drain affordable — and its
  `execute_decision!` is one of the refill paths discussed above), S30 (the model pick for
  `PenVariantClusterer`: the pen agent has been running on DO chat since S15, and S30's chat bench round
  either confirms the S01 starting model or picks a different one, applied as a config PR in S33 before
  this step; either way S30's price table is what this step's cost estimates use — there is no
  dependency on the ink-side final cutover, the pen stack never shared a provider flip with the ink
  agents). S31 informational only: by the time this drain runs, `search_web`'s `GoogleSearchSummarizer`
  sub-agent calls are on DO too (S31 flipped the summarizers), so drain cost estimates should use DO
  summarizer pricing, not the OpenAI gpt-4.1-mini price the drip ran on before S31. S40 is ordered
  before this step (chronologically, in the roadmap) but is not a hard dependency — the drain uses the
  top-up mechanism, not the real-time trigger. S42 (L3, `PenBrandClusterer`) must be live before stage 3
  specifically, not before the whole step.
- **Why here.** Last money-spending step, as both source plans require: on a full-price chat model this
  would cost several years of the current LLM bill (the pen plan's own back-of-envelope math); without
  the checker (S38) it would drown the human reviewer in ~97k decisions with no auto-approval path.
- **Does not include.** Any code beyond the brand scope/split and the refill mechanism described
  above, and — explicitly (Q37) — no transcript-trimming/retention job. Does not include raising
  Sidekiq concurrency (Q35 defers that to a follow-up if needed).
- **Definition of done.** Stage-by-stage counts recorded (re-measured at drain time with S10's
  `KnownBrand` scope, not the historical estimates in this text), hand-over/excluded counts per stage,
  and spend per stage recorded against the price table. No retention/trimming precondition applies
  (Q37). Expected-duration line recorded using the single-worker throughput figure (Q35); if concurrency
  is later raised as a follow-up, record the new figure alongside it rather than replacing the original
  estimate. Stage 3 does not start until `PEN_CLUSTERING_L3_ENABLED=true` is set in prod and its review
  page works (S42) — that is Q38's gate, "after L3 is live". If an L3 decision has appeared by then it
  must have been reviewed, but the ABSENCE of one does not block the stage: S42's own DoD notes new
  brand-less models arrive at only ~10/month, so requiring an approved decision could be
  unsatisfiable. Stage 3 is stopped early if the hand-over rate clearly exceeds the earlier stages' rate
  (record the observed rates and the stop/continue call either way, even if the call is "continued
  through completion").
- **Implementation notes.**
  - Stage sizes (prod, 2026-09-14, under the old "definition C" — re-count with S10's scope at drain
    time, see the Goal): unknown-brand singletons 22,911; unknown-brand multi-pen 443; known-brand
    singletons 69,822; known-brand multi-pen 3,651; empties 9,370 (deleted by S08, so they are not in
    any stage).
  - `agent_logs` baseline the growth estimate is added to (prod, 2026-09-14): 74,267 rows / 1,017 MB
    total — heap 66 MB, TOAST plus indexes 951 MB; `transcript` 681 MB and `extra_data` 37 MB, about
    14 KB per log. The ~1.3-2.5 GB of growth this drain adds is on top of that.
- **Decisions applied.** Q32 (no dependency on an ink-side chat cutover; the pen stack has been DO-only
  since S15, so cost/model questions here are settled by S30's pick, not by any migration-wave step),
  Q23 (hand-over exclusion already implemented in S13's top-up; this step only verifies and reports it
  per stage), Q37 (keep all agent_log history forever; no trimming job; the growth estimate is
  informational), Q38 (unknown-brand singletons are stage 3, run last, only after S42 is live, and are
  stopped early if hand-overs dominate — no fixed numeric threshold was set), Q35 (accept the single
  worker/limit-1 throughput for the drain; revisit concurrency only now, as a possible follow-up, not as
  a precondition), Q18 (the known/unknown brand split for stages 2 and 3 reuses S10's `KnownBrand` tool
  definition — assigned-cluster brand spellings — instead of the plan's original "definition C" query
  over `pens_brands`/`pens_models`, so the tool's judgment and the drain's stage split never disagree).

### S42-pen-brand-clusterer — PenBrandClusterer (L3) as the `Pens::AssignBrand` fallback, L1 shape (no undo), with a review page

- **Goal.** Mirror `InkBrandClusterer` (app/agents/ink_brand_clusterer.rb, 118 lines) over the owner
  `Pens::Model` (the `has_many :agent_logs, as: :owner, dependent: :destroy` association S06 already
  added to `Pens::Model` directly after `has_one :pen_embedding`, i.e. model.rb:12 once S06 has
  landed — model.rb:11 is `has_one :pen_embedding` today; verify the association is present before
  starting): `MacroCluster -> Pens::Model`, `BrandCluster -> Pens::Brand`.
  New file `app/agents/pen_brand_clusterer.rb`. Constructor takes the SAME two-argument shape S12 gave
  `PenVariantClusterer` (not `InkBrandClusterer`'s bare `initialize(macro_cluster_id)`,
  ink_brand_clusterer.rb:69-71, which has no `agent_log_id:` because nothing ever calls `approve!`/
  `reject!` on it through a controller today): `PenBrandClusterer.new(model_id, agent_log_id: nil)`,
  storing both and using `agent_log_id` to disambiguate which log a review-page click applies to (the
  same reason S12/S14 pass it for `PenVariantClusterer`, fixing the ink controller's nil-`extra_data`
  bug at ink_clusterer_controller.rb:29/ink_clusterer.rb:253 — the review controller here passes
  `agent_log_id:` on BOTH `approve` and `reject`, never omitting it the way the ink controller still
  does on approve).
  - **Two halting tools that RECORD a decision and apply nothing.** This is the one place the ink
    original must not be copied: `InkBrandClusterer`'s tools call the operations inside `execute`
    (`UpdateBrandCluster.new(macro_cluster, brand_cluster).perform` at ink_brand_clusterer.rb:21,
    `CreateBrandCluster.new(macro_cluster).perform` at :43) — that is the apply-immediately shape Q39
    forbids here. In this class the operations `Pens::UpdateBrandCluster`
    (app/operations/pens/update_brand_cluster.rb:7-11: `Pens::Model.where(brand: model.brand).update_all(pens_brand_id: brand.id)`
    then `brand.update_name!`) and `Pens::CreateBrandCluster`
    (app/operations/pens/create_brand_cluster.rb:7-10: `Pens::Brand.create!(name: model.brand)` then
    the same `update_all`) are invoked ONLY from `approve!`. The tools are:
    `AddToBrand#execute(brand_id:, explanation_of_decision:)` ->
    `agent_log.update!(extra_data: { "action" => "add_to_brand", "brand_id" => brand.id, "explanation_of_decision" => ... }); halt "..."`;
    `CreateNewBrand#execute(explanation_of_decision:)` ->
    `agent_log.update!(extra_data: { "action" => "create_new_brand", "brand" => model.brand, "explanation_of_decision" => ... }); halt "..."`.
    From the ink file keep only the `param :brand_id, type: "integer"` shape (ink_brand_clusterer.rb:7)
    and the unknown-id retry string (:19); `CreateNewBrandCluster` is at ink_brand_clusterer.rb:32-47,
    with its operation call at :43 — read it for structure, not for behaviour.
  - Unique-index handling (Q20) lives in `CreateNewBrand#execute`, not in `approve!`. The constraint
    that makes all of this necessary is the UNIQUE index on `pens_brands.name`
    (db/structure.sql:2086); `Pens::Brand` has NO model-level uniqueness validation, so a duplicate
    raises `ActiveRecord::RecordNotUnique` from the database, not `RecordInvalid`. First call
    `Pens::Brand.find_by(name: model.brand)`; if a row already exists, do NOT halt — return the
    string `"A brand named '#{model.brand}' already exists (id #{existing.id}). Use add_to_brand
with that id instead."` so the LLM retries with `AddToBrand`, exactly the pattern
    `AddToBrandCluster` uses for an unknown id at ink_brand_clusterer.rb:19 ("This brand_cluster_id
    does not exist. Please try again."). If `model.brand.blank?` (one such model exists in prod),
    refuse the same way: return a string telling the LLM this model has no brand string to create a
    brand from (never call `Pens::Brand.create!(name: "")`, which is what
    `Pens::CreateBrandCluster#perform` would do unguarded, create_brand_cluster.rb:7). This mirrors
    `Pens::UpdateModelVariant`'s missing-rescue pattern being fixed elsewhere (S12) — here the fix is
    to never let the LLM reach the DB call with a blank/duplicate name in the first place, at
    decide time.
  - `PenBrandClusterer#approve!` is where the RACE version of the same collision is handled (Q20's
    approve-time half, same rule S12/S36 use elsewhere in this roadmap): wrap the `create_new_brand`
    branch's `Pens::CreateBrandCluster.new(model).perform` call in
    `rescue ActiveRecord::RecordNotUnique` and, on rescue, REFUSE the approval and plain-reject the
    log (Q22 — no `extra_data` tag, no stats-exclusion work, no special flash message, no auto-reject
    hook from any React controller) instead of silently finding the row and assigning to it. This can
    only happen if another brand with the same name got created between this log's decision and this
    approval (nothing else creates `pens_brands` rows). Also wrap `brand.update_name!`
    (app/models/pens/brand.rb:40-48, which renames the brand to whichever raw string is now the
    majority spelling and can itself collide with another brand's name) in the same rescue inside the
    `add_to_brand` branch, and skip the rename on collision rather than failing the whole approval —
    this is the same latent "rename skipped" behaviour the ink version already has (ink has no
    equivalent guard at all; do not add one there, only reuse the shape here).
  - **Implementer default:** `approve!` also re-checks `model.reload.pen_brand.nil?` before applying
    either branch, and REFUSES (plain rejection, same as above) if the model already has a brand by
    approval time. This is not spelled out for L3 in the plan text or in the decisions file, but it is
    the same "stale approval" guard S12 applies to `PenVariantClusterer#approve!`
    (re-checks the micro cluster is still unassigned) and S36 applies to `PenModelClusterer#approve!`;
    without it, a model that got a brand out-of-band while the log sat waiting (a human used the
    manual page at `Admins::Pens::BrandClustersController#update`, or `Pens::AssignBrand` matched a
    new synonym on a later `Pens::UpdateModel` run for the same model) would have its `pens_brand_id`
    silently overwritten by `approve!`'s `Pens::UpdateBrandCluster` call
    (app/operations/pens/update_brand_cluster.rb:8, which is where the `update_all` lives). The
    `AddToBrand` TOOL never writes `pens_brand_id` — it only records the decision (Q39). Chosen because it is the cheapest safety net
    consistent with Q22's "minimal safety check" philosophy and costs nothing when there is no race.
    Flag this decision to the owner in the PR description as a judgment call, not a decided item.
  - `perform`: `guards -> ask!(user_prompt) -> agent_log.waiting_for_approval!` — the L1 shape (Q39).
    Deliberate divergence from S11/S29: there is NO separate side-effect-free `decide` method here,
    because L3 has no bench cases (S21/S29/S30 cover L1 and L2 only) and no shadow worker, so `perform`
    calls `ask!` directly. It is also NOT
    InkBrandClusterer's fire-and-forget `ask` + immediate `waiting_for_approval!` with no guard at
    all (`perform` at ink_brand_clusterer.rb:73-77). `InkBrandClusterer` has no guard, but not because
    it cannot be re-invoked: `app/workers/update_macro_cluster.rb:29-33` runs on every ink save under
    the macro cluster and calls `AssignMacroCluster.perform_async(id)` whenever `cluster.brand_cluster`
    is nil, and assign_macro_cluster.rb:6-10 then enqueues `RunAgent.perform_async("InkBrandClusterer", ...)`
    again; since `find_or_create_agent_log` reuses only `processing` logs, each re-invocation mints a
    fresh one. That is a pre-existing defect this step does not fix (it is the likely cause of the 301
    `InkBrandClusterer` logs sitting unreviewed in `waiting-for-approval` on prod, with 4 rejected and 0
    approved) — the pen agent gets the guard the ink one lacks. The pen trigger fires
    on every `Pens::UpdateModel` run, i.e. every collected-pen save under an unassigned model, so a
    guard is required or the same model gets a second `PenBrandClusterer` log queued behind an
    already-`processing`/`waiting-for-approval` one. Guard, evaluated in
    `Pens::AssignBrand#assign_brand!` (see Trigger below), not inside the agent: skip when a log named
    `"PenBrandClusterer"` on this model is `processing` or `waiting-for-approval`, and skip when the
    model's latest `PenBrandClusterer` log is `rejected` BY A HUMAN (the "last log rejected" guard —
    new to L3: neither S11's L1 guard, which checks ignored / assigned / in-flight log, nor S36's L2
    guard has a last-log-rejected clause, because those triggers are depth-gated and this one is not) — otherwise `Pens::UpdateModel` running again
    on the very next collected-pen save (update_model.rb:10, i.e. on every save under the model) would
    re-run the agent against a human's rejection and re-propose a brand forever, since
    `find_or_create_agent_log` only reuses `processing` logs (ruby_llm_agent.rb:56-59) — a rejected
    log is not reused, so a fresh one gets created and immediately re-decided the same way.
  - `agent_log` reads `agent_log_id` first, then falls back to find-or-create, mirroring
    `InkClusterer#agent_log` (ink_clusterer.rb:173-178) rather than `InkBrandClusterer`'s endless
    `def agent_log = find_or_create_agent_log(macro_cluster)` at ink_brand_clusterer.rb:79 (fine there only because nothing ever re-enters `InkBrandClusterer` with
    an existing log id): `@agent_log = AgentLog.find(agent_log_id) if agent_log_id; @agent_log ||=
model.agent_logs.pen_brand_clusterer.processing.first; @agent_log ||=
model.agent_logs.create!(name: self.class.name, transcript: [])`.
  - `reject!` applies NOTHING and does not touch `model.pens_brand_id` (it was never written — only
    `approve!` writes it): `agent_log.reject!` (or `agent_log.reject_by_agent!` if `agent: true`,
    kept for signature symmetry with every other agent's `reject!`, though nothing in this roadmap
    calls it that way since there is no L3 checker). The model "re-queues to the manual brand page"
    passively — it was never removed from `Pens::Model.unassigned` (`pens_brand_id` stays nil), so it
    already shows up in `Admins::Pens::BrandClustersController#new`
    (app/controllers/admins/pens/brand_clusters_controller.rb:8, `Pens::Model.unassigned.order(:brand).first`)
    the moment the log is rejected; the only thing making the agent leave it alone going forward is the
    "last log rejected" trigger guard above. There is NO undo code: no nilling of `pens_brand_id`, no
    destroying a created brand, no `extra_data` snapshot of affected model ids for reject to read back
    — delete every trace of that alternative design (it does not apply here because nothing was ever
    applied before a human clicks Approve).
  - **`extra_data` contract**, fixed here because `approve!`, the review page and the DoD all read it:
    `{"action" => "add_to_brand", "brand_id" => <Pens::Brand#id>, "explanation_of_decision" => "..."}`
    or `{"action" => "create_new_brand", "brand" => <model.brand at decide time>, "explanation_of_decision" => "..."}`.
    The AGENT writes no other keys, and a refused approval adds none (Q22). One key can appear later
    from outside the agent: `CleanUp::RejectAgentLog` (S13) merges `"auto_rejection" => "orphaned"`
    onto a stuck `processing` log of any name — which is exactly the key this step's trigger guard
    reads to tell a janitor rejection from a human one.
  - **`approve!(agent: false)`**, written out: `return if agent_log.approved?` (idempotency, matching
    `InkClusterer#approve!` at ink_clusterer.rb:251); the whole body wrapped in
    `AgentLog.transaction { agent_log.lock! ... }` as ink_clusterer.rb:248-250 does; then
    `case agent_log.extra_data["action"]` —
    `when "add_to_brand"`: `brand = Pens::Brand.find_by(id: agent_log.extra_data["brand_id"])`, refuse
    and plain-reject if the row is gone, otherwise `Pens::UpdateBrandCluster.new(model, brand).perform`;
    `when "create_new_brand"`: `Pens::CreateBrandCluster.new(model).perform` (the operation does its own
    `update_all`). It ends with `agent ? agent_log.approve_by_agent! : agent_log.approve!`, the same
    last line as `InkClusterer#approve!` (ink_clusterer.rb:266) — even though nothing in this roadmap
    ever passes `agent: true`, since there is no L3 checker.
  - Prompt data: `Pens::Brand.includes(:models).order(:name)` (preloaded exactly as
    `BrandCluster.includes(:macro_clusters)` is at ink_brand_clusterer.rb:106-108, avoiding the N+1
    `models.pluck(:brand)` per brand would otherwise cause, brand.rb:33) mapped to
    `{brand_id:, name:, synonyms:}` where `synonyms` comes from `Pens::Brand#names` minus the brand's
    own `name` (brand.rb:28-34: `names` is `([name] + models.pluck(:brand)).uniq.sort`, `synonyms` is
    `names - [name]`) — only include the `synonyms` key when it is present, exactly like
    `brands_data` does at ink_brand_clusterer.rb:104-117 (`macro_cluster_data` is :96-102; the
    `includes(:macro_clusters)` preload is at :106-108). Model data: `model.brand`, `model.model`
    (`Pens::Model#name` is only `"#{brand} #{model}"`, model.rb:98-100, so send both raw fields, not
    the combined name), the distinct raw `brand` strings actually typed on this model's collected pens
    with their counts (`model.collected_pens.group(:brand).count`, sorted by count descending — this
    is the synonym-candidate list the system directive should have the LLM read as spelling variants
    of the SAME brand, not synonyms of other brands), and the names of the model's own variants
    (`model.model_variants.map(&:name)`, model_variant.rb:38-41) so the LLM has more context than a
    bare `brand`/`model` string pair to judge a fuzzy brand match against.
  - System directive: copy `InkBrandClusterer::SYSTEM_DIRECTIVE` (ink_brand_clusterer.rb:51-67 — note
    the range includes :64-66, the "synonyms for ink include spelling variations or typos / different
    translations" lines this step wants)
    almost verbatim (assign vs. create, spelling variations, translations), but add the sentence
    already decided for `KnownBrand` at L1/L2 (Q18): "An unknown brand may be a misspelling or word
    variant of a known one (for example 'twisbi', 'esterbook', 'pilotpilot', 'kaweko', 'platinium' are
    typos for real brands already in the system) — check spelling carefully before deciding this is a
    genuinely new brand." Note the deliberate trim: Q18's sentence was written for the pen
    `KnownBrand` at L1/L2, where `Tools::PenWebSearchTool` exists (S10; pen decision 4 turns web search
    on at L1 from the first run). L3 has no web-search tool — its only tools are the two halting
    decision tools — so the directive must NOT tell the model to search the web for a tool it does not
    have. The brand list IS the full universe of known brands, already in the prompt, which is also why
    no `KnownBrand` TOOL is needed here (unlike L1/L2): the LLM checks directly against `brands_data`
    instead of calling a separate yes/no tool.
  - Trigger, in `Pens::AssignBrand#assign_brand!` (app/workers/pens/assign_brand.rb:16-22), AFTER the
    existing `Pens::Brand.find_each` exact/synonym-match loop, replacing today's silent no-op when no
    brand matched:
    ```ruby
    def assign_brand!
      return if model.pen_brand

      Pens::Brand.find_each do |brand|
        model.update!(pen_brand: brand) if brand.names.include?(model.brand)
      end
      return if model.reload.pen_brand

      return unless ENV.fetch("PEN_CLUSTERING_L3_ENABLED", "false") == "true"
      return if model.agent_logs.where(
        name: "PenBrandClusterer",
        state: [AgentLog::PROCESSING, AgentLog::WAITING_FOR_APPROVAL]
      ).exists?
      last_log = model.agent_logs.pen_brand_clusterer.order(:id).last
      # "rejected BY A HUMAN": CleanUp's 3-hour sweep (app/workers/clean_up.rb:43-48) rejects stuck
      # `processing` logs of EVERY agent name through `CleanUp::RejectAgentLog` (reject_agent_log.rb:8,
      # plain `reject!`, `agent_approved: false`) — indistinguishable from a human rejection. Without
      # the tag check, one stuck run would bar this model from L3 for ever, since the only recovery
      # path this step has IS that sweep. S13's CleanUp tagging must therefore cover
      # `PenBrandClusterer` logs too (`extra_data.auto_rejection = "orphaned"`).
      return if last_log&.state == AgentLog::REJECTED &&
                last_log.extra_data.to_h["auto_rejection"].blank?

      RunAgent.perform_async("PenBrandClusterer", model.id)
    end
    ```
    exactly as `AssignMacroCluster` enqueues `InkBrandClusterer` at app/workers/assign_macro_cluster.rb:9
    (`RunAgent.perform_async("InkBrandClusterer", macro_cluster.id)`) — plain `RunAgent`
    (app/workers/run_agent.rb, concurrency 2 on the `agents` queue), NOT `RunPenClustererAgent` (that
    throttled slot is shared by L1/L2 only, per S36; L3 volume is a handful of models a month and does
    not need its own throttle). Flag default off (`PEN_CLUSTERING_L3_ENABLED`, per the roadmap's
    "Resolved without asking" flag list — L2 and L3 each get their own boolean rather than piggy-
    backing on `PEN_CLUSTERING_QUEUE_DEPTH`, which is an L1-only concept).
  - Config entry (Q32): `PenBrandClusterer` is a `config/llm.yml` entry from the moment this PR
    merges — never OpenAI/`gpt-4.1` even transiently — pointing at the **S01-picked pen starting
    model**, like every other pen agent (Q32: "pen agents are built on DigitalOcean models FROM THE
    START ... The starting model is chosen by the spike (S01)"). L3 gets no bench cases of its own
    (S21/S29/S30 cover L1/L2 only), so if the implementer judges that S30's `InkBrandClusterer` pick
    suits this task better — it is the same shape: brand match/create over a short synonym list, no
    image, no web search — that substitution is allowed, but it is an implementer judgement call and
    must be flagged as such in the PR description, not treated as the default. Either way, if S30
    later re-picks a different model for `InkBrandClusterer`
    itself, that is a separate config-only PR for `InkBrandClusterer`'s own entry and does not
    automatically change `PenBrandClusterer`'s — record the model name and the merge date in the PR
    description as S36 does for its own model-pick boundary.
  - `AgentLog.pen_brand_clusterer` scope, next to `.pen_variant_clusterer` (agent_log.rb, added in
    S06) and `.ink_clusterer` (agent_log.rb:14): `scope :pen_brand_clusterer, -> { where(name:
"PenBrandClusterer") }`.
  - `AdminStats#pens_brand_agent_review_count` (waiting + processing, same convention as
    `pens_micro_cluster_agent_review_count` in S14 and `pens_model_micro_cluster_agent_review_count`
    in S36 — both count `waiting-for-approval` PLUS `processing`, unlike the OLDER ink count at
    admin_stats.rb:14-21 which omits `processing`; do not repeat that omission) plus a sibling
    `span` in `app/views/admins/dashboards/show.html.slim` next to the L1/L2 spans (pattern at line
    44).
  - Review page: `Admins::Agents::PenBrandClustererController` (`index`/`update`/`destroy`) built on
    the SAME shared partial S14 extracted (reused as-is by S36 for L2), parameterised the same way:
    log scope = `AgentLog.pen_brand_clusterer.where(state: [AgentLog::WAITING_FOR_APPROVAL,
AgentLog::PROCESSING]).or(AgentLog.pen_brand_clusterer.agent_processed).order(:id)` — the
    `.order(:id)` matters because the partial pages with `per(1)` (S14) and is unstable without a
    deterministic order, and the ink controller ends its own scope the same way
    (ink_clusterer_controller.rb:77). (There is no
    `owner_with_...` filter needed here — a `Pens::Model` with a `PenBrandClusterer` log always has a
    `brand` string, since the trigger only fires from `Pens::UpdateModel`, which itself only runs when
    `model.collected_pens.present?`, update_model.rb:7, so there is no empty-owner case to hide, unlike
    L1/L2's empty-micro-cluster filtering, S06/Q8); action list = `add_to_brand`, `create_new_brand`
    (no hand-over action exists for L3 — the model is not a micro cluster and the ink/pen L1/L2
    "hand over to human" concept does not apply here, since the review page itself already lets a
    human decide); search-query source = `model.name` (`"#{brand} #{model}"`, already a plain method,
    unlike L1/L2 which needed the S06 tuple helper because `Pens::MicroCluster`/`Pens::ModelMicroCluster`
    have no name method at all); `processing?` predicate = plain `agent_log.processing?` (no
    follow-up/checker fields exist for L3, and none ever will per "Does not include" below); and the
    fifth parameter S14 defines, the route-helper set for the pagination/approve/reject links
    (ink template at ink_clusterer_controller.rb:70-85) — here the helpers generated by the new
    `resources :pen_brand_clusterer` line.
    Controller `update`/`destroy` actions both do
    `PenBrandClusterer.new(model.id, agent_log_id: agent_log.id).approve!` /
    `.reject!` — `agent_log_id:` is passed on BOTH verbs (unlike the ink controller, which omits it
    on approve at ink_clusterer_controller.rb:29), so a stale `processing` log with nil `extra_data`
    can never be approved by accident.
- **Depends on.** S36 (L2 must exist and create the new models that need a brand — every model L2
  creates from an unassigned `simplified_brand` value with no assigned sibling is exactly the case
  L3 exists to catch), S06 (the `has_many :agent_logs` association on `Pens::Model`; verify it is
  present before starting — added there, not here). S04 (the `config/llm.yml` mechanism and
  `llm_config_key`) and S14 (the shared review partial/presenter) are transitive dependencies —
  S04 via S36 -> S29, S14 directly via S36. S30 is not a hard dependency edge (this step is simply
  ordered after it); this step's `config/llm.yml` entry points at S01's starting DO model by default,
  with S30's `InkBrandClusterer` pick available as a flagged implementer substitution (see the config
  bullet above), so pulling S42 forward into S37's watch week per the calendar note in section 1
  changes nothing about its config.
- **Why here.** The ink L3 has no review UI at all — `app/controllers/admins/agents/` holds exactly
  one controller (`ink_clusterer_controller.rb`), and on prod 301 `InkBrandClusterer` logs sit in
  `waiting-for-approval` for good, 4 rejected, 0 approved, never reviewed. This step gives the pen L3 the
  page the ink one never got. Value today is otherwise low: 0 of 1,798 `Pens::Model` rows are unassigned and new models
  arrive at roughly 10/month (120 created in the last 12 months), all matched today by the existing
  exact/synonym loop in `Pens::AssignBrand`. But "nothing depends on it" would be the wrong read:
  that 100% match rate exists only because humans already assigned 151 models whose `brand` string
  equals no `pens_brands.name` through `Admins::Pens::BrandClustersController`
  (brand_clusters_controller.rb:12-24; 58 of today's 286 brands carry more than one raw brand
  string), which is exactly the synonym data `brand.names.include?(model.brand)` later matches
  against (brand.rb:32-34) — so the manual page is quietly doing L3's job today, one model at a
  time. S41's backlog drain has no L2 stage of its own — its three stages are all L1 — but its L1
  CREATES trigger L2 downstream (`Pens::UpdateMicroCluster` -> `UpdateModelVariant` ->
  `AssignModelMicroCluster` -> L2), and those L2 creates mint models across 4,157 distinct unassigned
  `simplified_brand` values with no assigned sibling; every one of those lands on `Pens::Model` with
  no brand and would otherwise pile up on the manual page. Build this step while S41's earlier
  stages run. Q38: this step must be live before S41's stage 3 (the 22,911 unknown-brand singletons)
  starts; the rate watched during that stage is S41's L1 hand-over rate, plus this page's own
  approve/reject rate — L3 itself has no hand-over action.
- **Does not include.** A `CheckPenClustering` checker for L3 (no such class exists anywhere in this
  roadmap — every L3 decision stays human-reviewed forever, unlike L1's checkers in S38); queue-depth
  gating (pen decision 2 — `PEN_CLUSTERING_QUEUE_DEPTH` is an L1-only concept, L3 has its own
  always-on-when-flagged flag); a backfill run over existing models (none are unassigned today, so
  there is nothing to backfill); changes to `Admins::Pens::BrandClustersController` (stays exactly as
  it is today, as the manual fallback the trigger guard defers to on rejection); a `RunFailedClusterJobs`
  branch (`InkBrandClusterer` has none either — a stuck `processing` L3 log means the decision tool
  never ran to completion, so the only correct recovery is `CleanUp::RejectAgentLog`'s existing
  orphan-rejection sweep, which leaves nothing applied because nothing ever gets applied before
  `approve!`); any `hand_over_to_human` tool/action (there is nothing to hand over TO beyond this
  review page itself).
- **Definition of done.**
  1. Agent specs modelled on `spec/agents/ink_brand_clusterer_spec.rb` (590 lines, four sections:
     perform / tools / data formatting / transcript — mirror that structure): `perform` per action via
     `stub_request(:post, "https://api.openai.com/v1/chat/completions")` with a tool_calls envelope
     (test-environment config still resolves `PenBrandClusterer` to the OpenAI test stub URL per
     S04's `test:` section, so no new WebMock host is needed); tool `.call` -> `RubyLLM::Tool::Halt`;
     prompt-data formatting (brand list with synonyms, model brand/model/variant names/collected-pen
     brand-string counts); transcript save/restore; the guard tests below; `approve!`/`reject!` per
     action, including idempotency (`return if agent_log.approved?`) and both `RecordNotUnique`
     rescues (create-collision and rename-collision).
  2. `spec/workers/pens/assign_brand_spec.rb` (32 lines today, FOUR existing examples: "does not fail
     if pen model does not exist" :4, "assigns the pen brand if one can be found" :8, "assigns the pen
     brand if a synonym matches" :16, "does not assign if the pen brand is already present" :25 — that
     last one exercises the `return if model.pen_brand` early return the new guard code must keep)
     gains: enqueues `RunAgent.perform_async("PenBrandClusterer", model.id)` when no brand matches
     AND the flag is on; does NOT enqueue when the flag is off; does NOT enqueue when a
     processing/waiting-for-approval `PenBrandClusterer` log already exists on the model; does NOT
     enqueue when the model's last `PenBrandClusterer` log is `rejected`; still finds an exact/synonym
     match first and never enqueues in that case (extend the existing four examples, do not replace
     them). Assert with `RunAgent.jobs`.
  3. Request spec for `Admins::Agents::PenBrandClustererController` modelled on
     `spec/requests/admins/agents/ink_clusterer_controller_spec.rb`, adapted for the two-action list
     and the fact that `reject!` here leaves the data untouched and the model visible on
     `new_admins_pens_brand_cluster_path` afterward (assert `Pens::Model.unassigned` still includes
     it and `Admins::Pens::BrandClustersController#new` picks it up) — this REPLACES the old "reject
     undo" spec description from the plan text; there is no undo path to test.
  4. One forced run on the dev copy, with everything INSIDE the transaction — the agent log is created
     inside it too, so a rollback destroys the very log you want to read:
     ```ruby
     ActiveRecord::Base.transaction do
       model.update!(pens_brand_id: nil)
       RunAgent.new.perform("PenBrandClusterer", model.id)   # direct call; no Sidekiq needed
       log = model.agent_logs.where(name: "PenBrandClusterer").last
       pp log.transcript, log.extra_data
       raise ActiveRecord::Rollback
     end
     ```
     Never commit this on the dev copy's shared data, and NEVER run it on prod.
  5. Flag on in prod (`flyctl secrets set PEN_CLUSTERING_L3_ENABLED=true`, restarts every machine,
     same operational cost as any other Fly secret change); the first real decision (if any — new
     brand-less models arrive at only ~10/month) reviewed by hand within the week it appears on the
     review page.
- **Decisions applied.** Q39 (L1 shape: decide -> waiting-for-approval -> `approve!` applies,
  `reject!` applies nothing and passively re-queues the model to the manual brand page via the
  existing "last log rejected" trigger guard; no undo code, no `extra_data` snapshot of affected
  model ids, no apply-immediately alternative), Q20 (the create tool checks for an existing identical
  brand name at decide time and returns a non-halting retry message instead of halting; `approve!`
  independently rescues `RecordNotUnique` for the true race and refuses + plain-rejects, same rule as
  S12/S36), Q22 (a refused approval is an ordinary rejection — no tag, no stats-exclusion filter, no
  flash branch, no auto-reject hook anywhere), Q32 (the config entry is a DigitalOcean model from the
  first merge, picked from S30's `InkBrandClusterer` bench result — no `gpt-4.1`, no separate pen
  cutover step), Q38 (this step must be live before S41's unknown-brand-singleton stage starts; the
  hand-over rate watched during that stage is S41's L1 rate — L3 has no hand-over action — alongside
  this page's own approve/reject rate).
- **Implementation notes.**
  - Files to create: `app/agents/pen_brand_clusterer.rb`,
    `app/controllers/admins/agents/pen_brand_clusterer_controller.rb`,
    `spec/agents/pen_brand_clusterer_spec.rb`,
    `spec/requests/admins/agents/pen_brand_clusterer_controller_spec.rb`.
  - Files to modify: `app/workers/pens/assign_brand.rb` (the trigger, shown in full above),
    `app/models/agent_log.rb` (new scope), `app/models/admin_stats.rb` (new count method),
    `app/views/admins/dashboards/show.html.slim` (new span, copy the L1/L2 pattern at line 44),
    `config/routes.rb` (add `resources :pen_brand_clusterer, only: %i[index destroy update]` inside
    the existing `namespace :agents` block at config/routes.rb:124-126, which today holds only
    `resources :ink_clusterer, only: %i[index destroy update]`, next to S14's `:pen_variant_clusterer`
    and S36's L2 route — named `:pen_model_clusterer` after the `PenModelClusterer` agent class),
    `config/llm.yml` (new `PenBrandClusterer` entry pointing at S30's DO pick for
    `InkBrandClusterer`), `spec/workers/pens/assign_brand_spec.rb` (new examples above),
    `spec/factories/agent_logs.rb` (add `trait :pen_brand_clusterer do name { "PenBrandClusterer" } end`
    next to `:ink_clusterer` at :31-33 and S06's `:pen_variant_clusterer` — every worker, request and
    agent spec here needs `PenBrandClusterer`-named logs), and `spec/models/admin_stats_spec.rb` (one
    example asserting `pens_brand_agent_review_count` counts `waiting-for-approval` PLUS `processing`
    and ignores approved/rejected logs).
  - Test cases (agent spec, in addition to item 1 of the DoD): `add_to_brand` with a valid
    `brand_id` calls `Pens::UpdateBrandCluster` and halts; `add_to_brand` with an unknown `brand_id`
    returns a retry string (does NOT halt — mirrors `AddToBrandCluster`'s unknown-id branch);
    `create_new_brand` when `Pens::Brand.find_by(name: model.brand)` already exists returns the
    "use add_to_brand" retry string and does NOT call `Pens::CreateBrandCluster`; `create_new_brand`
    with `model.brand.blank?` is refused with a retry string and never reaches `Pens::Brand.create!`;
    the guard is not fired when the flag is off, when a log is pending, or when the last log was
    rejected (worker-level tests, item 2 above); `approve!` for `create_new_brand` when a
    `RecordNotUnique` race is simulated (stub `Pens::Brand.create!` to raise, or create a second
    identically-named brand between decide and approve in the test) ends the log `rejected` with no
    `extra_data` tag and creates no new `Pens::Brand` row; `approve!` for `add_to_brand` when
    `brand.update_name!` raises `RecordNotUnique` (two brands whose models' majority raw string would
    collide) still assigns `pens_brand_id` and simply skips the rename, ending the log `approved`
    (this mirrors the pre-existing "latent bug" in `Pens::UpdateBrandCluster`/`Pens::CreateBrandCluster`
    that the ink version already has and this step deliberately does not fix, only avoids
    crashing on); the Implementer-default stale-brand recheck: decide `add_to_brand`, then have a
    human assign the model to a DIFFERENT brand via `Admins::Pens::BrandClustersController#update`
    while the log still waits, then call `approve!` on the stale log and assert it ends `rejected`
    with the human's assignment untouched.
  - `Pens::UpdateModel` (update_model.rb:7) returns early when the model has no collected pens, so an
    L2-created model only reaches `Pens::AssignBrand` (and therefore only becomes a candidate for
    `PenBrandClusterer`) once its own model micro cluster/variants have collected pens attached; spec
    fixtures need the full chain from the bottom (collected pen -> micro cluster -> model variant ->
    model micro cluster -> model) rather than building a bare `Pens::Model` — see
    `spec/workers/pens/update_model_spec.rb` for the canonical top-down build to copy.
  - Prod numbers (as of 2026-09-12/14, read-only replica): 1,798 `Pens::Model` rows, 0 unassigned, 286
    `Pens::Brand` rows; 151 models matched only via a synonym created by an earlier manual assignment
    (i.e., today's 100% auto-match rate is partly manual labor, not automatic); 120 models created in
    the last 12 months (~10/month) — this is the entire L3 volume until S41's L2 stage starts minting
    new brand-less models faster.
  - Rollback if the flag needs to come back off in prod: `flyctl secrets set PEN_CLUSTERING_L3_ENABLED=false`
    (or delete the secret; `ENV.fetch` defaults to `"false"`), restarts every machine, same as
    turning it on; no data migration to reverse since `approve!` is the only code path that ever
    writes anything, and it is always a deliberate human click.

## 4. Decided against the plan text (2026-09-14)

All figures as of 2026-09-12 to 2026-09-14 (read-only production SQL); re-count before acting on any
of them (see "Prod figures" in the Editor notes).

### 4a. Decided against the plan text (2026-09-14)

Each row: what the plan/decisions document said, what the code or data showed to be wrong or
incomplete about it, and the owner's 2026-09-14 decision that resolves it, quoted, with the steps it
shapes.

| Decided text                                                                                                                                                                                        | What the code/data shows (DIGEST and verifier evidence)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | Decision (2026-09-14)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Migration Decisions: "Cost attribution via existing `agent_logs.usage` graphs"                                                                                                                      | The only graph (`Admins::GraphsController#agent_usage`) sums `total_tokens` per agent name per day: no price, no model split, sub-agent tokens under their own name; RubyLLM subtracts cached tokens from `input_tokens` so cache hits are invisible; `usage->>'model'` holds the response string (`gpt-4.1-2025-04-14`), not the catalog id. "Cost per run <= current" cannot be read from it once agents run different models.                                                                                                                                                     | **(Q5)** "Bench-only cost from a hand-maintained price table. NO app change to `agent_logs.usage`, NO per-model admin graph. Step S17 is DROPPED." Shapes S01-do-spike (catalog price seed), S20-harness-core-ink (`lib/bench/pricing.rb`), S22-bench-round-0, S30-chat-bench-round (acceptance bar computed from the table).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Migration Decisions: "Embedding backfill... `CREATE INDEX CONCURRENTLY` off-peak"                                                                                                                   | Migrations run in the Fly `release_command` at merge time (60-minute cap, strong_migrations 1-hour statement timeout); the prod image has no `psql`; prod `maintenance_work_mem` defaults to 149 MB but is settable per session; `max_parallel_maintenance_workers` is 2; the ink HNSW index is 2.2 GB at 1536 dims.                                                                                                                                                                                                                                                                 | **(Q30)** "HNSW on embedding_v2: build BY HAND at a quiet hour from a detached session (not an interactive fly console), with SET maintenance_work_mem = '1GB', then merge a migration that records the index with `if_not_exists: true` + `algorithm: :concurrently` + `disable_ddl_transaction!`. DEFAULT index parameters." Shapes S26-hnsw-index-v2.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| Migration Decisions: "Bench DB: full prod dump (~10 GB)... Refreshed per round"                                                                                                                     | The database is 14 GB; vectors dump as text (~15 GB+); throughput from DO is ~1-1.5 MB/s (hours); restore rebuilds two HNSW indexes (slow at the container's 64 MB `maintenance_work_mem`); a full dump also copies users, emails, tokens and review content onto a laptop, and neither plan says anything about personal data (the `versions`/`usage_records` exclusion idea comes from the evidence maps, not the plans).                                                                                                                                                          | **(Q6)** "Bench DB = second database in the SAME Postgres container, selected by one env var. Refresh before MAJOR rounds only; minor rounds re-export cases from the existing copy." **(Q7)** "Full prod copy, no PII blanking, no retention rule." Shapes S17-bench-db.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Migration "Labels that already exist": "~10,200 ReviewApprover decisions"; "Every one of these micro clusters still exists"                                                                         | ReviewApprover labels are not in `agent_logs.state` (10,222 waiting / 0 approved) but in `ink_reviews.approved_at/rejected_at`; 10,230 logs cover only 6,163 reviews (5,247 duplicate May-2025 runs, 491 inconsistent). 15% of human-labelled InkClusterer micro clusters have no collected inks any more (InkClusterer refuses empties): ~10k usable cases over 9,369 clusters, several tries per cluster.                                                                                                                                                                          | **(Q10, ink case unit)** "Ink bench: (i) one case per micro cluster, latest human-labelled run; (ii) exclude approved hand-over cases and approved-but-unassigned-today cases; (iii) approved creates later merged count as ASSIGN to the merged cluster; (iv) rejected-try feedback HIDDEN by default, optional `--with-feedback` mode." **(Q11, ReviewApprover cases)** "ReviewApprover cases: latest run per review, human-confirmed verdicts only, drop reviews with contradictory decisions (~5,800-6,000 cases)." Shapes S20-harness-core-ink (Q10), S28-harness-checkers-review-export (Q11).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| Migration Decisions "YoutubeSummarizer thumbnail: Keep. Candidates for that agent must support image input"; P3 "Vision-capable candidates only for YoutubeSummarizer"                              | Three agents attach the thumbnail, not one: `ask!(user_prompt, with: resolved_image_url)` in ReviewApprover (review_approver.rb:126) and `ask(user_prompt, with: resolved_image_url)` in ReviewFinder (review_finder.rb:108); spec/agents/review_finder_spec.rb:376-387 asserts the `image_url` part is sent; 0 of the 5,817 human-confirmed ReviewApprover case reviews have a blank `image`. A non-vision candidate for either review agent would fail or silently drop the image.                                                                                                 | **(Q15)** "ReviewApprover and ReviewFinder keep the thumbnail; their candidates are limited to vision-capable DO models. No prompt change." Shapes S28-harness-checkers-review-export (export mode), S30-chat-bench-round (candidate list).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Migration Decisions "Bench spend cap ~$30 per full round. ~200 cases per labelled agent, 5-6 candidates"; acceptance bar "within 1pp of baseline agreement"                                         | ReviewApprover averages 21,400 prompt tokens/run: 200 cases x (baseline + 5 candidates) is ~25.7M prompt tokens for that agent alone; the four checkers ~19M; InkClusterer ~5.8M; pen L1/L2 similar. At Haiku-class prices the labelled agents alone are ~~$25-35 before the gpt-4.1 baselines (~$10) and the Sonnet subset. Wilson intervals at n~~200 are about +/-5 pp at 85-90% agreement, so a 1 pp difference cannot be resolved at that n.                                                                                                                                    | **(Q16)** "Acceptance bar: point estimate within 1 pp (2 pp for ReviewApprover) AND overlapping confidence intervals counts as pass. Cap stays ~$30/round: ~100 ReviewApprover cases per candidate, 200 only for the finalist; two or three candidates for the checkers." Shapes S30-chat-bench-round.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| Pen plan: "create -> `Pens::ModelVariant.create!` from the micro cluster's most common values"                                                                                                      | The six-column UNIQUE index on `pens_model_variants` makes `create!` raise `RecordNotUnique` exactly when the agent should have assigned; `Pens::UpdateModelVariant#update_attributes!` (`save`, no rescue) has no `RecordNotUnique` handling, unlike `Pens::UpdateModel#update_attributes!` (update_model.rb:20-29, itself carrying a `retried`-flag bug), so a later derived save fails and retries 25 times over ~3 weeks before the dead set. Same shape for `Pens::Model (brand, model)` and `Pens::Brand` name.                                                                | **(Q20)** "The create tool (create_new_variant / create_new_model / create_new_brand) itself checks for an existing identical row and, if found, RETURNS a message telling the model to assign instead of halting. That is the only chosen mechanism. If a collision still reaches approve! (race between decision and approval), approve! refuses and rejects the log exactly like the plan's stale-approval rule." Shapes S11-pen-agent-decide (the tool check), S12-pen-agent-apply (the approve! refusal), S29-pen-model-clusterer-agent (L2 tool check), S36-pen-model-clusterer-wiring (L2 approve! refusal), S42-pen-brand-clusterer (L3 tool + approve!).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| Pen plan: "human -> `touch` to move it back in the queue"; Pull-based rollout "Same ordering the manual review app uses"                                                                            | No effect for pens: the decided top-up order is by pen count then random, and the React app sorts by `Pens::MicroCluster.ordered` (simplified brand/model/color, micro_cluster.rb:13) and only filters by pen count (controller:9-17), so "same ordering" is wrong too; the same cluster would be re-selected on the next refill. For inks the `touch` never runs in practice either: the Human checker approves the parent log directly (237 of 239 hand-overs).                                                                                                                    | **(Q23)** "Clusters whose latest run is an approved hand_over_to_human are EXCLUDED from top-up refills until a human assigns or ignores them in the React app. No timestamp touch." Shapes S13-pen-workers (the refill exclusion), S16-pen-react-marker (the filter surfacing handed-over clusters so a human can act), S41-pen-backlog-drain (honors the same exclusion at scale).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| Pen plan P0 cleanup list and "96,705 unassigned"                                                                                                                                                    | The column count is 106,044-106,197 including 9,333-9,370 empty unassigned pen micro clusters; also 453 empty assigned ones (human "spelling -> variant" rules that `Pens::AssignMicroCluster` reuses), 349 empty assigned model micro clusters, 219 orphan pen and 607 orphan ink embedding rows, 1,407 collected pens without a micro cluster (1,260 also without an embedding row; re-enqueueing `FetchEmbedding` does not create rows); dev copy numbers differ from prod.                                                                                                       | **(Q8)** "Cleanup option (c): delete the unassigned empties (9,333 pen micro clusters, 69/75 model micro clusters, 25 empty variants, 7 empty models), orphan embedding rows, re-embed NULL vectors, fix missing rows. KEEP the empty ASSIGNED pen micro clusters (453) and model micro clusters (349) as human spelling rules and filter them in every query/count." Shapes S06-pen-groundwork (the filter scopes), S08-stale-data-cleanup (the deletions), S21-harness-pen-cases (exporter reads through the scope), S29-pen-model-clusterer-agent (assign/create labels count the kept empties as siblings).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| Pen plan P2 target: "at least the ink clusterer's ~85% human approval rate"                                                                                                                         | 84.8% is all-time; monthly human approval (by decision date) is 78-92% except a dip to ~64-68% in Aug 2026 (1,000 decisions), Sep 2026 back at 89%; by `created_at` month: Feb-Apr 83-86%, May 78.7%, Jun-Jul 83-84%, Aug 68.3% — volatile rather than uniformly low, and up to 4.5 pp apart depending on the date basis; `create_new_cluster` is approved 76.7% vs `assign` 95.8%; the figure includes `CheckInkClustering::Human` auto-approvals (`agent_approved = false`, no human saw them; 231-237 parents) and the empty-cluster pseudo-action `reject` (74 rows at 62%).     | **(Q27) DEFERRED.** "DEFERRED until the two-week drip shows real per-action approval rates. S33 (raise depth) and S38 (checkers) are gated on 'owner sets the bar after S15'; the roadmap must say so and must record both candidate yardsticks (ink per-action recent months; all-time 85%) for that later decision." Both yardsticks are recorded in S15-pen-drip-enable's DoD: (a) the ink agent's recent human-only monthly per-action rate; (b) the all-time 84.8% ("~85%"). Shapes S15 (records the yardsticks; owner sets the bar at the end of the drip), S33-pen-directive-tuning (depth raise gated on the bar), S38-pen-checkers (gated on the bar).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| Pen plan: "`KnownBrand` — `Pens::Brand.simplified_names` includes the micro cluster's simplified brand"                                                                                             | `Pens::Brand.simplified_names` is not callable code (`simplified_names` is an instance method, brand.rb:32-38; the plan means `Pens::Brand.find_each.flat_map(&:simplified_names)`, a 286-pluck N+1), and an exact match labels about a quarter of the backlog "unknown" (23,354 clusters, 4,384 distinct strings): the top unknown strings are typos or word variants of known brands (twisbi 287, esterbook 283, pilotpilot 272, kaweko 135, platinium 129) and a few renames (Karas Pen Co vs Karas Kustoms, Nahvalur vs Narwhal), but the top 25 cover only ~15% of that bucket. | **(Q18)** "Pen KnownBrand = exact match of the micro cluster's simplified brand against brand spellings seen in already-ASSIGNED pen micro clusters (one EXISTS query, mirrors the ink KnownBrand). The system directive tells the model that an unknown brand may be a misspelling and to check spelling / search the web." Shapes S10-pen-tools (the tool), S11-pen-agent-decide (the directive sentence), S41-pen-backlog-drain (reuses this definition for the stage 2/3 split instead of the old "definition C").                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| Pen decision 3 (ignore policy: Pilot Parallel is not ignored) vs the existing ignore labels                                                                                                         | Two `pilot / parallel` micro clusters (`blanco`, `white`) and a `?/calligraphyparallelset` one are among the 361 ignored (4 of 361 match parallel/calligraphy), directly contradicting decision 3; 252 of 361 ignored rows are `?`/unknown placeholders, so bench "ignore" labels partly contradict the decided policy.                                                                                                                                                                                                                                                              | **(Q13)** "Ignore labels that violate the decided ignore policy are EXCLUDED from the bench." Shapes S21-harness-pen-cases.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Pen plan P4: "agent-approved logs do not count" against the depth; ink admin queue semantics                                                                                                        | The ink review queue includes `agent_processed` logs for post-hoc review (ink_clusterer_controller.rb:71-78, 669 such ink logs), and that is the only source of the "correct auto review" percentages. Whether checker-decided pen logs appear in the human review page and how queued-but-not-started runs are counted (no log exists until the agent runs) is not in the plan. The P1 counting itself ("waiting-for-approval or processing", both by name) is implemented as written in S13.                                                                                       | **(Q24)** "(i) Depth counts waiting-for-approval + processing logs only; queued-but-unstarted jobs are not counted; brief overshoot accepted. (ii) Checker era: agent-decided logs SHOW on the human review page (spot checks feed the 'correct auto review' percentages) but do NOT count toward the depth." Shapes S13-pen-workers (part i), S38-pen-checkers (part ii).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| Pen plan: "`Tools::PenSimilaritySearchTool` ... for each the variants"; cost reference "a Lamy Safari candidate carries 50 variants"                                                                | `Pens::Model.embedding_search` returns no variants for models matched via their own embedding (tier 1), returns up to 200 models (272 under 0.6 for a common query), and the largest variant lists are 110 (Jinhao 82), 105 (Sailor Pro Gear Slim), 81 (Kaweko Sport), 76 (Lamy Safari under the model), not 50.                                                                                                                                                                                                                                                                     | **(Q17)** "PenSimilaritySearchTool lists the TOP K variants per model by number of micro clusters plus an 'and N more' line; the full-text tool finds the rest. K is a constant the implementer picks (suggest 15) and the bench reports capped cases." Shapes S10-pen-tools, S21-harness-pen-cases (capped-case stratum).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| Pen plan P5: "`Pens::UpdateMicroCluster` enqueues the L1 agent with debounce"; "With a checker in place the queue depth counts only logs that still need a human"                                   | No design anywhere caps the trigger path: the depth check lives only in `TopUpPenClusteringQueue`, the ink trigger enqueues unconditionally (update_micro_cluster.rb:19) and `InkClusterer#perform` has no depth check; a triggered run cannot know in advance whether the checker will approve. Inflow (~57-59 clusters/day) may therefore overshoot the human queue by the hand-over/reject share.                                                                                                                                                                                 | **(Q36)** "Real-time trigger performs a run-time check: if the human review queue is at its cap, the run skips without a log and leaves the cluster to the next refill." Shapes S40-pen-realtime-trigger.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Pen plan L3: "applies immediately and logs `waiting_for_approval` like the ink version"; Admin: shared review partial for the pen agents                                                            | `InkBrandClusterer` has no review UI at all (only `ink_clusterer_controller.rb` exists under app/controllers/admins/agents/; prod: 301 of its logs sit in `waiting-for-approval` for good, 4 rejected, 0 approved). Giving L3 the shared partial means approve and reject need a definition the plan does not give: reject of an already-applied `add_to_brand` must undo `update_all` on every model with the same raw brand and the `update_name!` rename; reject of `create_new_brand` must destroy the brand.                                                                    | **(Q39)** "PenBrandClusterer (L3) uses the L1 shape: decide, park waiting-for-approval, approve applies, reject re-queues to the manual brand page. It does NOT apply immediately. No undo code. This overrides the pen plan text 'applies immediately and logs waiting_for_approval like the ink version'." Shapes S42-pen-brand-clusterer.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Pen plan decision 6: pen agents run on gpt-4.1 through a constant `MODEL_ID`, converted to config-driven model selection only in a later cutover step (mirroring the ink migration's cutover waves) | No code exists yet to contradict this — `PenVariantClusterer` and its siblings are greenfield (built new in S11, S29, S42). This is not a factual correction but a deliberate strategic reversal: every pen decision is human-reviewed during the two-week drip (S15), so running the cheap DO model from day one is judged low-risk, saves money immediately, and gives the migration a second, fully human-reviewed DO tool-calling agent (after S31's wave 1) weeks before the ink cutover.                                                                                       | **(Q32) MAJOR OVERRIDE.** "MAJOR: pen agents are built on DigitalOcean models FROM THE START. This overrides pen plan decision 6 ('gpt-4.1 with a constant MODEL_ID'). The starting model is chosen by the spike (S01): whichever of two or three candidates handles forced tool choice and transcript replay cleanly; the pick is written into the roadmap/plan then. Consequence: the chat config layer (S15) MOVES BEFORE the pen agent (before S04-S13); the pen agent is born as a config entry pointing at a DO model. OpenAI stays the default for all ink agents until their own cutover. There is no separate pen cutover step any more." Shapes S00-ops-prereqs, S01-do-spike (picks the model), S04-llm-config-chat (built first because of this), S05-model-not-found-alert, S11/S29/S42 (pen agents born as config entries), S15-pen-drip-enable, S22-bench-round-0, S24-embedding-v2-backfill, S30-chat-bench-round (may pick a different model), S31-chat-cutover-wave-1, S33/S36 (config-only change if S30 picks differently), S37-chat-cutover-final, S38-pen-checkers, S41-pen-backlog-drain. No step anywhere converts a constant into config — there never is one. |

### 4b. Plan text that is wrong or incomplete, corrected by a step without a re-decision

Renumbered to v2 step ids only; the content each rewriter must implement is unchanged.

- Migration Decisions "RubyLLM 1.16: `openai_api_base` + `assume_model_exists: true` is enough":
  `assume_model_exists` raises without `provider:`, and `build_chat` at ruby_llm_agent.rb:86 passes
  neither; the OpenAI provider sends the system prompt as role `developer` unless
  `openai_use_system_role = true`; tool parameters carry `strict: true` / `additionalProperties:
false`; images are sent as remote URLs. Staying on 1.16 is still viable; "enough" is not. S01
  verifies each item, S04 encodes the outcome. The only thing that could become an owner decision
  is if DO cannot fetch image URLs, in which case base64 upload is forced by the decision "keep the
  YouTube thumbnail".
- Migration Decisions "Failure handling: Sidekiq retries only. No second provider, no cross-model
  fallback": the decided substance is "no fallback provider", and it is implementable as is.
  RubyLLM's Faraday layer already retries POSTs 3x on 429/5xx/timeouts (not on 400/404), no worker
  sets `sidekiq_options retry:` (default 25, also for `DecisionNotReachedError`), Honeybadger reports
  Sidekiq failures on the 3rd attempt. Today's prod already runs with this stack; it continues unless
  the owner tightens it (Q4, non-blocking; the budget lands in S04 and S13). Q33's "fallback entry"
  option was reworded so it cannot be read as an automatic cross-model fallback.
- Migration P0 "Ship with OpenAI still the default. Zero prod risk": true for prod; the test suite
  keeps today's endpoint and per-agent models as its defaults (173 `api.openai.com/v1` stubs in 16
  spec files keep working; only 10 literal `eq("gpt-4.1...")` assertions move to the config
  accessor). The shared stub-helper rewrite is an optional later cleanup, not a blocker (see
  "Engineering decisions" below).
- Migration P4: shadow runs write "an `agent_log` flagged `shadow: true`": a same-named log would
  block prod via `already_resolved?`, enter the admin queue, be re-enqueued by `RunFailedClusterJobs`
  while `processing` and rejected by `CleanUp` after 3 h; there is no shadow column. Compatible with
  the plan's phrase: a distinct log name in a terminal state plus `extra_data["shadow"] = true`
  (S25; see "Engineering decisions").
- Migration P1 "Runner (`lib/bench/`, rake task, not RSpec)" (the pen plan only says "shared
  harness"): implementable as written. `lib/` is not autoloaded (one explicit `require` in the rake
  task), Prettier runs over every `.rb` regardless of path, bench code gets specs so the Codecov
  project threshold (0.2%) stays green, and S17 adds the `.dockerignore` regardless of location.
  S02, S17 and S20 use `lib/bench/`.
- Migration Decisions "Bench execution: baseline rerun uses the existing OpenAI key":
  `RubyLlmAgent#access_token` and `EmbeddingsClient#access_token` branch on
  `Rails.env.development?`, so a rake task in the container would use `OPEN_AI_DEV_TOKEN` for
  everything. S04/S18 remove the branch; the baseline then uses whichever key the config names.
- Migration ground truth "Decision tools only write `agent_log.extra_data`": false for
  InkBrandClusterer (`UpdateBrandCluster`/`CreateBrandCluster` inside `execute`), ReviewApprover
  (`agent_approve!`/`agent_reject!` inside `execute`) and `CheckInkClustering::Base#execute_decision!`;
  `perform` also short-circuits and enqueues. S11/S19/S28 add the `decide` path; S20/S28 run tool
  writes inside the rollback or stop after `ask!`.
- Migration "CheckInkClustering::*: mostly still waiting for approval; weak labels": the child logs
  are left waiting by design; the verdict is copied to the parent's `follow_up_action` and crossed
  with the human verdict gives 10,955 strong labels (89% agreement, 859 hard negatives). S28 reports
  that matrix as a second reference.
- Migration P1 "exporter pulls the first user message": the prompt depends on DB state and
  `processed_tries_data` injects rejected tries including notes that name the answer; S20
  regenerates the prompt per case and hides the feedback inside the per-case transaction (Q10
  decides the default).
- Migration P2 "throttled backfill worker with batched inputs; dual-write": `EmbeddingsClient#fetch`
  is single-text and caches every vector in Redis for a week (a bulk path must bypass the cache);
  `FetchEmbedding` writes only `:embedding`; the column is hard-coded in `has_neighbors`,
  `FetchEmbedding` and six `nearest_neighbors` calls; `after_save` fires only on content change;
  sidekiq-throttled `threshold:` pacing counts job executions, so the backfill must be one job per
  batch; the public `PenModelsController#index` is also a reader. S09, S18, S24 cover each.
- Migration P2 step 5 "drop old column": `DROP COLUMN` frees the two HNSW indexes (~3.5 GB) at
  once but not the ~8.2 GB of old-vector TOAST, which stays until a table rewrite; S35 records the
  decision.
- Migration P0 "_TOKEN env var mismatch": broader than written; `PenAndInkSuggester` derives
  `OPEN_AI_PEN_AND_INK_SUGGESTER_TOKEN` while `.env`/`ci.yml` define `OPEN_AI_PEN_AND_INK_SUGGESTION`;
  namespaced `CheckInkClustering::*` derive names containing `/`; `EmbeddingsClient` uses
  `ENV.fetch` without default. S04/S18 replace the scheme (names per Q3).
- Migration volume table "avg prompt tok": per-run cumulative sums over all round-trips, not per
  call; 26,310 logs predate usage tracking. Fine for relative comparison; S20 records per-call
  usage.
- Pen plan P0 associations omit `Pens::Model`, the owner of PenBrandClusterer: S06 adds all three.
- Pen plan "generic replacement for `AgentLog.with_collected_inks`": two different EXISTS joins
  are needed (collected pens for L1, model variants for L2): S06 adds per-agent scopes.
- Pen plan "`approve!` re-checks that the micro cluster is still unassigned and rejects the log if
  not" and "destroy the created variant if it only holds this micro cluster" are decided, but they
  are new behaviour, not mirrors: `InkClusterer#approve!` overwrites `macro_cluster_id`
  unconditionally, `clean_up_rejected_approval!` always destroys the macro cluster and returns all
  its micro clusters, `ModelVariant#destroy` leaves the `Pens::ModelMicroCluster` behind, and the ink
  controller has no branch for a refused approval. S12 implements both decided rules with new specs;
  Q22 is narrowed to the tag and the admin message; Q21 keeps only the cross-level cascade the plan
  itself left open.
- Pen plan Pull-based rollout "Counts `PenVariantClusterer` logs in `waiting-for-approval` or
  `processing`": implemented as written in S13 (by name); Q24(i) confirms "processing" counts toward
  the depth exactly as this plan text already said.
- Pen plan "L2 triggered from `Pens::UpdateModelMicroCluster` when `pens_model_id` is nil; volume is
  small": that worker runs on every collected-pen save in an assigned cluster, so the trigger needs
  ignored / empty / in-flight guards and a race guard on `find_or_create_by!`: S36. The plan's
  "behind the same flag" (P3) is read as "the same mechanism": S36 uses its own
  `PEN_CLUSTERING_L2_ENABLED`, because the plan also says L2 is not depth-limited.
- Pen plan "L2 label: the 3,320 assigned model micro clusters": only 2,971 still have variants
  (1,649-1,736 assign, 1,235-1,322 create depending on whether empty siblings count): S29.
- Pen plan P1 omits the synthetic REJECTED guidance logs the ink micro clusters controller creates
  on un-ignore/unassign; the pen React controllers have none: S14 (L1), S36 (L2).
- Pen plan Admin "Same reject-and-reprocess and delete-history semantics": the ink path persists
  the manual rejection note first (controller:35) and then `cluster.agent_logs.destroy_all` on
  delete-history (controller:83) discards it together with all history, including sibling clusters'
  history when a created cluster is destroyed (ink_clusterer.rb:318-323); the "d" shortcut reveals
  the note input first because the delete-history button carries `.reject-btn`. S14 must either
  write the note after `destroy_all` onto a fresh guidance log or document that delete-history means
  "no feedback": Q25(ii).
- Pen plan Admin "Dashboard: pending-review counts for pen agents": covered per level, S14 (L1),
  S36 (L2), S42 (L3).
- Pen plan Pull-based rollout "A run that ends without a reviewable log (empty micro cluster, error)
  also calls the top-up": the error half needs an `ensure` in the worker, not a call inside the
  agent, because an exception unwinds before any top-up call: S13.
- Pen plan "`RunFailedClusterJobs` re-enqueues stuck processing logs": it is ink-only and the
  existing spec asserts other names are not restarted; `CleanUp` rejects any >3 h processing log
  regardless of name, via `CleanUp::RejectAgentLog`: S13.
- Pen plan "measure `embedding_search` latency on prod-sized data": prod `pg_stat_statements` is
  unreadable by the read-only role: S02 measures on the dev copy.
- Pen plan cost reference and prompt-size estimates: variant lists reach 110 (not 50); 39 pens is
  the largest **unassigned** cluster, but the labelled (bench) clusters reach 832 pens and 253
  distinct tuples, and 67-69 exceed 40 tuples, so S11's `PROMPT_TUPLE_CAP` is a bench variable S21
  reports (or raises above 253).
- Pen plan "own throttled worker": correct, but with `SIDEKIQ_CONCURRENCY=5` the three throttled
  worker classes can hold four of five threads, and sidekiq-throttled's 900 s `lost_job_threshold`
  collides with `RunFailedClusterJobs`' 15-minute requeue: S13 sets the threshold above the requeue
  age and requeues pen logs on `updated_at`; Q35 covers capacity before the checkers.
- Pen plan Cost reference (per agent run) understates the drain: with the checker every decision is
  two LLM calls plus web-search sub-agent calls: S41 restates the stage costs.
- CLAUDE.md "always override `def name`", CLAUDE.md:167 "some older agents still use raix", and
  `spec/agents/README.md` (raix, `Faraday::ServerError`) are stale: S03.
- Not in either plan (found by the DIGEST): `ImportCollectedPen` bypasses `SaveCollectedPen`, so
  imported pens never enter clustering until the disabled `RefreshPens` is run by hand (1,407 pens
  today): Q9 / S07.

---

## 5. Decision log (2026-09-14)

Every one of the 39 open questions from the v1 roadmap is now decided. Nothing below is a question
any more: each entry states the decision as fact, quoted from
the owner's answers of 2026-09-14, and lists the v2 steps it shapes.

Owner statements recorded alongside the 39 decisions, both accepted as fact: the admin React apps
for pens are the fallback destination for hand-overs only — humans do not work the React app and
the agent queue at the same time (this shapes Q22 and Q26 below); and "no vetoes given" on the
"Engineering decisions" list further down this section — every item there is accepted.

**Q1. How should the per-agent model settings be stored, and how are they keyed?**
Decision: "YAML file in the repo (`config/llm.yml`), keyed by agent class name with a shared default
block, secrets referenced by env var name. The four ink checkers share ONE entry. PenAndInkSuggester's
patron tier is a SECOND plain entry (e.g. `PenAndInkSuggester.premium`); the agent picks the entry
name at runtime."
Shapes: S04-llm-config-chat, S18-llm-config-embeddings, S24-embedding-v2-backfill (`dual_write` flip),
S27-embedding-read-flip (`read` flip), S31-chat-cutover-wave-1, S34-embedding-dual-write-off,
S37-chat-cutover-final.

**Q2. How does the bench (and shadow mode) tell an agent to use a different provider and model for
one run?**
Decision: "Scoped temporary override, keyed by agent class, active only inside one bench/shadow call,
thread-safe for concurrent Sidekiq jobs; specs must reset it."
Shapes: S04-llm-config-chat (the override hook), S20-harness-core-ink (the runner uses it),
S25-shadow-code (shadow mode applies it to the agent class and its summarizer classes together).

**Q3. What are the secret names during and after the migration?**
Decision: "Keep `OPEN_AI_TOKEN` and `OPEN_AI_EMBEDDINGS` until retirement; add ONE DigitalOcean key
name (e.g. `DO_INFERENCE_TOKEN`). The misnamed `OPEN_AI_PEN_AND_INK_SUGGESTION` /
`OPEN_AI_SPAM_CLASSIFIER` disappear."
Shapes: S00-ops-prereqs (creates `DO_INFERENCE_TOKEN`), S04-llm-config-chat, S18-llm-config-embeddings,
S31-chat-cutover-wave-1, S39-retire-openai-keys (removes the OpenAI names).

**Q4. How many times should a failed model call be retried, and how quickly should you hear about
failures?**
Decision: "DEFERRED. Keep today's retry behaviour (HTTP 3x + Sidekiq default 25 + Honeybadger
threshold 3). Revisit after the first DO flips. Exception already resolved: `RunPenClustererAgent`
ships with `sidekiq_options retry: 2`."
Shapes: S04-llm-config-chat (no retry-budget change), S13-pen-workers (`RunPenClustererAgent`'s
`retry: 2`), S24-embedding-v2-backfill (`BackfillEmbeddings` keeps the Sidekiq default). Revisit after
S31 (first ink flip) or later.

**Q5. Should the app start recording cached and raw prompt tokens per run and show cost per model in
the admin graph, or is cost computed only inside the bench?**
Decision: "Bench-only cost from a hand-maintained price table. NO app change to `agent_logs.usage`, NO
per-model admin graph. Step S17 is DROPPED." ("S17" there is the v1 usage/cost-fields step; in v2
numbering S17 is S17-bench-db, which is NOT dropped.)
Shapes: S01-do-spike (seeds the price table from the catalog), S20-harness-core-ink
(`lib/bench/pricing.rb`), S22-bench-round-0, S30-chat-bench-round.

**Q6. How is the bench database set up, and how often is it refreshed?**
Decision: "Bench DB = second database in the SAME Postgres container, selected by one env var.
Refresh before MAJOR rounds only; minor rounds re-export cases from the existing copy."
Shapes: S17-bench-db (`DATABASE_NAME` env var), S22-bench-round-0 (refresh #1), S30-chat-bench-round
(refresh #2), S33-pen-directive-tuning (minor round, re-export only).

**Q7. May the bench copy contain personal data?**
Decision: "Full prod copy, no PII blanking, no retention rule."
Shapes: S17-bench-db.

**Q8. Which stale rows may be deleted on production during the cleanup?**
Decision: "Cleanup option (c): delete the unassigned empties (9,333 pen micro clusters, 69/75 model
micro clusters, 25 empty variants, 7 empty models), orphan embedding rows, re-embed NULL vectors, fix
missing rows. KEEP the empty ASSIGNED pen micro clusters (453) and model micro clusters (349) as
human spelling rules and filter them in every query/count."
Shapes: S06-pen-groundwork (the filter scopes), S08-stale-data-cleanup (the deletions),
S21-harness-pen-cases, S29-pen-model-clusterer-agent.
Amendment recorded 2026-09-15 (the one place Q8's own numbers move): applying the project's standard
"no collected pens" definition AFTER task 2 destroys the 25 empty variants makes the empty-model set
**14**, not the 7 Q8 names (7 further models' only variant was one of those 25), and destroying those
14 nullifies 7 of the kept empty ASSIGNED model micro clusters, which task 3 then sweeps — so the
kept count is 351 today falling to 344, not 349. This widens Q8 by 7 rows the decision's text says to
keep; it is recorded here as an explicit amendment rather than left implicit in S08, and the
alternative (restricting task 4 to the literal 7) stays available if the owner prefers the narrower
read. See S08 task 4 for the 14 prod ids.

**Q9. Should pens imported from CSV files start going through the normal save path so they get a
micro cluster and an embedding?**
Decision: "YES: route `ImportCollectedPen` through `SaveCollectedPen`, plus a one-off re-save of only
the ~1,407 pens without a micro cluster (not the argument-less `RefreshPens`). Step S39 stays, and the
one-off re-save runs before the first bench dump (S14) and before the backfill (S23)." (v2 ids: S07
stays unconditional and precedes S08; the re-save runs before S17-bench-db and S24-embedding-v2-backfill.)
Shapes: S07-csv-import-routing (unconditional, moved before the cleanup), S08-stale-data-cleanup
(the one-off re-save), S24-embedding-v2-backfill (sees complete tables).

**Q10. What counts as one ink benchmark case, and how are the awkward labels handled?**
Decision: "Ink bench: (i) one case per micro cluster, latest human-labelled run; (ii) exclude approved
hand-over cases and approved-but-unassigned-today cases; (iii) approved creates later merged count as
ASSIGN to the merged cluster; (iv) rejected-try feedback HIDDEN by default, optional `--with-feedback`
mode."
Shapes: S20-harness-core-ink, S33-pen-directive-tuning (feedback hidden for hard negatives by default).

**Q11. Which ReviewApprover decisions become benchmark cases?**
Decision: "ReviewApprover cases: latest run per review, human-confirmed verdicts only, drop reviews
with contradictory decisions (~5,800-6,000 cases)."
Shapes: S28-harness-checkers-review-export.

**Q12. How honest should the pen benchmark be about singletons and leakage?**
Decision: "Pen bench: OVER-SAMPLE the singleton cells AND re-derive the held-out variant's (and
single-variant model's) name and embedding from the remaining pens inside the rolled-back transaction
(one extra embedding call per case)."
Shapes: S21-harness-pen-cases (the L1 hide/re-derive step), S23-embeddings-bench (re-embeds the
re-derived name per candidate), S29-pen-model-clusterer-agent (the L2 analogue re-derives the model).

**Q13. How should the benchmark treat "ignore" labels that contradict the decided ignore policy?**
Decision: "Ignore labels that violate the decided ignore policy are EXCLUDED from the bench."
Shapes: S21-harness-pen-cases.

**Q14. When a clusterer is benchmarked or shadowed on a candidate model, which model do its
sub-agents use?**
Decision: "Sub-agents (GoogleSearchSummarizer inside search_web, Youtube/WebPage summarizers inside
ReviewApprover's Summarize) run on the SAME CANDIDATE model as the agent under test, in bench and
shadow."
Shapes: S25-shadow-code, S28-harness-checkers-review-export, S30-chat-bench-round, S32-shadow-run
(soft dependency on S31's wave-1 summarizer flips having settled).

**Q15. Do ReviewApprover and ReviewFinder keep the thumbnail too, which limits their candidates to
vision-capable models?**
Decision: "ReviewApprover and ReviewFinder keep the thumbnail; their candidates are limited to
vision-capable DO models. No prompt change."
Shapes: S28-harness-checkers-review-export, S30-chat-bench-round.

**Q16. How is the acceptance bar applied at about 200 cases, and what fits the $30 round cap?**
Decision: "Acceptance bar: point estimate within 1 pp (2 pp for ReviewApprover) AND overlapping
confidence intervals counts as pass. Cap stays ~$30/round: ~100 ReviewApprover cases per candidate,
200 only for the finalist; two or three candidates for the checkers."
Shapes: S30-chat-bench-round.

**Q17. How should the pen similarity tool list variants under each model it returns?**
Decision: "PenSimilaritySearchTool lists the TOP K variants per model by number of micro clusters
plus an 'and N more' line; the full-text tool finds the rest. K is a constant the implementer picks
(suggest 15) and the bench reports capped cases."
Shapes: S10-pen-tools, S21-harness-pen-cases.

**Q18. What should the pen "known brand" check mean?**
Decision: "Pen KnownBrand = exact match of the micro cluster's simplified brand against brand
spellings seen in already-ASSIGNED pen micro clusters (one EXISTS query, mirrors the ink KnownBrand).
The system directive tells the model that an unknown brand may be a misspelling and to check spelling
/ search the web."
Shapes: S10-pen-tools, S11-pen-agent-decide, S41-pen-backlog-drain.

**Q19. What should a run do when it finds a micro cluster with no pens?**
Decision: "Empty micro cluster at run time: skip, write a small marker log OUTSIDE the review queue
(own name or tag, terminal state, excluded from stats), trigger a top-up."
Shapes: S11-pen-agent-decide (the marker log), S13-pen-workers (the worker's `ensure` triggers the
top-up), S38-pen-checkers (the checker copy of the same behaviour).

**Q20. What happens when the agent says "create a new variant" but an identical variant already
exists?**
Decision: "The create tool (create_new_variant / create_new_model / create_new_brand) itself checks
for an existing identical row and, if found, RETURNS a message telling the model to assign instead of
halting. That is the only chosen mechanism. If a collision still reaches approve! (race between
decision and approval), approve! refuses and rejects the log exactly like the plan's stale-approval
rule."
Shapes: S11-pen-agent-decide, S12-pen-agent-apply, S29-pen-model-clusterer-agent,
S36-pen-model-clusterer-wiring, S42-pen-brand-clusterer.

**Q21. When a human rejects an approved first-level "create" after the second level has already
acted on it, what is undone?**
Decision: "Full cross-level cascade on rejecting an approved L1 create: destroy the now-empty model
micro cluster, reject any L2 log on it, re-run the model update or destroy an empty model.
Implemented in S35 (L2 wiring); S09 handles the L1 half plus unassigned empty mmc." (v2 ids: S36
handles the cascade; S12 handles the L1 half plus the unassigned-empty-mmc destroy.)
Shapes: S12-pen-agent-apply, S36-pen-model-clusterer-wiring.

**Q22. When an approval is refused because a human already assigned or ignored the cluster
meanwhile, how is the auto-rejected run marked and shown?**
Decision: "Owner: 'not a case in practice; the React app is only used as the fallback for hand-overs,
never at the same time as the agent.' So: keep the plan's refuse-and-reject guard as a minimal safety
check (no tag, no stats exclusion work, no flash design, NO auto-reject hook from the React
controllers). Drop the React-double-work framing everywhere."
Shapes: S12-pen-agent-apply, S14-pen-admin, S16-pen-react-marker, S36-pen-model-clusterer-wiring,
S38-pen-checkers.

**Q23. What should "hand over to a human" do to the review queue's ordering?**
Decision: "Clusters whose latest run is an approved hand_over_to_human are EXCLUDED from top-up
refills until a human assigns or ignores them in the React app. No timestamp touch."
Shapes: S12-pen-agent-apply (state change only, no touch), S13-pen-workers (the refill exclusion),
S16-pen-react-marker (the filter), S41-pen-backlog-drain.

**Q24. Two details of counting the review queue's depth.**
Decision: "(i) Depth counts waiting-for-approval + processing logs only; queued-but-unstarted jobs
are not counted; brief overshoot accepted. (ii) Checker era: agent-decided logs SHOW on the human
review page (spot checks feed the 'correct auto review' percentages) but do NOT count toward the
depth."
Shapes: S13-pen-workers (i), S14-pen-admin (the presenter that reads the resulting logs), S38-pen-checkers
(ii).

**Q25. Two admin-page behaviours to confirm for the shared review page.**
Decision: "(i) Stats population: latest 500 manually processed logs (as inks). (ii) Delete-history
preserves the just-typed rejection note on a fresh guidance log and does NOT wipe sibling clusters'
history; the same fix is applied to the ink page."
Shapes: S14-pen-admin (also patches the existing ink review page in the same PR).

**Q26. The React marker for clusters the agent is working on: how much, and before or after the
first decisions?**
Decision: "React marker = badge PLUS a filter for clusters handed over to a human (latest log is an
approved hand_over_to_human) and clusters with a pending agent log. Ships AFTER the queue goes live
(S12 moves after S13). Purpose: make the hand-over fallback workable, not double-work prevention."
(v2 ids: the marker step moves after the drip step.)
Shapes: S15-pen-drip-enable (ships first), S16-pen-react-marker (badge + two filters, ships one PR
after S15), S36-pen-model-clusterer-wiring (the L2 marker reuses the same shape).

**Q27. Which approval rate does the pen agent have to reach before the queue is deepened and the
checkers are built?**
Decision: "DEFERRED until the two-week drip shows real per-action approval rates. S32 (raise depth)
and S38 (checkers) are gated on 'owner sets the bar after S13'; the roadmap must say so and must
record both candidate yardsticks (ink per-action recent months; all-time 85%) for that later
decision." (v2 ids: the depth-raise step is S33; the drip step is S15.)
Both candidate yardsticks, recorded in S15's DoD for the owner's later choice: (a) the ink agent's
recent human-only monthly per-action rate — all-time `assign` 95.8% vs `create` 76.7%; monthly human
approval 78-92% except 64-68% in Aug 2026 (1,000-1,170 decisions) and 89% in Sep 2026; by `created_at`
month Feb-Apr 83-86%, May 78.7%, Jun-Jul 83-84%, Aug 68.3%; excluding the Human checker's
auto-approvals (231-237 parents) and the empty-cluster pseudo-action (74 rows); (b) the all-time
84.8% ("~85%").
Shapes: S15-pen-drip-enable (owner sets the bar at the end of the two weeks), S33-pen-directive-tuning
(depth raise 10 -> 25 gated on it), S38-pen-checkers (gated on it).

**Q28. How much review time per week can you give the pen queue during the hand-review phase?**
Decision: "Queue depth 10 as planned."
Shapes: S15-pen-drip-enable.

**Q29. Should the pen hand-review queue pause while the embedding read flip happens?**
Decision: "On the embedding read-flip day: set PEN_CLUSTERING_QUEUE_DEPTH=0, flip, set back to 10 the
next day, record the boundary in the stats."
Shapes: S27-embedding-read-flip.

**Q30. How is the new similarity index built on production?**
Decision: "HNSW on embedding_v2: build BY HAND at a quiet hour from a detached session (not an
interactive fly console), with SET maintenance_work_mem = '1GB', then merge a migration that records
the index with `if_not_exists: true` + `algorithm: :concurrently` + `disable_ddl_transaction!`.
DEFAULT index parameters."
Shapes: S26-hnsw-index-v2. (S35-drop-old-embedding-column also checks the backup/PITR point, but
that check comes from S00's "DB backup check" prerequisite, not from Q30, which covers only the
by-hand HNSW build.)

**Q31. What is the new embedding column called in the end?**
Decision: "Column stays `embedding_v2` (or config-driven name) forever. No rename. S34b does not
exist."
Shapes: S34-embedding-dual-write-off, S35-drop-old-embedding-column.

**Q32. When do the pen agents switch to the DigitalOcean model?**
Decision: "MAJOR: pen agents are built on DigitalOcean models FROM THE START. This overrides pen plan
decision 6 ('gpt-4.1 with a constant MODEL_ID'). The starting model is chosen by the spike (S01):
whichever of two or three candidates handles forced tool choice and transcript replay cleanly; the
pick is written into the roadmap/plan then. Consequence: the chat config layer (S15) MOVES BEFORE the
pen agent (before S04-S13); the pen agent is born as a config entry pointing at a DO model. OpenAI
stays the default for all ink agents until their own cutover. There is no separate pen cutover step
any more." (v2 ids: the chat config layer is S04, moved before every pen step S06-S15.)
Shapes: S00-ops-prereqs, S01-do-spike, S04-llm-config-chat, S05-model-not-found-alert,
S11-pen-agent-decide, S15-pen-drip-enable, S22-bench-round-0, S24-embedding-v2-backfill,
S29-pen-model-clusterer-agent, S30-chat-bench-round, S31-chat-cutover-wave-1,
S33-pen-directive-tuning, S36-pen-model-clusterer-wiring, S37-chat-cutover-final, S38-pen-checkers,
S41-pen-backlog-drain.

**Q33. What should happen when DigitalOcean retires or renames a catalog model?**
Decision: "Explicit alert on 'model not found' errors (match the provider error) plus a runbook line
per agent naming a manual replacement model; small PR before the first ink flip (can be part of S15
or its own step)." (v2: its own step, S05, landing before the drip.)
Shapes: S01-do-spike (records the exact error text), S05-model-not-found-alert (its own step),
S18-llm-config-embeddings (wires the same matcher into `EmbeddingsClient`), S31-chat-cutover-wave-1
(inherits the alert).

**Q34. Two behaviours for the pen checker agents.**
Decision: "(i) CheckPenClustering::Human COPIES the ink behaviour: email hello@ and approve the
parent with agent_approved=false; but the pen copy finalises its own child log. (ii)
RunFailedClusterJobs DOES restart stuck pen checker runs."
Shapes: S38-pen-checkers.

**Q35. Is the single worker machine's capacity enough once pen agents, checkers and the real-time
trigger all run?**
Decision: "Accept the single worker as is; watch queue latency; revisit when the drain starts."
Shapes: S38-pen-checkers, S40-pen-realtime-trigger, S41-pen-backlog-drain (revisit point).

**Q36. Does the real-time trigger perform a run-time check against the human review queue's cap?**
Decision: "Real-time trigger performs a run-time check: if the human review queue is at its cap, the
run skips without a log and leaves the cluster to the next refill."
Shapes: S40-pen-realtime-trigger.

**Q37. How much run history should be kept once the backlog is drained?**
Decision: "Keep all agent_log history; no trimming; transcripts stay in bench dumps."
Shapes: S41-pen-backlog-drain (no trimming job needed before it; ~1.3-2.5 GB growth accepted as
information only).

**Q38. Are the ~22,900 single-pen clusters with an unknown brand worth running at all?**
Decision: "Unknown-brand singletons run LAST, after L3 (S42) is live, watching the hand-over rate;
stop early if hand-overs dominate."
Shapes: S41-pen-backlog-drain (stage 3, ordered after S42).

**Q39. How do approve and reject work for the brand agent (L3)?**
Decision: "PenBrandClusterer (L3) uses the L1 shape: decide, park waiting-for-approval, approve
applies, reject re-queues to the manual brand page. It does NOT apply immediately. No undo code. This
overrides the pen plan text 'applies immediately and logs waiting_for_approval like the ink version'."
Shapes: S42-pen-brand-clusterer.

### Engineering decisions (accepted 2026-09-14)

Formerly "Resolved without asking" — answered from code, data or the plans, not from a numbered
question. The owner gave no vetoes on this list; every item is accepted as-is.

- System-prompt role and image delivery on DO: the spike (S01) decides; if DO rejects the
  `developer` role the system-role flag is required (set per config entry on the DO block, never
  globally in `config/initializers/ruby_llm.rb`, so the OpenAI-default test suite is untouched), and
  if DO cannot fetch image URLs base64 upload is forced by the decision to keep the thumbnail.
- Test-suite defaults after the config layer: the test environment keeps today's OpenAI endpoint
  and per-agent models, so the 173 literal `api.openai.com/v1` stubs in 16 spec files stay as they
  are and only the 10 literal `eq("gpt-4.1...")` assertions move to the config accessor; the shared
  stub-helper rewrite is an optional later cleanup — this keeps S04 a modest PR.
- Where the harness lives: `lib/bench/` with an explicit `require` from the rake tasks and specs
  under `spec/lib/bench/`, exactly as the migration plan decides (docs/llm-migration-plan.md:190);
  the CI facts (Prettier over every `.rb`, Codecov 0.2%, no `.dockerignore`) are handled by specs
  and by S17, not by moving the code.
- Which Rails environment the bench runs in: development in the container. S04 removes the
  `Rails.env.development?` key branch, which today prevents a dev container from spending the prod
  key; after S04 the separation moves to secret names (`.env.local` vs Fly).
- The tool-name initializer patch stays (all existing tools rely on it); CLAUDE.md is corrected in
  S03. Pen tools rely on it; the web-search tool keeps the explicit name `search_web`.
- Bench isolation: bench rake tasks always switch Sidekiq to fake mode inside the task block, use a
  separate Redis cache database, and abort unless the connected database name ends in `_bench`; a
  "remember to stop sidekiq" procedure would corrupt the dev database the first time it is
  forgotten.
- Dump details: directory format with four parallel jobs from the app container, indexes skipped on
  restore and rebuilt with raised memory, container tools only. No `--exclude-table-data` at all: Q7's
  "full prod copy" replaced the evidence maps' `versions`/`usage_records` exclusion idea.
- `.dockerignore` is added in S17; CI's docker-build job is a signal, the deploy does not wait for
  it, and the Fly remote build is what fails safe.
- Bench code gets specs (the repo's rule for new code) so no coverage filter is needed.
- `bench_embeddings` is created by the harness in the bench database only, never as a Rails
  migration; it holds only the four candidates' vectors (the baseline is read from the existing
  column).
- Model prices come from a hand-maintained map in the harness filled from the spike's catalog
  table, keyed by the response `model` string (RubyLLM's registry has no DigitalOcean entries).
- The historical checker-vs-human confusion matrix is reported for free next to the leave-one-out
  checker bench.
- Narrowing the similarity queries so vectors are not transferred is done in S09 with a real-vector
  spec (needed anyway for the dual-column period) by selecting `id, owner_type, owner_id` before
  `nearest_neighbors`; the tier-3 N+1 fix rides along; the embedding column stays hard-coded until
  S24's per-column config entries.
- Guidance logs are excluded from the "correct auto review" stats population (S14), on top of Q25(i)'s
  "latest 500 manually processed logs" and the blessed `auto_rejection` exclusion. The synthetic
  REJECTED guidance logs S12's helper writes carry no `auto_rejection` key and would inflate every
  per-action Rejected count S22 compares against the bench; they are recognised by their empty
  transcript (`jsonb_array_length(transcript) > 0`). Applied to the pen page and, because the ink page
  has the same rows, to the ink page too — a visible change to live ink numbers that S14's PR
  description must state.
- A concurrent `(name, state)` index on `agent_logs` is added in S06: 53,810 rows are
  `waiting-for-approval` (every non-clusterer agent parks its logs there), and the by-name queue
  count that S13/S14 run after every review and on every dashboard load costs 1.8 s cold / 85 ms
  warm on prod without it; the build takes seconds.
- Auto-rejections by the three-hour janitor are tagged (in `CleanUp::RejectAgentLog`) and excluded
  from approval statistics; they are not human decisions.
- No debounce in the pen agent before the real-time trigger (the plan places the trigger and its
  debounce in P5); S40 also adds the "newer pens than the waiting log" guard clause then.
- The observable after a pen decision without a checker is the enqueued top-up job; environment
  variables are stubbed with `allow(ENV).to receive(:fetch).and_call_original` followed by a
  `.with(...)` stub in specs (no precedent exists; a bare `.with` stub makes every other `ENV.fetch`
  raise).
- `processing` runs count toward the queue depth, exactly as decided (Q24(i)): the plan text
  "Counts `PenVariantClusterer` logs in `waiting-for-approval` or `processing`" is implemented as
  written.
- First-level rejection cleanup follows the plan's rule (destroy the created variant only if it
  holds just this micro cluster, otherwise unassign) and additionally destroys a now-empty
  **unassigned** model micro cluster the variant produced; an assigned one is left to the S36
  cascade (Q21).
- A refused approval (cluster assigned or ignored meanwhile) rejects the run, as the plan decides;
  the tag and admin message are decided (Q22): no tag, no stats exclusion, no auto-reject hook from
  the React controllers.
- Shadow runs are stored under a distinct log name (`InkClusterer::Shadow`, `ReviewApprover::Shadow`)
  in a terminal state with `extra_data["shadow"] = true`, run synchronously next to the prod
  decision, and are excluded from the Human checker's previous-logs tool; compatible with the plan's
  "flagged shadow: true".
- Prompt-size cap for the pen agent's tuple list: a public constant `PROMPT_TUPLE_CAP = 40` plus
  "and N more". Not needed for the backlog (largest unassigned cluster 39 pens) but the bench runs
  on assigned clusters, 67-69 of which exceed 40 tuples (max 253), so S21 reports the capped cases
  as their own stratum.
- The S02 retrieval verdict threshold: "wrap as is" if model recall@20 >= 0.9 and variant recall@20
  > = 0.8 over assign cases in the top-20-by-distance view; otherwise "retrieval work needed in S09".
- `RunPenClustererAgent` ships with `sidekiq_options retry: 2` (Q4); the broader retry budget for
  every other agent worker stays deferred (Q4) until after the first DO flips.
- The two 15-minute constants (janitor requeue vs throttle slot release) are reconciled in S13:
  `lost_job_threshold` strictly above the requeue age, and the pen requeue keyed on `updated_at`.
- Flags: L2 gets its own boolean `PEN_CLUSTERING_L2_ENABLED` (default off) rather than
  piggy-backing on `PEN_CLUSTERING_QUEUE_DEPTH`, because the plan says L2 is not depth-limited; the
  pen checkers get `PEN_CLUSTERING_CHECKERS_ENABLED` (a literal copy of the ink code would
  auto-approve from the moment it merges); L3 gets `PEN_CLUSTERING_L3_ENABLED`.
- The ignored-cluster branch in `Pens::UpdateMicroCluster` is added with the trigger (S40), not
  earlier, and ordered after the assigned-variant branch (one prod row is ignored and assigned); the
  agent's own guard already skips ignored clusters.
- One embedding model for both tables and both columns (the plan's single embeddings entry); cutoff
  and ef_search are per table. S23 picks the cutoffs only; `ef_search` keeps its S09 values unless
  S26's `EXPLAIN` or S27's watch week shows otherwise.
- Both baselines (before and after the embedding swap) are run on purpose.

---

## 6. Deferred / dropped

Nothing from either plan is dropped for lack of merit. Items deliberately not scheduled, why, and
what the 2026-09-14 decisions changed about this list:

- **The v1 usage/cost-fields step is DROPPED entirely (Q5).** (Q5's own text calls it "S17", a v1 id;
  in v2 numbering S17 is S17-bench-db, a live step — do not read Q5 as dropping that.) No per-model
  admin cost graph, no cached/raw prompt token fields on `agent_logs.usage`. Cost is bench-only, from
  the hand-maintained price table (S20-harness-core-ink).
- **There is no pen cutover step anywhere (Q32).** v1 imagined a step that would convert
  `PenVariantClusterer` (and L2/L3) from a `gpt-4.1` constant to a config-driven pick, mirroring the
  ink agents' cutover waves. That step never exists: the pen agents are born as `config/llm.yml`
  entries pointing at a DO model (S11, S29, S42); a model pick that changes after the chat bench
  round (S30) is a plain config PR (S33 for L1, S36 for L2), not a cutover.
  `PenVariantClusterer` also never runs on the OpenAI key at any point, so **S39-retire-openai-keys**
  removes only `OPEN_AI_TOKEN` / `OPEN_AI_EMBEDDINGS`, never a pen-specific name.
- **A rename of `embedding_v2` back to `embedding` does not exist as a step.** v1's placeholder
  "S34b" (a repeat of the whole add/dual-write/backfill/flip/drop sequence, S24-S35 in v2 numbering)
  never gets scheduled: Q31 decided the column keeps the name `embedding_v2` (or a config-driven
  name) forever.
- **No transcript trimming job before S41-pen-backlog-drain.** Q37 decided to keep all `agent_log`
  history with no trimming, so the ~1.3-2.5 GB of growth the drain adds is accepted as-is; there is
  no small "trim old transcripts" step before S41.
- **The retry/error-reporting budget stays deferred (Q4).** Today's behaviour (HTTP layer retries 3x
  on 429/5xx/timeouts; Sidekiq default 25 retries; Honeybadger reports on the 3rd Sidekiq attempt)
  continues unchanged everywhere except `RunPenClustererAgent`'s explicit `sidekiq_options retry: 2`
  (S13-pen-workers). Revisit after the first DO flips (S31-chat-cutover-wave-1 or later); no step
  implements a new budget in this roadmap.
- **The pen approval-rate bar stays deferred (Q27) until the two-week drip (S15-pen-drip-enable)
  produces real per-action numbers.** It gates S33-pen-directive-tuning's depth raise (from the
  decided starting depth of 10 to a value the owner picks; 25 is S33's working default, not a decided
  number) and
  S38-pen-checkers; the owner chooses then between the two yardsticks recorded in S15's DoD (the
  ink agent's recent human-only monthly per-action rate, or the all-time 84.8%).
- **Prompt tuning of the ink agents** (ReviewApprover, WebPageSummarizer, SpamClassifier carry very
  large prompts): out of scope by the migration plan; the harness (S20, S28) is what a later
  tuning pass would use. Pen directive tuning (S33) stops at the Q27 target, as the pen plan's
  out-of-scope note asks.
- **RubyLLM 2.0 upgrade**: out of scope by the migration plan.
- **Prompt caching beyond the spike**: the spike (S01) records what DO exposes; there is no in-app
  cost/cache visibility change (Q5 drops S17 entirely), so any further work — cache-hit visibility
  included — is a follow-up, as the plan says ("use if trivial, not a gate").
- **Web search tool quality** (single Serper query summarised by a mini model): a separate research
  task per the pen plan's follow-ups; must not block the pen work.
- **"Name the model on create" shortcut for L1**: a follow-up only if L2 volume becomes a real cost
  (a pen-plan follow-up note, not one of the 39 decided questions).
- **PenBrandClusterer (L3)** stays in scope and is built last (S42), in the L1 shape (decide, wait,
  approve applies, reject re-queues — Q39, no undo code), but it must be live before the backlog
  drain's unknown-brand stage (S41 stage 3), because the models L2 creates from that stage have
  brand strings no brand row matches and their public pages redirect until a brand exists.
- **Deferring `PenAndInkSuggester.premium` to S37**: an optional variation, not the plan. S31 places
  the premium entry last in wave 1 with a 7-day watch window; if the owner prefers to hold it back
  until after the shadow results, that is a deliberate deviation to record in the runbook, not a fork
  left open inside S31.
- **Running the bench in CI**: not scheduled, per the decision "local machine only".
- **A shadow for the `CheckInkClustering::*` agents**: not scheduled; the decision limits the shadow
  to InkClusterer and ReviewApprover, so the checkers are flipped on the bench result alone (S37).

---

## Editor notes (verifier conflicts and judgement calls)

_Kept verbatim from the v1 roadmap; step ids below are v1 ids, as originally written, since these
notes are a historical record of how v1 was assembled, not instructions to re-implement._

- **Retry budget (Q4).** The section-4 verifier wanted Q4 moved to 4b as "implementable as is" and
  removed from every "Blocked by"; the S15-S17, S30-S32 and S12-S14 verifiers wanted the budget
  implemented somewhere on both layers (RubyLLM `max_retries` plus `sidekiq_options retry:`) and the
  pen worker capped before the drip. Both are honoured: Q4 is kept as a non-blocking question, S15
  implements it on both layers when answered and ships today's behaviour otherwise, S10 ships the
  pen worker with a proposed cap of 2 (listed under "Resolved without asking"), and Q4 is removed
  from S30.
- **Queue depth (Q24).** The section-4 verifier wanted Q24 removed from S10 entirely ("implement as
  written"); the Q20-Q38 verifier showed that the eager-log option for queued-but-not-started runs
  collides with the two janitors. The plan-decided part (waiting + processing, by name) is recorded
  as resolved; the queued-run sub-question stays on S10 as the only open P1 detail, and the
  checker-era visibility sub-question moves to S38.
- **First-level rejection cleanup and refused approvals (Q21, Q22).** Three verifiers agreed the
  plan already decides both (destroy-only-if-lonely, reject-on-refusal). Q21 keeps only the
  cross-level cascade the plan itself left open (blocks S35); Q22 keeps only the tag and admin
  message. S09 carries the plan's rule plus an implementation rule for the model micro cluster
  (destroy if unassigned and empty, leave if assigned).
- **`(name, state)` index.** Four verifiers found the "few hundred waiting rows" justification
  wrong (53,810 rows; 1.8 s cold count on prod). Two suggested adding the index in S04, two
  suggested recording the cost and revisiting. Added in S04: an engineering choice, seconds to
  build, and the count runs on every review and dashboard load from S10 on.
- **Harness location (former harness-location question).** The section-4 and Q1-Q19 verifiers showed the migration plan
  decides `lib/bench/` and none of the cited CI facts prevents it; the S00-S02 verifier wanted the
  question added to S02 instead. Removed as plan-decided; S02, S14 and S19 quote the plan line.
- **S06 column constant vs S16/S23.** Two verifiers offered two consistent options (lift the column
  into an S06 constant, or leave it to S23). Chosen: cutoffs and ef_search only in S06/S16; the
  column becomes part of S23's per-column entries (`legacy`/`current`/`read`), which S26 flips and
  S24-S26's verifier needed anyway. Section 2 and S06/S16/S23/S26 all say the same thing.
- **`RecordNotUnique` template.** One verifier said "copy `Pens::UpdateModel#update_attributes!`",
  another said that method has a `retried`-flag bug that loops forever. Both are right: S09 copies
  UpdateModel's semantics with `retried` declared before `begin` (the `UpdateMacroCluster` structure)
  and S35 fixes UpdateModel.
- **S34 freed space.** One verifier measured 8.2 GB of TOAST (6,376 + 1,822 MB), another wrote
  ~8.4 GB; the measured figure is used. Both agree DROP COLUMN frees only the indexes.
- **Monthly ink approval (Q27, section 4).** Two verifiers gave different monthly series because
  one grouped by run date and the other by decision date (up to 4.5 pp apart in a month). Both
  series are shown and the owner is asked to name the basis.
- **S31 cost.** Estimates of ~$5-10 and "at most ~$7" replaced the unexplained ~$25; the roadmap
  says "$5-10, at most the two agents' current two-week spend".
- **Bench DB refreshes (S20 vs S21).** Two verifiers flagged that S20 and S21 each implied a
  refresh. One refresh at S21; S20 exports rejected-log labels from the read-only URL if needed.
- **S35 and the cheap model.** One verifier wanted an S30/S36 edge on S35 depending on Q32; the
  volume is zero today (0 unassigned non-ignored model micro clusters with variants), so the rationale
  was changed instead and no edge added.
- **S38/S42 after S36.** The section-1/2 verifier showed neither plan gates the checkers or L3 on
  the cheap model. The edges are kept as a cost preference and marked "preferred, not required" in
  the table so the owner can pull them forward.
- **S41 size.** Changed from S to M because the brand-stage filter and the periodic refill are code;
  the months of running are calendar time, not implementer effort.
- **Q31 and S33.** The S21-S23 verifier said "only S33/S34 are blocked"; S33 does not depend on the
  final column name (it only ignores the old column), so Q31 blocks S34 alone.
- **New questions.** Four were added where verifiers found undecided design points: the vision
  constraint on ReviewApprover/ReviewFinder, the acceptance-bar statistics and the $30 cap, the
  real-time trigger vs the pending cap, and L3 approve/reject semantics. Three were removed as
  plan-decided or code-resolved (test defaults, harness location, shadow representation).
- **Prod figures.** Verifiers re-ran the SQL on different days (2026-09-12 to 2026-09-14) and got
  counts differing by tens to low hundreds (e.g. 9,333 vs 9,370 empty unassigned pen micro
  clusters, 96,711 vs 96,827 with pens, 53,808 vs 54,028 waiting logs). Ranges are shown where they
  differ; every figure should be re-counted before it is acted on.

### Decisions fold-in notes (judgement calls made while producing this v2 fragment)

- **4a scope.** All 16 rows already in v1's "Needs a re-decision by the owner" table map onto one or
  two of the 39 decided questions (Q5, Q30, Q6+Q7, Q10+Q11, Q15, Q16, Q20, Q23, Q8, Q27, Q18, Q13,
  Q24, Q17, Q36, Q39); none were "fully resolved" in the sense of becoming a non-conflict, so none
  moved to 4b — each is now a "decided against the plan text" row, per skeleton.md's instruction to
  keep the evidence column and replace only the decision column. Q32 (pen decision 6) was added as a
  17th row: it is not a code/data conflict the DIGEST found, but a deliberate strategic override of
  explicit plan text, which the skeleton file also asked to fold into this table.
- **Q10/Q11 combined row.** v1 already combined the ink-case and ReviewApprover-case conflicts into
  one row ("Labels that already exist"); I kept them combined and cited both decisions in the third
  column rather than splitting the row, since splitting would require duplicating the identical
  evidence column.
- **Step ids cited per decision (section 5).** Sourced from the v2 ordering skeleton's "changed
  by" column (section 1, "Ordering at a glance"), inverted into a Q -> steps index, then
  cross-checked against every step's individual change brief (section 3 of that file) for
  consistency. Where a brief mentions a Qn only to say "delete this sentence" (a deletion, not new
  scope), I did not list that step as shaped by the question.
- **One-line questions in section 5.** Paraphrased from the v1 bold headings rather than quoted
  verbatim, to keep 39 entries scannable; the original options/trade-offs prose is dropped
  everywhere since a decision now exists and the trade-offs no longer need weighing by the reader.
- **Q4 and Q27 "deferred" framing.** Both appear in section 5 with the decision's own "DEFERRED"
  language kept intact, and both were additionally surfaced in section 6 (not just section 4/5),
  since the task asked section 6 to "add anything the decisions defer" and both are explicitly
  marked deferred rather than merely "resolved."
- **"Resolved without asking" renumbering.** Every v1 step-number mention in that list was updated
  to its v2 id via the same numbering map; three "Veto if you disagree" sentences were deleted
  (shadow log shape, flag naming) per skeleton.md's instruction to drop veto language now that the
  owner gave no vetoes.
- **Editor notes appendix.** Left verbatim, including its v1 step numbering, per the top-level task
  instruction to "keep" it (as opposed to skeleton.md's own suggestion to rewrite it as history) —
  only the new "Decisions fold-in notes" list below it is new content.

### Assembly notes (v2 verifier pass applied 2026-09-15)

After the steps were rewritten against the decisions, fourteen verifier passes (one per step group)
re-checked every claim against the repo, the installed gems and the prod data check. Their findings
are folded into the step texts above. Where two sides disagreed, the side with the stronger evidence
won; those calls are recorded here.

- **S08, task 4 vs Q8's "349 kept" (the only genuine decision conflict).** Q8 names 7 empty models to
  delete and 349 empty assigned model micro clusters to keep. Applying the project's standard "no
  collected pens" definition AFTER task 2 destroys the 25 empty variants makes the model set 14, not
  7 — the decision's 7 is a pre-cleanup count of the same rule — and destroying those 14 orphans 7 of
  the kept model micro clusters, which task 3 then sweeps. Both numbers in the step are now stated as
  what they are: the 14-model list is named by id, and the kept count is written as 351 today falling
  to 344, not 349. The alternative (restricting task 4 to the literal 7) was rejected because it
  would leave 7 equally hollow models behind and contradict the step's own run order.
- **S29, the 87 empty-sibling-only L2 cases.** The label rule (Q8: an empty assigned sibling counts)
  and the hide rule (only variant-bearing siblings count) classified 87 cases incompatibly. The label
  rule won, because the skeleton fixes the 1,736/1,235 split; the hide branch was widened to match,
  and the 87 are reported as their own stratum since their model's name and vector cannot be
  re-derived from anything.
- **S29, where Q12's re-derivation runs.** The rewritten step attached it to the lonely-model branch,
  where `Pens::UpdateModel` provably returns early every time. It now runs on the assign branch, which
  is where the leak actually is. Same correction applied to S21's create-case model handling.
- **S05, `RubyLLM::ModelNotFoundError`.** The step asserted no distinct exception class exists. The
  gem source shows one for the local, registry-resolution case; the matcher and the rescue were
  widened rather than kept narrow.
- **S18, the `embeddings:` YAML block.** "Sibling top-level key" would have resolved to `nil` in every
  environment (`config_for` returns only `shared` merged with the current environment). It moved
  inside `shared:`.
- **S25/S32, the shadow on/off switch.** S25 shipped a switch nothing could set and S32 had nothing to
  edit. A `shadow:` block in `config/llm.yml` now carries it: S25 ships it nil everywhere, S32 fills
  it in.
- **S13/S16, hand-over exclusion.** S13's inline query excluded any cluster that had ever been handed
  over; Q23 and S16 say the LATEST log. One shared method, `Pens::MicroCluster.handed_over_to_human_ids`,
  now defines it, and both steps call it.
- **S14/S38, Q24(ii).** The pen review page renders agent-decided logs but must not count them. The
  controller now keeps two relations apart, and S14's own spec assertion was corrected to match.
- **Anchors and counts.** Roughly fifty file:line anchors, gem line numbers and prod counts were off by
  a few lines or a few rows and were corrected against the live sources (for example
  `ruby_llm_agent.rb:173-188` for `restore_transcript`, `ci.yml:16-19` for the OpenAI env block,
  `codecov.yml:10-12`, ink 797,700 / pen 210,534 embedding rows, 355 ignored pen clusters with pens,
  13 `RubyLLM::ServerError` occurrences in spec/). Where a rewritten step had dropped a v1 anchor the
  brief did not name, it was restored.
- **Two Rails-8 command errors** (`db:structure:dump`, removed in Rails 7) and **one Ruby syntax error**
  (a brace block on a paren-less `attribute :x` call) were corrected; both would have failed on the
  first run for an implementer copying the text verbatim.
