# LLM Provider Migration Plan

Status: plan agreed 2026-09-11, implementation not started.

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
  still exists in prod.
- ReviewApprover: ~10,200 decisions; `ink_reviews` has ~27k approved / ~16k rejected.
- CheckInkClustering::\*: mostly still waiting for approval; weak labels.
- Summarizers, PenAndInkSuggester, ReviewFinder, InkBrandClusterer, SpamClassifier: no usable labels.

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

| Topic                       | Decision                                                                                       |
| --------------------------- | ---------------------------------------------------------------------------------------------- |
| Provider                    | DigitalOcean serverless inference only. Anthropic/OpenAI/open models via the DO catalog.       |
| Failure handling            | Sidekiq retries only. No second provider, no cross-model fallback.                             |
| Keys                        | One DO prod key, one DO dev key. Cost attribution via existing `agent_logs.usage` graphs.      |
| Acceptance bar per agent    | Cost per run ≤ current. InkClusterer/CheckInkClustering within 1pp of baseline agreement,      |
|                             | ReviewApprover within 2pp, judged agents ≥ baseline, summarizers via their parent agents.      |
| Shadow phase                | InkClusterer and ReviewApprover, ~2 weeks, before cutover of those two agents.                 |
| Bench spend cap             | ~$30 per full round. ~200 cases per labelled agent, 5–6 candidates, Sonnet-class only as       |
|                             | upper bound on a small subset.                                                                 |
| Bench DB                    | Full prod dump incl. pen embeddings (~10 GB) into local docker Postgres. Refreshed per round.  |
| Bench code / data           | Harness lives in the repo. Exported cases and results are gitignored.                          |
| Judge for unlabelled agents | No API judge. Bench exports side-by-side files; Claude Code (team subscription) grades them.   |
| YoutubeSummarizer thumbnail | Keep. Candidates for that agent must support image input.                                      |
| Prompt tuning               | After migration, separate PRs, using the bench.                                                |
| RubyLLM                     | Stay on 1.16. `openai_api_base` + `assume_model_exists: true` is enough.                       |
| Prompt caching              | Best-effort spike in P0. Use if trivial, not a gate.                                           |
| Embedding backfill on prod  | Throttled via low queue over hours; `CREATE INDEX CONCURRENTLY` off-peak.                      |
| Bench execution             | Local machine only, not CI. Baseline rerun uses the existing OpenAI key during the bench only. |

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
  `/v1/embeddings`, prompt caching. Record findings in this doc.
- Ship with OpenAI still the default. Zero prod risk.

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
  4. Config flag switches reads and query embedding to the new column/model. Flip.
  5. Watch InkClusterer approval rate and pen search for a week, then drop old column and index.

### P3 — Chat model bench

Candidates on DO: Claude Haiku 4.5, DeepSeek V4 Pro, Kimi K2.6, Qwen3.8-Max, GLM-5.3,
Claude Sonnet 5 (upper bound, small subset only). Baseline: gpt-4.1 / gpt-4.1-mini rerun on
the identical case set. Vision-capable candidates only for YoutubeSummarizer.

- Run per agent, pick the cheapest candidate that meets the acceptance bar.
- Agents without labels or with negligible volume (SpamClassifier ~10 runs/90d): switch to the
  cheap tier pick, spot check outputs.
- Record chosen model, metrics and bench round date in this doc.

### P4 — Shadow run

InkClusterer and ReviewApprover only, ~2 weeks. Candidate runs alongside prod with tools in
read-only mode and no side effects, writing an `agent_log` flagged `shadow: true`. Compare to
the prod decision and, once available, the human verdict. Guards against bench/prod drift.

### P5 — Chat cutover

Config flip per agent, starting with low-risk summarizers, then ReviewFinder/InkBrandClusterer,
then ReviewApprover and InkClusterer after shadow results. Retire OpenAI keys once embeddings
(P2) and all agents are on DO.

## Follow-ups (not part of this plan)

- Prompt tuning per agent with the bench; ReviewApprover, WebPageSummarizer and
  SpamClassifier carry very large prompts.
- RubyLLM 2.0 upgrade.
- Prompt caching if the P0 spike shows it needs work.
