# LLM Provider Migration Plan

Status: plan agreed 2026-09-11, implementation not started. `docs/implementation-roadmap.md` is
the authoritative ordering across this plan and the pen clustering plan; the owner's 2026-09-14
decisions there supersede several rows below (marked inline).

## Goals

1. Move all LLM usage (chat completions and embeddings) from OpenAI direct to DigitalOcean
   serverless inference (`https://inference.do-ai.run/v1`). DO is the only provider afterwards.
2. Make provider and model per agent configurable without code changes.
3. Build a benchmark harness so model and prompt changes can be evaluated against real,
   human-labelled prod data.
4. Keep quality within 1–2 percentage points of the current gpt-4.1 / gpt-4.1-mini setup.
   Keep the bill flat at worst. Flexibility matters more than savings.

Out of scope for this project: prompt tuning (follow-up using the bench), RubyLLM 2.0 upgrade.

## Current state (2026-09-11)

- Everything goes through RubyLLM 1.16 (`RubyLlmAgent` concern, `EmbeddingsClient`). No raix left.
- Chat models: `gpt-4.1` (InkClusterer, CheckInkClustering::*, ReviewFinder, InkBrandClusterer,
  PenAndInkSuggester for patrons) and `gpt-4.1-mini` (everything else).
- Embeddings: `text-embedding-3-small`, 1536 dims, pgvector HNSW cosine on `ink_embeddings`
  and `pen_embeddings`. Neither gpt-4.1 nor text-embedding-3-small exists in the DO catalog,
  so migration implies a model change for every call site.
- Keys: per-agent `OPEN_AI_<AGENT>_TOKEN` with fallback `OPEN_AI_TOKEN`; `OPEN_AI_EMBEDDINGS`;
  `OPEN_AI_DEV_TOKEN` in development. Bug: `OPEN_AI_PEN_AND_INK_SUGGESTION` and
  `OPEN_AI_SPAM_CLASSIFIER` lack the `_TOKEN` suffix and are never matched.
- Spend, last 90 days, list prices: roughly $105 total (~$35/month). gpt-4.1 agents ~$85,
  mini agents ~$20. Absolute savings potential is small.

Prod volume, last 90 days:

| Agent                  | Model    | Runs/day | Avg prompt tok |
| ---------------------- | -------- | -------- | -------------- |
| GoogleSearchSummarizer | mini     | 42       | 1,000          |
| InkClusterer           | 4.1      | 33.5     | 4,800          |
| CheckInkClustering::\* | 4.1      | 33       | 3,500–4,100    |
| ReviewFinder           | 4.1      | 26       | 4,300          |
| YoutubeSummarizer      | mini     | 23       | 1,400          |
| PenAndInkSuggester     | mini/4.1 | 18.6     | 6,800          |
| ReviewApprover         | mini     | 8.6      | 21,400         |
| WebPageSummarizer      | mini     | 1.8      | 34,400         |
| InkBrandClusterer      | 4.1      | 1        | 16,400         |
| SpamClassifier         | mini     | 0.1      | 33,500         |

## Labels that already exist

`agent_logs` carries human verdicts (`state` approved/rejected with `agent_approved = false`):

- InkClusterer: ~9,970 approved, ~1,790 rejected by humans. Every one of these micro clusters
  still exists in prod. Bench case rule (Q10): (i) one case per micro cluster, the latest
  human-labelled run; (ii) exclude approved hand-over cases and approved-but-unassigned-today
  cases; (iii) an approved create that was later merged counts as ASSIGN to the merged cluster;
  (iv) rejected-try feedback is HIDDEN by default, with an optional `--with-feedback` mode.
- ReviewApprover: ~10,200 decisions; `ink_reviews` has ~27k approved / ~16k rejected. Bench case
  rule (Q11): the latest run per review, human-confirmed verdicts only, dropping reviews with
  contradictory decisions (~5,800-6,000 usable cases).
- CheckInkClustering::\*: the checker's own child log is always left `waiting_for_approval`
  forever by design, so its own log is a weak label — **but its verdict is copied onto the
  parent InkClusterer log as `extra_data.follow_up_action`, and crossing that with the parent's
  human verdict gives a strong label**: correct iff (`follow_up_action == "approve"` AND
  `state == "approved"`) OR (`"reject"` AND `"rejected"`), exactly the admin view's own
  "correct auto review" computation. Treat these as strong labels, not weak ones.
- Summarizers, PenAndInkSuggester, ReviewFinder, InkBrandClusterer, SpamClassifier: no usable labels.
- Pen bench honesty (Q12/Q13): the pen L1 labelled set is 99% multi-pen micro clusters while the
  real backlog is 96% singletons, so the bench must OVER-SAMPLE singleton cells and, for each
  singleton case, re-derive the held-out variant's (and single-variant model's) name and
  embedding from the remaining pens inside the same rolled-back transaction (one extra embedding
  call per case) rather than reuse the pre-existing name/embedding. Ignore-label cases that
  violate the decided ignore policy are EXCLUDED from the bench entirely.

### Ground truth for clustering: today's state, leave-one-out

Replaying an old InkClusterer run against today's DB is not comparable to the historical
verdict, because the DB has grown since. Rolling the DB back is not possible (merges, renames
and embedding rewrites leave no history). Instead:

- Label = the micro cluster's **current** state after human review:
  - `macro_cluster_id` set and the macro cluster has other micro clusters → expect
    `assign_to_cluster(macro_cluster_id)`
  - `macro_cluster_id` set and the macro cluster contains only this micro cluster → expect
    `create_new_cluster`
  - `ignored = true` → expect `ignore_ink`
- Rejected logs are hard negatives with a known correction. Report them as a separate subset.
- Leave-one-out in the bench DB, per case, inside a transaction that is rolled back:
  1. Set the case micro cluster's `macro_cluster_id` to NULL and `ignored` to false. Because
     `MacroCluster.embedding_search`, `full_text_search` and the `KnownBrand` tool all join
     through `micro_clusters.macro_cluster_id`, the micro cluster and its collected inks
     disappear from search results.
  2. If the macro cluster was lonely, also hide its own `ink_embeddings` row.
  3. Run the agent with live tools against the bench DB. Decision tools only write
     `agent_log.extra_data`; capture the action and cluster id, then roll back.
  4. Compare to the expected action/cluster.
- Caveat, stated up front: today's DB is richer than at decision time, so the task is easier
  than the original run. This affects every model equally, including the gpt-4.1 baseline
  rerun, so it is valid for relative comparison but not comparable to historical approval rates.
- CheckInkClustering::\* is benched the same way: run InkClusterer leave-one-out, feed the
  result to the checker, expected verdict = whether that result matches today's state.

The same idea gives a retrieval benchmark for embeddings (see P2).

## Decisions

| Topic                                    | Decision                                                                                        |
| ---------------------------------------- | ----------------------------------------------------------------------------------------------- |
| Provider                                 | DigitalOcean serverless inference only. Anthropic/OpenAI/open models via the DO catalog.        |
| Config format (Q1)                       | YAML file in the repo, `config/llm.yml`, keyed by agent class name with a shared default block; |
|                                          | secrets are referenced by env var name, not stored in the file. The four ink checkers           |
|                                          | (`CheckInkClustering::*`) share ONE entry. `PenAndInkSuggester`'s patron tier is a SECOND plain |
|                                          | entry (e.g. `PenAndInkSuggester.premium`); the agent picks the entry name at runtime.           |
| Override hook (Q2)                       | A scoped, temporary override keyed by agent class, active only inside one bench/shadow call,    |
|                                          | thread-safe for concurrent Sidekiq jobs. Specs must reset it after each example.                |
| Keys (Q3)                                | Keep `OPEN_AI_TOKEN` and `OPEN_AI_EMBEDDINGS` until retirement; add ONE new DigitalOcean key    |
|                                          | name (e.g. `DO_INFERENCE_TOKEN`). The misnamed `OPEN_AI_PEN_AND_INK_SUGGESTION` and             |
|                                          | `OPEN_AI_SPAM_CLASSIFIER` (missing the `_TOKEN` suffix, never actually matched) disappear       |
|                                          | rather than get fixed.                                                                          |
| Failure handling / retries (Q4 deferred) | Sidekiq retries only; no second provider, no cross-model fallback. Retry tuning itself is       |
|                                          | DEFERRED — keep today's behaviour (HTTP 3x + Sidekiq default 25 + Honeybadger threshold 3)      |
|                                          | as-is and revisit after the first DO cutover flips. Exception already decided:                  |
|                                          | `RunPenClustererAgent` ships with `sidekiq_options retry: 2`.                                   |
| Cost attribution (Q5)                    | Bench-only, from a hand-maintained price table. NO app change to `agent_logs.usage`, NO         |
|                                          | per-model admin graph. The v1 usage/cost-fields step is dropped entirely; cost lives in the     |
|                                          | bench price table (roadmap S20-harness-core-ink). Q5 calls that step "S17", a v1 id — in v2     |
|                                          | numbering S17 is the bench-database step, which is NOT dropped.                                 |
| Acceptance bar per agent (Q16)           | Point estimate within 1pp of baseline (2pp for ReviewApprover) AND overlapping confidence       |
|                                          | intervals counts as a pass; cost per run ≤ current; judged agents ≥ baseline; summarizers via   |
|                                          | their parent agents. Bench spend stays capped at ~$30/round: ~100 ReviewApprover cases per      |
|                                          | candidate (200 only for the finalist), two or three candidates for the checkers. Q16 re-specs   |
|                                          | only those cells; other labelled agents keep the default of ~200 cases per candidate over the   |
|                                          | 5-6-candidate short list, with Sonnet-class only as an upper bound on a small subset.           |
| Sub-agent model (Q14)                    | A sub-agent called inside an agent under test — `GoogleSearchSummarizer` inside `search_web`,   |
|                                          | the Youtube/WebPage summarizers inside `ReviewApprover`'s Summarize tool — runs on the SAME     |
|                                          | CANDIDATE model as the agent under test, in both bench and shadow.                              |
| Vision constraint (Q15)                  | `ReviewApprover` and `ReviewFinder` both keep the thumbnail (not just `YoutubeSummarizer`);     |
|                                          | their chat-model candidates are limited to vision-capable DO models. No prompt change.          |
| Shadow phase                             | InkClusterer and ReviewApprover, ~2 weeks, before cutover of those two agents.                  |
| Bench DB (Q6 / Q7)                       | A second database in the SAME Postgres container as the app's dev DB, selected by one env var — |
|                                          | not a separate container. Full prod copy including pen embeddings (~10 GB), NO PII blanking,    |
|                                          | no retention rule. Refreshed before MAJOR rounds only; minor rounds re-export cases from the    |
|                                          | existing copy.                                                                                  |
| Bench code / data                        | Harness lives in the repo. Exported cases and results are gitignored.                           |
| Judge for unlabelled agents              | No API judge. Bench exports side-by-side files; Claude Code (team subscription) grades them.    |
| YoutubeSummarizer thumbnail              | Keep. Candidates for that agent must support image input — see vision constraint (Q15) above,   |
|                                          | which applies the same rule to ReviewApprover/ReviewFinder.                                     |
| Prompt tuning                            | After migration, separate PRs, using the bench.                                                 |
| RubyLLM                                  | Stay on 1.16. `openai_api_base` + `assume_model_exists: true` is enough.                        |
| Prompt caching                           | Best-effort spike in P0. Use if trivial, not a gate.                                            |
| Embedding backfill on prod               | Throttled via low queue over hours; `CREATE INDEX CONCURRENTLY` off-peak.                       |
| HNSW index build (Q30)                   | Built BY HAND at a quiet hour from a detached session (not an interactive `fly console`), with  |
|                                          | `SET maintenance_work_mem = '1GB'`; then merge a migration that records the index with          |
|                                          | `if_not_exists: true` + `algorithm: :concurrently` + `disable_ddl_transaction!`. DEFAULT index  |
|                                          | parameters — no custom `m` / `ef_construction`.                                                 |
| Embedding column name (Q31)              | Stays `embedding_v2` (or the config-driven name) forever — no rename once cutover is done. No   |
|                                          | rename step is scheduled: v1's "S34b" placeholder (a repeat of the                              |
|                                          | add/dual-write/backfill/flip/drop sequence, roadmap S24-S35) does not exist.                    |
| Model-not-found alerting (Q33)           | Explicit alert on "model not found" errors (matching the provider's error), plus a runbook line |
|                                          | per agent naming a manual replacement model. Small PR before the first ink flip; scheduled as   |
|                                          | its own step (roadmap S05-model-not-found-alert).                                               |
| Bench execution                          | Local machine only, not CI. Baseline rerun uses the existing OpenAI key during the bench only.  |

## Phases

Order matters: embeddings go first because the InkClusterer bench depends on
`embedding_search`. Choosing a chat model on old embeddings and then swapping embeddings would
invalidate the comparison.

### P0 — Configuration layer (no behaviour change)

- Central config (`config/llm.yml` or ENV-backed) with per-agent `provider`, `model`,
  `api_base`, key env var. `MODEL_ID` constants become defaults. Embeddings get the same
  treatment (`model`, `dimensions`, column name).
- `RubyLlmAgent#ruby_llm_context` and `EmbeddingsClient#context` build from that config.
  `EmbeddingsClient` cache key must include the model name.
- Fix the `_TOKEN` env var mismatch.
- Spike against DO with one agent in development: `tool_choice: required` (`ask!`), parallel
  tool calls, transcript restore with the OpenAI tool-call invariants, image attachments,
  `/v1/embeddings`, prompt caching. Record findings in this doc. Per Q32, this same spike also
  picks the pen agents' starting model (whichever candidate handles forced tool choice and
  transcript replay cleanly) — record that pick and its date here too.
- Ship with OpenAI still the default. Zero prod risk.
- **This phase now precedes the pen agent work** (roadmap: S04-llm-config-chat comes before the pen
  agent steps S06 and S10-S16; Q32 states this with v1 step numbers, which the v2 renumbering has
  since inverted). The pen
  agents (`PenVariantClusterer` and friends, see `docs/pen-clustering-plan.md`) are born as a
  config entry pointing at the DO model this spike picked, rather than being built on a
  hard-coded `gpt-4.1` and adopting config later — see Q32 there.

### P1 — Bench DB and harness

- Script to `pg_dump` prod via the read-only URL and restore into a local `bench` database.
- Case exporter: pulls N cases per agent from `agent_logs` (first user message, owner id,
  original decision, label per the rules above) into gitignored JSON under `bench/data/`.
  Stratify by action and by approved/rejected.
- Runner (`lib/bench/`, rake task, not RSpec): instantiates an agent with injected
  provider/model, runs it against the bench DB with live tools, per-case transaction rollback,
  record/replay cache for the web search tool, captures action, cluster id, tool calls,
  tokens, cost, latency, `DecisionNotReachedError` rate.
- Report: table per agent × model. Split metrics for approved vs rejected cases. Confidence
  intervals at n≈200 are wide, so report them.
- Export mode for unlabelled agents: markdown/JSON with baseline vs candidate output per
  case, for manual grading in Claude Code. Rubric per agent (PenAndInkSuggester: pen and ink
  exist in the user's collection, pairing rationale coherent; summarizers: facts preserved,
  nothing invented).
- Dev/test split of cases so later prompt tuning does not overfit.

### P2 — Embeddings bench and cutover

Candidates on DO (all 1024 dims): BGE-M3 ($0.02/M), E5-Large-v2 ($0.02/M),
Qwen3-Embedding-0.6B ($0.04/M), GTE-large-en-v1.5 ($0.09/M). Full re-embed of all
~1M rows is roughly 8–10M tokens, under $1 per model.

- Bench table `bench_embeddings(model, owner_type, owner_id, embedding)`, brute-force cosine,
  no index needed for a few hundred queries.
- Ink retrieval: leave-one-out set, query = micro cluster names, expected = its macro cluster.
  Recall@1/5/20 through the same three-tier logic as `MacroCluster.embedding_search`.
- Pen retrieval (`pen_models_controller` search is user-facing): query = collected pen name,
  expected = its `Pens::Model`. Recall@k.
- Threshold recalibration: `embedding_search` hard-codes a 0.6 cosine-distance cutoff. This is
  model-specific. Report recall across cutoffs and pick a new threshold for the chosen model.
- Cutover, zero downtime:
  1. Add `embedding_v2 vector(1024)` on `ink_embeddings` and `pen_embeddings`.
  2. Throttled backfill worker with batched inputs. Dual-write new rows to both columns.
  3. `CREATE INDEX CONCURRENTLY` (HNSW, cosine) off-peak.
  4. Config flag switches reads and query embedding to the new column/model. Flip. Pause the pen
     drip for the flip day (Q29): set `PEN_CLUSTERING_QUEUE_DEPTH=0` before the flip, back to `10`
     the next day, and record the boundary in the drip's per-action stats series.
  5. Watch InkClusterer approval rate and pen search for a week, then drop old column and index.

### P3 — Chat model bench

Candidates on DO: Claude Haiku 4.5, DeepSeek V4 Pro, Kimi K2.6, Qwen3.8-Max, GLM-5.3,
Claude Sonnet 5 (upper bound, small subset only). Baseline: gpt-4.1 / gpt-4.1-mini rerun on
the identical case set. Vision-capable candidates only for `YoutubeSummarizer`, `ReviewApprover`
and `ReviewFinder` (Q15 — the thumbnail constraint isn't unique to the summarizer). This wave's
_cutover_ covers the ink agents only. The pen agents ARE benched in the same round, with the S01
starting DO model as their baseline (roadmap S30); a different pick lands as a plain `config/llm.yml`
PR (roadmap S33 for L1, S36 for L2), not a cutover — per Q32 there is no pen cutover step.

- Run per agent, pick the cheapest candidate that meets the acceptance bar.
- Agents without labels or with negligible volume (SpamClassifier ~10 runs/90d): switch to the
  cheap tier pick, spot check outputs.
- Record chosen model, metrics and bench round date in this doc.

### P4 — Shadow run

InkClusterer and ReviewApprover only, ~2 weeks. Candidate runs alongside prod with tools in
read-only mode and no side effects. Representation (resolved without asking, see the roadmap):
shadow runs are stored under a distinct log name (`InkClusterer::Shadow`,
`ReviewApprover::Shadow`), created already in a terminal state with `extra_data["shadow"] =
true`, and run synchronously right next to the prod decision (not queued for later) so the
shadow sees the same world the prod run saw; they are excluded from the Human checker's
previous-logs tool. Compare to
the prod decision and, once available, the human verdict. Guards against bench/prod drift.

### P5 — Chat cutover

Config flip per agent, starting with low-risk summarizers, then ReviewFinder/InkBrandClusterer,
then ReviewApprover and InkClusterer after shadow results. These waves cover the ink agents
only — per Q32 the pen agents are on DO from the moment they are built (P0's spike), so there is
no separate pen cutover wave here. Retire OpenAI keys once embeddings (P2) and all agents are on
DO.

## Follow-ups (not part of this plan)

- Prompt tuning per agent with the bench; ReviewApprover, WebPageSummarizer and
  SpamClassifier carry very large prompts.
- RubyLLM 2.0 upgrade.
- Prompt caching if the P0 spike shows it needs work.
