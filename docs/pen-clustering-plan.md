# Pen Clustering Automation Plan

Status: plan agreed 2026-09-12 (all open questions decided, see bottom), implementation not
started.

## Goals

1. Automate pen clustering the way ink clustering is automated today: an LLM agent proposes a
   decision, humans approve or reject in an admin queue, and once the approval rate is known a
   second-level checker agent auto-approves the easy cases.
2. Cover every manual level of the pen hierarchy, not just the first one.
3. Roll out pull-based: the agent only runs to replace decisions a human has reviewed, and
   never keeps more than a handful of unreviewed decisions waiting. Throughput, cost and
   quality of the agent are unknown, so no schedule and no bulk run until measured.
4. Reuse the benchmark harness from `docs/llm-migration-plan.md` (P1) to pick model and prompt
   against human-labelled prod data before scaling up.

Out of scope: changing the pen data model, redesigning the manual admin React apps, prompt
tuning beyond what is needed to reach a usable approval rate.

## Current state (2026-09-12, prod)

### Hierarchy

Pens have five links where inks have three. Two of them are automatic string normalisation, the
rest are manual today.

| Level | From → To                                        | How assigned today                                                                                          | Rows                                                        |
| ----- | ------------------------------------------------ | ----------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| L0    | `CollectedPen` → `Pens::MicroCluster`            | Automatic. `Pens::AssignMicroCluster`: Simplifier on brand/model/color plus a few synonym rules.            | 202,645 pens → 122,142 micro clusters                       |
| L1    | `Pens::MicroCluster` → `Pens::ModelVariant`      | **Manual.** Admin React app (`pens-micro-clusters`), Levenshtein candidate ranking in the browser.          | 16k assigned, **96,705 unassigned**, 361 ignored            |
| L1.5  | `Pens::ModelVariant` → `Pens::ModelMicroCluster` | Automatic. `Pens::AssignModelMicroCluster`: Simplifier on the variant's brand/model.                        | 7,126 variants → 3,395 model micro clusters                 |
| L2    | `Pens::ModelMicroCluster` → `Pens::Model`        | **Manual.** Admin React app (`pens-model-micro-clusters`).                                                  | 3,320 assigned, 69 unassigned (all empty, stale), 6 ignored |
| L3    | `Pens::Model` → `Pens::Brand`                    | Semi-automatic. `Pens::AssignBrand` exact name match against `Pens::Brand#names`; manual fallback in admin. | 1,798 models → 286 brands, 0 unassigned                     |

Ink equivalent: `MicroCluster` → `MacroCluster` is `InkClusterer` + `CheckInkClustering::*`,
`MacroCluster` → `BrandCluster` is `InkBrandClusterer`. So pens need agents at L1, L2 and L3.
L1 is where nearly all the work is.

### L1 backlog shape

| Pens per unassigned micro cluster | Clusters | Pens   |
| --------------------------------- | -------- | ------ |
| 1                                 | 92,630   | 92,630 |
| 2–3                               | 3,926    | 8,231  |
| 4–10                              | 135      | 671    |
| >10                               | 14       | 291    |

- 73,383 of the unassigned clusters have a brand already known in `pens_brands` / assigned
  `pens_models`; 23,322 do not.
- Top unassigned brands: Sailor 5.5k, Pilot 5.2k, Jinhao 4.9k, Platinum 3.1k, Lamy 3.1k,
  Pelikan 2.9k, Parker 2.6k, TWSBI 2.4k, Kaweco 2.4k, Franklin-Christoph 1.9k.
- Inflow: ~1,700 new micro clusters/month (~57/day), ~2,500 collected pens/month.
- Human throughput: 833 L1 assignments in Nov 2025, 405 in Dec, 61 in Jan 2026, effectively
  zero since. The backlog only grows.

### Variant granularity

A `Pens::ModelVariant` is brand + model + color + material + trim color + filling system. In
practice it is the colour/finish level: Lamy Safari has 50+ variants (Violet, Mango, Terra Red,
Charcoal…), each with 5–21 micro clusters. Users put year, edition and colour into whatever
field they like ("2016 LE Dark Lilac" as color, "‘17 LE Petrol" as color, "150 Jahre
Freundschaft" as color). The agent's main job at L1 is to recognise that these are the same
variant.

Note: variant and model attributes are **derived**, not authored. `Pens::UpdateModelVariant`
and `Pens::UpdateModel` overwrite brand/model/color/material/trim/filling with the most common
values from the collected pens on every update. Whatever a human types into the "create
variant" form is replaced on the next update. The agent therefore only has to decide
assign/create/ignore, not to author canonical names. This mirrors `MacroCluster` being created
with a UUID name and renamed by `UpdateMacroCluster`.

### What gets ignored today (361 micro clusters, sampled)

Nib units and nibs only ("Esterbrook nib only", "Pilot Vanishing Point nib unit", "Franklin-
Christoph #6 nib"), unknown/unidentified ("Parker don't know", "unknown unknown black"), clones
and fakes ("unbranded Lamy Safari clone", "fake Lamy Vista"), non-fountain-pen products (Pilot
Parallel, Neox Graphite pencil, traveling inkwell), and placeholder colours ("Opus 88 clear
color"). Ignored model micro clusters (6) are line names entered as model ("Pilot Custom",
"Sailor Shikiori") or material entered as model ("Ensso Japanese Ebonite").

### Existing building blocks

- `RubyLlmAgent` concern, `AgentLog` state machine, `RunAgent` / `RunInkClustererAgent`
  workers, `RunFailedClusterJobs`, `GoogleSearchSummarizer` for web search.
- `Pens::Model.embedding_search(query)`: three-tier pgvector search over model, variant and
  collected-pen embeddings, returns models sorted by distance with their matching variants.
  Already used by the public pen search. Hard-coded 0.6 cosine cutoff, same caveat as inks.
- `Pens::ModelVariant.search` / `Pens::Model.search`: ILIKE full text.
- `Pens::Brand#names` / `#simplified_names`: brand synonyms.
- `pen_embeddings`: 210k rows (201k collected pens, 7.1k variants, 1.8k models), 305 with a
  NULL vector. There is no embedding per `Pens::MicroCluster` (inks have one per micro
  cluster); the collected-pen embeddings play that role.
- Ink admin review UI (`Admins::Agents::InkClustererController` + view) with keyboard
  shortcuts, rejection notes, "delete history and reprocess".
- `InkClusterer` spec (1,650 lines) and `CheckInkClustering::*` specs (2,200 lines) as the
  testing template.

### Cost reference

`InkClusterer` on gpt-4.1, last 30 days: 999 runs, avg 5,337 prompt / 165 completion tokens,
roughly $0.012/run. Pen L1 prompts will be larger because variant lists are long (a Lamy Safari
candidate carries 50 variants); assume $0.015–0.02/run on gpt-4.1.

| Scope                                | Runs   | gpt-4.1 est. | Haiku-4.5-class est. (~1/5) |
| ------------------------------------ | ------ | ------------ | --------------------------- |
| Inflow, steady state                 | 57/day | ~$1/day      | ~$0.2/day                   |
| Backlog, ≥2 pens                     | 4,075  | ~$70         | ~$15                        |
| Backlog, singletons with known brand | ~70k   | ~$1,200      | ~$250                       |
| Backlog, everything                  | 96.7k  | ~$1,700      | ~$350                       |

Current total LLM spend is ~$35/month. Draining the full backlog on gpt-4.1 would cost four
years of the current bill, so the backlog waits for the cheaper model from the migration plan
and for a checker agent that removes the human bottleneck.

## Design

### Agents

Three decision agents, mirroring the ink agents one to one, plus checkers later.

**`PenVariantClusterer`** (L1, owner `Pens::MicroCluster`). Decision tools, all halting, all
requiring an explanation, all writing only `agent_log.extra_data` like `InkClusterer`:

- `assign_to_variant(variant_id, explanation)`
- `create_new_variant(explanation)` — no attributes, see "derived" above
- `ignore_pen(explanation)`
- `hand_over_to_human`

Lookup tools:

- `Tools::PenSimilaritySearchTool` — wraps `Pens::Model.embedding_search`, returns the top N
  models with distance, and for each the variants (id, name, number of micro clusters). Grouping
  variants under their model is the key difference from the ink tool: the agent must see that
  "Safari Petrol" and "Safari Dark Lilac" are sibling variants, not candidates for each other.
- `Tools::PenFullTextSearchTool` — `Pens::ModelVariant.search` fallback.
- `KnownBrand` — `Pens::Brand.simplified_names` includes the micro cluster's simplified brand.
- `Tools::PenWebSearchTool` — `GoogleSearchSummarizer` with " fountain pen" appended. Same
  sub-agent-log pattern as `InkWebSearchTool`. Open question whether to enable at first.

Prompt data: the micro cluster's distinct (brand, model, color, material, trim_color,
filling_system) tuples from collected pens with counts. Nib is deliberately excluded: it is not
part of the variant. System directive encodes the ignore policy decided in open question 3 (nib
units, unknowns, clones, non-fountain-pens, kit and self-made pens, vintage with unknown
model; calligraphy pens are real pens) and the variant definition from open
question 8 (same model and same colour/finish; year and edition markers are noise; material
and filling system never split a variant; trim colour may split only for a documented,
separately sold version).

`approve!` / `reject!` mirror `InkClusterer`:

- assign → `micro_cluster.update!(pens_model_variant_id:)`, then `Pens::UpdateMicroCluster`.
- create → `Pens::ModelVariant.create!` from the micro cluster's most common values, assign,
  then `Pens::UpdateMicroCluster` (which triggers `UpdateModelVariant` → `AssignModelMicroCluster`
  → possibly a new unassigned `Pens::ModelMicroCluster`, which is L2's trigger).
- ignore → `ignored: true`.
- human → `touch` to move it back in the queue.
- Rejection cleanup: unassign / destroy the created variant if it only holds this micro cluster
  (nullifying its micro clusters and re-queueing them) / unignore. Rejected logs with a manual
  note are fed back into the next attempt exactly like `processed_tries_data`.
- `already_resolved?` guards against the human having assigned it in the React app meanwhile.
  `approve!` re-checks that the micro cluster is still unassigned and rejects the log if not.

**`PenModelClusterer`** (L2, owner `Pens::ModelMicroCluster`). Same shape with
`assign_to_model(model_id)`, `create_new_model`, `ignore`, `hand_over_to_human`. Lookup:
similarity search restricted to `Pens::Model` embeddings, `Pens::Model.search`, known brand,
web search. Prompt data: simplified brand/model plus the names of its variants and pen count.
Triggered from `Pens::UpdateModelMicroCluster` when `pens_model_id` is nil (today that worker
just returns), behind an on/off flag but not limited by the L1 queue depth. Volume is small: it only fires when L1 creates a
variant whose simplified brand+model is new.

**`PenBrandClusterer`** (L3, owner `Pens::Model`). Mirror of `InkBrandClusterer`: full list of
286 brands with synonyms in the prompt, tools `add_to_brand(brand_id)` /
`create_new_brand`, applies immediately and logs `waiting_for_approval` like the ink version.
Triggered from `Pens::AssignBrand` when the exact match finds nothing. Lowest priority; exact
match covers the current 100%.

**`CheckPenClustering::{Assign,Create,Ignore,Human}`** (phase 4). Copy of
`CheckInkClustering::*` with pen tools and pen prompt. Only built once L1 has a measured
human approval rate; until then humans review 100% and the checker would just add cost.

### Pull-based rollout

Nothing is triggered from the collected-pen save path at first, and nothing runs on a
schedule. The agent runs only to refill a small review queue after a human has emptied part of
it. No review, no runs, no spend.

- `TopUpPenClusteringQueue` worker. Reads `PEN_CLUSTERING_QUEUE_DEPTH` (default `0` = off,
  planned prod value `10`). Counts `PenVariantClusterer` logs in `waiting-for-approval` or
  `processing`; if below the target it enqueues one `RunPenClustererAgent` per missing slot
  from the priority order below. Idempotent, so calling it twice is harmless.
- Trigger: the admin review controller enqueues `TopUpPenClusteringQueue` after every human
  approve or reject. Reviewing 3 decisions refills 3; not reviewing for a week costs nothing.
  A run that ends without a reviewable log (empty micro cluster, error) also calls the top-up
  so the queue does not silently shrink. `RunFailedClusterJobs` re-enqueues stuck
  `processing` logs but never adds new ones.
- `RunPenClustererAgent`: own throttled worker, concurrency 1, `agents` queue, so pen runs
  never starve `RunInkClustererAgent`.
- Priority order for the L1 queue: most collected pens per micro cluster first, random
  after that. Same ordering the manual review app uses. No brand preference: the hand-review
  phase should see a mix of everything the data contains.
- Only L1 is gated by the queue depth. L2 and L3 run whenever their trigger fires, with every
  decision reviewed by a human. Their volume is small enough to clear in a day.
- Real-time triggering from `Pens::UpdateMicroCluster` (with the 30s debounce inks use) is
  phase 5, after the checker exists and approval rates are known. With a checker in place the
  queue depth counts only logs that still need a human, so agent-approved logs do not block
  refills.

### Admin

- `Admins::Agents::PenVariantClustererController` + `PenModelClustererController`, views
  extracted from the ink clusterer view into a shared partial (state, extra data, owner dump,
  transcript, approve/reject/reject-with-note, shortcuts). Same reject-and-reprocess and
  delete-history semantics.
- Dashboard: pending-review counts for pen agents next to the existing pen cluster counts.
- The existing React apps stay as the "hand over to human" destination. They should show a
  marker on micro clusters that have a pending agent log so the human does not double-work.
- `AgentLog.with_collected_inks` is ink-specific; replace with a generic "owner still has
  members" scope or per-agent scopes.

### Bench

Extends the harness from the migration plan (P1) with pen cases. Ground truth is today's
state, leave-one-out, exactly as for inks:

- L1 label: the 16k human-assigned micro clusters. Null out `pens_model_variant_id` inside a
  rolled-back transaction; if the variant has other micro clusters expect
  `assign_to_variant(id)`, else expect `create_new_variant` and also hide the variant's own
  `pen_embeddings` row. The 361 ignored expect `ignore_pen`. Stratify: singleton vs multi-pen
  cluster, known vs unknown brand, big model (Safari, Vanishing Point) vs rare.
- L2 label: the 3,320 assigned model micro clusters, same trick on `pens_model_id`.
- Same caveat as inks: today's DB is richer than at decision time, so numbers are relative, not
  historical.
- Rejected logs will accumulate once phase 1 runs and become the hard-negative subset.
- Retrieval sanity check first: does `Pens::Model.embedding_search` even return the correct
  variant's model in its top 20 for the leave-one-out set? If recall@20 is poor, no prompt will
  fix it and the tool needs work before the agent is built (see migration plan P2 for the
  embeddings-side bench of the same question).

### Interaction with the LLM migration plan

- Build the agents on `MODEL_ID = "gpt-4.1"` like the ink agents now; adopt the per-agent
  config from migration P0 when it lands. Do not block on it.
- The pen bench cases live in the shared harness and are also what migration P2/P3 use to
  evaluate embeddings and chat models for pens. Build them once.
- Do not drain the backlog before migration P3 picks a cheaper chat model. Inflow and the
  multi-pen backlog are affordable on gpt-4.1; the singleton backlog is not.
- If migration P2 swaps embeddings, `Pens::Model.embedding_search`'s 0.6 cutoff changes, and
  the L1 bench must be re-run.

## Phases

### P0 — Groundwork (no behaviour change)

- `Pens::MicroCluster` and `Pens::ModelMicroCluster` get `has_many :agent_logs, as: :owner,
dependent: :destroy`. Generic replacement for `AgentLog.with_collected_inks`.
- `Tools::PenSimilaritySearchTool`, `Tools::PenFullTextSearchTool`, `Tools::PenWebSearchTool`
  with specs. Measure `embedding_search` latency on prod-sized data; it loads up to 2,400
  embedding rows per call.
- Clean up stale rows: 69 empty unassigned model micro clusters, 5 empty variants, 305
  `pen_embeddings` with NULL vectors (re-enqueue `FetchEmbedding`).
- Retrieval sanity check (bench-lite): script over ~200 leave-one-out L1 cases reporting
  whether the correct model/variant appears in `embedding_search` top 20. This is cheap (no
  chat calls) and decides whether the tool needs work before P1.

### P1 — `PenVariantClusterer` behind a flag

- Agent, decision tools, `approve!`/`reject!`, `already_resolved?`, rejected-try feedback.
- `RunPenClustererAgent`, `TopUpPenClusteringQueue` (queue depth default 0, triggered from the
  review controller), `RunFailedClusterJobs` extension.
- Admin review controller + shared view partial + dashboard counts + pending marker in the
  React app.
- Specs modelled on `spec/agents/ink_clusterer_spec.rb`: tool unit tests, WebMock
  integration per action, approve/reject side effects and cleanup, resolved-meanwhile guard,
  top-up gating (never exceeds depth, no-op when off).
- Ship with `PEN_CLUSTERING_QUEUE_DEPTH=0`. Set it to `10` in prod and trigger the first
  top-up by hand from the console. From then on the queue refills only as fast as decisions are
  reviewed. Review every decision by hand for a couple of weeks. Track per action: approval rate, hand-over rate,
  `DecisionNotReachedError` rate, tokens and latency per run. Rejection notes are the prompt
  tuning input.

### P2 — Bench cases and tuning

- Pen case exporter and leave-one-out runner in the shared harness (migration P1). If the
  harness is not there yet, this phase builds the pen half of it.
- Run gpt-4.1 baseline on ~200 L1 cases, stratified. Compare to the prod approval rate from P1
  as a sanity check that bench and prod agree.
- Iterate on the system directive against the bench, not against prod. Raise the prod queue
  size once bench and prod both look acceptable (target: at least the ink clusterer's ~85%
  human approval rate).

### P3 — `PenModelClusterer` (L2)

- Same shape as P1, triggered from `Pens::UpdateModelMicroCluster` behind the same flag.
- Human review of every decision. Volume will be low until L1 creates many variants.
- Bench cases from the 3,320 assigned model micro clusters.

### P4 — Checker agents and auto-approval

- `CheckPenClustering::{Assign,Create,Ignore,Human}` copied from the ink checkers.
- Enable once L1 human approval is stable. Admin view then shows the same "correct auto
  review" percentages as the ink view.
- Raise the queue depth; agent-approved logs no longer count against it, so throughput is
  bounded by the checker's rejection rate rather than by human review time.

### P5 — Real-time trigger, backlog, brand agent

- `Pens::UpdateMicroCluster` enqueues the L1 agent with debounce for new and edited pens.
- Backlog drain in priority order, on the cheap model chosen in migration P3, still gated by
  the pending cap. Decide then whether singletons with unknown brands are worth running at all.
- `PenBrandClusterer` as fallback for `Pens::AssignBrand`.

## Follow-ups (not part of this plan)

- Web search tool quality. `GoogleSearchSummarizer` is a single Serper query summarised by
  gpt-4.1-mini. It is basic and sometimes wrong, and both `InkClusterer` and the pen agents
  depend on it. Worth a separate research task: better queries, multiple queries, reading
  result pages, or a different search backend. Must not block the pen clustering work.
- "Name the model on create" shortcut for L1 if L2 volume turns out to be a real cost (see
  open question 1).

## Open questions

Answers decide the shape of P1, so they come before implementation.

1. **Decision scope of L1.** Decided 2026-09-12: pure micro cluster → variant. Keep each
   agent's task small and the levels decoupled, automate one level at a time. Less context
   per agent tends to give better results. The "name the model on create" shortcut stays a
   possible follow-up if L2 volume turns out to be a real cost.
   To investigate before P3: what a human rejection at one level does to decisions already
   taken at the next level (L1 creates a variant → L2 assigns its new model micro cluster to a
   model → human rejects the L1 creation and the variant is destroyed). The L2 log, the model
   micro cluster and possibly a freshly created model need a defined cleanup path.
2. **What to run first.** Decided 2026-09-12: most collected pens per micro cluster first,
   random after that, no known-brand preference. L2 and L3 are not queue-limited.
3. **Ignore policy.** Decided 2026-09-12. L1 ignores: nib units and bare nibs; brand or
   model that literally says unknown or is a placeholder ("don't know", "?"); clones, fakes and
   unbranded copies; non-fountain-pen products (pencils, ballpoints, rollerballs, inkwells,
   accessories); kit pens and self-made one-offs (products of small makers are real pens);
   vintage pens whose model is genuinely unknown. L2 ignores model micro clusters whose model
   is really a line name or a material. Not ignored: calligraphy pens such as Pilot Parallel
   (they are fountain pens), and micro clusters that are merely malformed (placeholder colour
   on a real pen), which should be assigned instead. Obscure but real names are handed over to
   a human rather than ignored, because ignoring is permanent and hand-over is not.
4. **Web search at L1.** Decided 2026-09-12: on from the first run, same tool as inks with
   " fountain pen" appended. Watch the calls-per-run ratio during hand review. The tool
   itself (Serper query, gpt-4.1-mini summary) is basic and not always right; making it more
   reliable is its own research task for both ink and pen agents, see follow-ups.
5. **Queue depth.** Decided 2026-09-12: pull-based, no schedule, refill to ~10 unreviewed
   decisions after each human review. Open detail: should `processing` logs count towards the
   depth (proposed yes, otherwise a slow run lets the queue overshoot)?
6. **Model.** Decided 2026-09-12: gpt-4.1 with a constant `MODEL_ID`, same pattern as
   `InkClusterer`, no dependency on the migration plan. Approval rates stay comparable to the
   ink baseline; the bench picks a cheaper model later.
7. **Bench ordering.** Decided 2026-09-12: retrieval sanity check (P0), then the
   hand-reviewed prod drip (P1), then the full bench (P2) built in parallel and used for
   prompt and model tuning. Rejected prod decisions feed the bench's hard-negative subset.
8. **Variant definition.** Decided 2026-09-12: a variant is the model in one colour or
   finish. Material and filling system never split a variant; they are weak confirming
   signals, and users spell them inconsistently ("C/C", "Converter", "Cartridge/Converter" all
   live in one Lamy Safari variant today). Trim colour is the one exception: when the same
   colour is a documented, separately sold version with different trim (gold vs silver), it
   may be its own variant. Otherwise same model plus same colour means the same variant. Nib
   is not part of a variant. Year, "LE"/"SE" and edition markers are noise. Data check: 7,116
   of 7,121 existing brand/model/colour groups are a single variant; the 5 splits are
   accidental duplicates.
