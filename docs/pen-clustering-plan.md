# Pen Clustering Automation Plan

Status: plan agreed 2026-09-12 (all open questions decided, see bottom), implementation not
started. `docs/implementation-roadmap.md` is the authoritative ordering across this plan and
the LLM migration plan; the owner's 2026-09-14 decisions there supersede several items below
(marked inline).

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
candidate carries 50 variants); assume $0.015–0.02/run at gpt-4.1-class pricing, used here only
as a reference price point. Per Q32, the pen agents never actually run on gpt-4.1: they launch
on whichever DigitalOcean model the S01 compatibility spike picks, so the real per-run cost is
whatever that model's DO pricing works out to — re-price this table once the spike records its
pick.

| Scope                                | Runs   | gpt-4.1-class ref. est. | Haiku-4.5-class est. (~1/5) |
| ------------------------------------ | ------ | ----------------------- | --------------------------- |
| Inflow, steady state                 | 57/day | ~$1/day                 | ~$0.2/day                   |
| Backlog, ≥2 pens                     | 4,075  | ~$70                    | ~$15                        |
| Backlog, singletons with known brand | ~70k   | ~$1,200                 | ~$250                       |
| Backlog, everything                  | 96.7k  | ~$1,700                 | ~$350                       |

Current total LLM spend is ~$35/month. Draining the full backlog at gpt-4.1-class pricing would
cost four years of the current bill, so the backlog waits for the cheap chat model migration P3
picks and for a checker agent that removes the human bottleneck.

## Design

### Agents

Three decision agents, mirroring the ink agents one to one, plus checkers later.

**`PenVariantClusterer`** (L1, owner `Pens::MicroCluster`). Decision tools, all halting, all
requiring an explanation, all writing only `agent_log.extra_data` like `InkClusterer`:

- `assign_to_variant(variant_id, explanation)`
- `create_new_variant(explanation)` — no attributes, see "derived" above. The tool itself first
  checks for an existing identical variant row; if one is found it returns a message telling the
  model to assign instead (not a `halt`, so the model can retry with `assign_to_variant`). This is
  the only duplicate-prevention mechanism (Q20); the same pattern applies to
  `create_new_model`/`create_new_brand` at L2/L3.
- `ignore_pen(explanation)`
- `hand_over_to_human`

Lookup tools:

- `Tools::PenSimilaritySearchTool` — wraps `Pens::Model.embedding_search`, returns the top N
  models with distance, and for each the top K variants by micro-cluster count (id, name, count),
  K a public constant (15), plus an "and N more variants" line when the model has more;
  `PenFullTextSearchTool` finds the rest, and the bench reports capped cases as their own stratum
  (Q17). Grouping variants under their model is the key difference from the ink tool: the agent must
  see that "Safari Petrol" and "Safari Dark Lilac" are sibling variants, not candidates for each
  other.
- `Tools::PenFullTextSearchTool` — `Pens::ModelVariant.search` fallback.
- `KnownBrand` (Q18) — one EXISTS query: does the micro cluster's simplified brand match a brand
  spelling already seen on an ASSIGNED pen micro cluster? Mirrors the ink `KnownBrand`, not
  `Pens::Brand.simplified_names`. The system directive tells the model an unknown brand may be a
  misspelling and to check spelling or search the web.
- `Tools::PenWebSearchTool` — `GoogleSearchSummarizer` with " fountain pen" appended. Same
  sub-agent-log pattern as `InkWebSearchTool`. Enabled from the first run (open question 4); watch
  the calls-per-run ratio during hand review.

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
- human → no timestamp touch; the cluster is excluded from top-up refills until a human assigns or
  ignores it in the `pens-micro-clusters` React app (Q23).
- Rejection cleanup: unassign / destroy the created variant if it only holds this micro cluster
  (nullifying its micro clusters and re-queueing them) / unignore. Rejected logs with a manual
  note are fed back into the next attempt exactly like `processed_tries_data`.
- Cross-level cascade on reject (Q21): rejecting an approved L1 create fully cascades — destroy
  the now-empty model micro cluster it produced, reject any L2 log sitting on that model micro
  cluster, then re-run the model update (or destroy the model if it is now empty too). The L1
  half of this (plus cleaning up any unassigned empty model micro cluster) ships with L1's
  apply/reject code; the L2 half ships with L2's wiring.
- If a collision still reaches `approve!` — a race between the model's decision and the human's
  approval, where an identical row now exists that the create tool did not see — `approve!`
  refuses and rejects the log, the same as the stale-approval guard below (Q20).
- `already_resolved?` guards against the human having assigned it in the React app meanwhile.
  `approve!` re-checks that the micro cluster is still unassigned and rejects the log if not.
  This is a minimal safety check only (Q22): no tag, no stats exclusion, no flash-message
  design, and no auto-reject hook wired from the React controllers. The owner confirmed the
  React app and the agent queue are never worked at the same time — the React app is only the
  fallback destination for hand-overs — so this guard exists for correctness, not to prevent
  double-work.

**`PenModelClusterer`** (L2, owner `Pens::ModelMicroCluster`). Same shape with
`assign_to_model(model_id)`, `create_new_model`, `ignore`, `hand_over_to_human`. Lookup:
similarity search restricted to `Pens::Model` embeddings, `Pens::Model.search`, known brand,
web search. Prompt data: simplified brand/model plus the names of its variants and pen count.
Triggered from `Pens::UpdateModelMicroCluster` when `pens_model_id` is nil (today that worker
just returns), behind an on/off flag but not limited by the L1 queue depth. Volume is small: it only fires when L1 creates a
variant whose simplified brand+model is new.

**`PenBrandClusterer`** (L3, owner `Pens::Model`). Mirror of `InkBrandClusterer`: full list of
286 brands with synonyms in the prompt, tools `add_to_brand(brand_id)` / `create_new_brand`.
**Correction (Q39, overrides the ink-mirrored text above): L3 uses the L1 shape, not the ink
brand clusterer's shape** — the agent decides, the log parks in `waiting_for_approval`, a human
approval applies the decision (create tool duplicate-checks per Q20 above), and a rejection
re-queues the model to the manual brand admin page. It does not apply immediately, and there is
no undo code. Triggered from `Pens::AssignBrand` when the exact match finds nothing. Lowest
priority; exact match covers the current 100%.

**`CheckPenClustering::{Assign,Create,Ignore,Human}`** (phase 4). Copy of
`CheckInkClustering::*` with pen tools and pen prompt. Only built once L1 has a measured
human approval rate; until then humans review 100% and the checker would just add cost.
`CheckPenClustering::Human` copies the ink checker's behaviour (Q34): it emails hello@ and
approves the parent log with `agent_approved=false`, but — unlike the ink checker, which
leaves its own child log `waiting_for_approval` forever — the pen `Human` checker finalises its
own child log. `RunFailedClusterJobs` restarts stuck pen checker runs the same way it does for
L1 runs.

### Pull-based rollout

Nothing is triggered from the collected-pen save path at first, and nothing runs on a
schedule. The agent runs only to refill a small review queue after a human has emptied part of
it. No review, no runs, no spend.

- `TopUpPenClusteringQueue` worker. Reads `PEN_CLUSTERING_QUEUE_DEPTH` (default `0` = off,
  planned prod value `10`). Depth counting (Q24): counts `PenVariantClusterer` logs in
  `waiting-for-approval` or `processing` only — a queued-but-not-yet-started job does not
  count, so a brief overshoot past the target is accepted rather than guarded against. Once the
  checker (P4) exists, agent-decided logs still show on the human review page (human spot checks on
  them feed the "correct auto review" percentages) but do not count toward this depth. Hand-over exclusion
  (Q23): a cluster whose latest `PenVariantClusterer` log is an approved `hand_over_to_human` is
  excluded from top-up refills entirely until a human assigns or ignores it in the
  `pens-micro-clusters` React app — no timestamp touch, no other special handling. If the
  counted total is below the target, the worker enqueues one `RunPenClustererAgent` per missing
  slot from the priority order below. Idempotent, so calling it twice is harmless.
- Trigger: the admin review controller enqueues `TopUpPenClusteringQueue` after every human
  approve or reject. Reviewing 3 decisions refills 3; not reviewing for a week costs nothing.
  Empty-cluster marker (Q19): a run whose micro cluster is already empty by the time it runs
  skips deciding, writes a small marker log outside the review queue (its own name or tag, a
  terminal state, excluded from every stats query), and calls the top-up so the queue does not
  silently shrink; any other run that ends without a reviewable log (e.g. an error) calls the
  same top-up. `RunFailedClusterJobs` re-enqueues stuck `processing` logs but never adds new
  ones.
- `RunPenClustererAgent`: own throttled worker, concurrency 1, `agents` queue, so pen runs
  never starve `RunInkClustererAgent`. A single worker is accepted as-is for now (Q35); watch
  queue latency as volume rises and revisit only once the drain actually starts falling behind.
- Priority order for the L1 queue: most collected pens per micro cluster first, random
  after that. Same ordering the manual review app uses. No brand preference: the hand-review
  phase should see a mix of everything the data contains.
- Only L1 is gated by the queue depth. L2 and L3 run whenever their trigger fires, with every
  decision reviewed by a human. Their volume is small enough to clear in a day.
- Real-time triggering from `Pens::UpdateMicroCluster` (with the 30s debounce inks use) is
  phase 5, after the checker exists and approval rates are known. With a checker in place the
  queue depth counts only logs that still need a human, so agent-approved logs do not block
  refills. The trigger respects the cap (Q36): it performs a run-time check first, and if the
  human review queue is already at its cap, the run skips entirely without writing a log,
  leaving the cluster for the next top-up refill.

### Admin

- `Admins::Agents::PenVariantClustererController` + `PenModelClustererController`, views
  extracted from the ink clusterer view into a shared partial (state, extra data, owner dump,
  transcript, approve/reject/reject-with-note, shortcuts). Same reject-and-reprocess semantics.
  Stats are computed over the latest 500 manually processed logs, as on the ink page. Delete-history
  is fixed (Q25): it preserves the just-typed rejection note on a fresh guidance log and does not
  wipe sibling clusters' history — the same fix is applied to the ink page.
- Dashboard: pending-review counts for pen agents next to the existing pen cluster counts.
- The existing React apps stay as the "hand over to human" destination, used only as that
  fallback — the owner confirmed humans never work the React app and the agent queue at the
  same time, so this is not a double-work-prevention feature. Once the agent queue is live (Q26:
  after the P1 hand-review drip is underway, not alongside it), the app adds a badge plus a
  filter covering two cases: clusters whose latest agent log is an approved
  `hand_over_to_human`, and clusters with a pending agent log. Purpose is to make the hand-over
  fallback workable.
- `AgentLog.with_collected_inks` is ink-specific; replace with a generic "owner still has
  members" scope or per-agent scopes.
- Keep all `agent_log` history indefinitely — no trimming policy of any kind (Q37); transcripts
  stay available in bench dumps too.

### Bench

Extends the harness from the migration plan (P1) with pen cases. Ground truth is today's
state, leave-one-out, exactly as for inks:

- L1 label: the 16k human-assigned micro clusters. Null out `pens_model_variant_id` inside a
  rolled-back transaction; if the variant has other micro clusters expect
  `assign_to_variant(id)`, else expect `create_new_variant` and also hide the variant's own
  `pen_embeddings` row. Singleton cells are OVER-SAMPLED, because the labelled set is 99% multi-pen
  while the backlog is 96% singletons; for every singleton case, re-derive the held-out variant's
  (and a single-variant model's) name and embedding from the remaining pens inside the same
  rolled-back transaction — one extra embedding call per case — rather than reuse the pre-existing
  name and vector (Q12). The ignored micro clusters expect `ignore_pen`, minus those whose existing
  ignore does not match the decided ignore policy (open question 3) — those are excluded from the
  bench entirely (Q13), so fewer than 361 cases survive. Stratify: singleton vs multi-pen
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

- **Superseded (Q32):** the pen agents are NOT built on `MODEL_ID = "gpt-4.1"`. They are built
  on DigitalOcean models from the start, via the migration plan's per-agent config
  (`config/llm.yml`). This flips the dependency the other way round: the chat config layer
  (migration P0 / roadmap S04-llm-config-chat) now comes before the pen agent work (roadmap S06 and
  S10-S16) instead of being adopted opportunistically afterwards. (Q32 states this with v1 step
  numbers — "S15 moves before S04-S13" — which the v2 renumbering has since inverted; the named ids
  here are authoritative.) The starting model is whichever
  candidate the compatibility spike (migration P0 / roadmap S01) finds handles forced tool
  choice and transcript replay cleanly; record the pick and its date here once chosen. OpenAI
  stays the default for ink agents until their own cutover — there is no separate pen cutover
  step any more.
- The pen bench cases live in the shared harness and are also what migration P2/P3 use to
  evaluate embeddings and chat models for pens. Build them once.
- Do not drain the backlog before migration P3 picks a cheaper chat model. Inflow and the
  multi-pen backlog are affordable on the spike's starting model; the singleton backlog is not.
- If migration P2 swaps embeddings, `Pens::Model.embedding_search`'s 0.6 cutoff changes, and
  the L1 bench must be re-run.

## Phases

### P0 — Groundwork (no behaviour change)

- `Pens::MicroCluster` and `Pens::ModelMicroCluster` get `has_many :agent_logs, as: :owner,
dependent: :destroy`. Generic replacement for `AgentLog.with_collected_inks`.
- `Tools::PenSimilaritySearchTool`, `Tools::PenFullTextSearchTool`, `Tools::PenWebSearchTool`
  with specs. Measure `embedding_search` latency on prod-sized data; it loads up to 2,400
  embedding rows per call.
- Clean up stale rows (Q8, cleanup option (c)): DELETE the unassigned-and-empty rows — 9,333
  empty pen micro clusters, the 69 empty unassigned model micro clusters (Q8's shorthand "69/75"
  contradicts this document's own hierarchy table, which counts 69 unassigned model micro clusters,
  all empty; re-count before running), 25 empty variants, 7 empty models — plus orphaned embedding rows, and re-embed the NULL-vector
  `pen_embeddings` rows (re-enqueue `FetchEmbedding`) and fix any other missing rows found along
  the way. KEEP the empty but ASSIGNED micro clusters (453 pen micro clusters, 349 model micro
  clusters): they encode human spelling rules and must stay, filtered out of every query and
  count from here on (bench cases, dashboard counts, top-up eligibility, everything).
- CSV import routing (Q9): route `ImportCollectedPen` through `SaveCollectedPen` (roadmap
  S07-csv-import-routing), plus a one-off re-save of only the ~1,407 pens that currently have no
  micro cluster, not the argument-less `RefreshPens` (roadmap S08-stale-data-cleanup). That one-off
  re-save must run before the first bench dump (P1 below / roadmap S17-bench-db) and before the
  embedding backfill (roadmap S24-embedding-v2-backfill), so do it here in P0 rather than later.
  (Q9 names these by their v1 step numbers; the roadmap has since been renumbered, so the named ids
  above are authoritative.)
- Retrieval sanity check (bench-lite): script over ~200 leave-one-out L1 cases reporting
  whether the correct model/variant appears in `embedding_search` top 20. This is cheap (no
  chat calls) and decides whether the tool needs work before P1.

### P1 — `PenVariantClusterer` behind a flag

- Agent, decision tools, `approve!`/`reject!`, `already_resolved?`, rejected-try feedback.
- `RunPenClustererAgent`, `TopUpPenClusteringQueue` (queue depth default 0, triggered from the
  review controller), `RunFailedClusterJobs` extension.
- Admin review controller + shared view partial + dashboard counts. The React app's
  hand-over/pending badge and filter do NOT ship with this phase — per Q26 they ship only after
  the queue goes live and the hand-review drip (below) is underway.
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
- Run a baseline on the spike-picked starting model (Q32) on ~200 L1 cases, stratified.
  Compare to the prod approval rate from P1 as a sanity check that bench and prod agree.
- Iterate on the system directive against the bench, not against prod. Raising the prod queue
  depth (and later enabling the checkers, P4) is gated on the owner setting the acceptance bar
  after the two-week hand-review drip (P1) shows real per-action approval rates (Q27) — not
  before. Record both candidate yardsticks for that later decision: the ink clusterer's
  per-action approval rate over the recent months, and its all-time rate of ~85%.

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
  the pending cap. Unknown-brand singletons run LAST, after `PenBrandClusterer` (L3, next
  bullet) is live, watching the hand-over rate; stop early if hand-overs dominate (Q38).
- `PenBrandClusterer` as fallback for `Pens::AssignBrand`, using the L1 decide /
  wait-for-approval / approve-applies shape (Q39, see the PenBrandClusterer paragraph above):
  approving applies the brand assignment, rejecting re-queues the model to the manual brand
  admin page, and there is no undo code.

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
   decisions after each human review. Open detail resolved 2026-09-14 (Q24): yes, `processing`
   logs count towards the depth alongside `waiting-for-approval`; queued-but-not-yet-started
   jobs do not count, so a brief overshoot is accepted rather than guarded against. Once the
   checker (P4) is live, agent-decided logs show on the review page but do not count toward the
   depth.
6. **Model.** Decided 2026-09-12: gpt-4.1 with a constant `MODEL_ID`, same pattern as
   `InkClusterer`, no dependency on the migration plan. Approval rates stay comparable to the
   ink baseline; the bench picks a cheaper model later. **Superseded 2026-09-14 (Q32):** the
   pen agents are built on DigitalOcean models from the start, via the migration plan's
   per-agent config — not gpt-4.1, not a constant `MODEL_ID`. The starting model is picked by
   the migration plan's compatibility spike (whichever candidate handles forced tool choice and
   transcript replay cleanly); record the pick and its date here once chosen. See "Interaction
   with the LLM migration plan" above for the full consequence (config layer moves earlier,
   no separate pen cutover step).
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
