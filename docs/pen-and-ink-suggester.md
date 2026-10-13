# PenAndInkSuggester

The dashboard widget "What should I ink up next?" suggests one fountain pen and one ink from the
user's own collection, optionally steered by a free-text instruction ("only samples, fairly broad
nibs", "an ink for my Lamy 2000, nothing blue"). This document describes how it works, which
rules must keep holding, and how to measure a change. Read it before changing the suggester, its
prompts or its models.

Related documents:

- `docs/nib-reference.md`: every nib rule (grades, Japanese sizing, width classes, grinds, ink
  matching). `NibProfile` and the prompt's "Nib knowledge" section follow it; this document does
  not repeat it.
- `spec/agents/README.md`: which spec covers which part.

**Design in one line: Ruby filters, one pick call.** A small extractor model turns the instruction
into typed constraints, Ruby applies them to the whole collection and resolves named items, and
the picker model makes one tool call over pre-filtered rows. Hard requirements are enforced in code,
not in prose, so they hold on small models too. The prompt has fixed slice sizes, so its size does
not grow with the collection, and the only provider feature the design needs is a forced, halting
tool call.

---

## 1. What a suggestion must do

The picker's system prompt (`PenAndInkSuggestion::PickPrompt::SYSTEM_DIRECTIVE`) carries these
defaults; an explicit request overrides them:

- one fountain pen and one ink, both from the rows shown;
- a balance of novelty and favourites, leaning towards novelty (items not used recently or often);
- a pairing that has not been inked before, unless the user asks to repeat one;
- variety against what is currently inked (ink colours and nib sizes);
- an ink that suits the nib (the "Nib knowledge" extract of `docs/nib-reference.md`);
- never an exact pen + ink pairing the user rejected; a rejected pairing bans neither item alone.

The reasoning it writes is markdown, 2–4 sentences or at most 3 bullets (about 40–120 words), in
the request's language. It has no headings, does not list the chosen items (the server adds them),
never mentions the selection rules or the words "novelty", "favourite(s)" and "balance(d)", never
cites tags or descriptions as such, and never contains refs, ids, width classes, links or images.

Code enforces what the model must not get wrong: only shown rows can be picked, the server writes
the pen/ink header, filters and pins are applied before the call, and `record_suggestion`
re-checks every constraint.

**Out of scope** (each would be a new design decision): more than one pair per run, model-facing
search tools, persisted preferences, rollerball or dip-pen suggestions, answering collection
questions or shopping advice, enforcing conditional rules ("shimmer only in clear pens"), filters
for filling system, name prefix, "added recently", tag includes, sheen, shading or water
resistance, localised server notes, and an extractor result cache.

---

## 2. Request flow

```
Widget (pen_and_ink_suggestion_widget.jsx)
  GET /dashboard/widgets/pen_and_ink_suggestion.json?extra_user_input=…&rejected_suggestions=[…]
  └─ WidgetsController            instruction cut to 500 chars; rejected pairs parsed as
     │                            {"ink_id","pen_id"} integers, newest 50 kept
     │                            Rack::Attack: 10 enqueues / minute / IP (polls never throttled)
     └─ RequestPenAndInkSuggestion  daily-cap pre-check (fast feedback), returns suggestion_id
        └─ SchedulePenAndInkSuggestion   Sidekiq, queue "interactive", retry 0
           │  instruction gate; queue_ms; result written to Rails.cache in `ensure`
           └─ PenAndInkSuggester#perform
                1. daily cap (authoritative); one new AgentLog per request
                2. CollectionSnapshot.new(user)
                3. precheck: no fillable ink, or no uninked pen and no instruction
                4. MentionMatcher → NameHints ("names_found")
                5. PenAndInkConstraintExtractor (sub-agent) → Constraints, or fallback
                6. NameResolver → pins, brand filters, notes
                7. CandidateSelector → Selection (rows, refs, notes, relaxations) or an early end
                8. pick call: ask!(PickPrompt#user_message), tool record_suggestion
                9. message = header + notes + sanitised reasoning; extra_data saved
  Widget polls ?suggestion_id= every second for up to 60 s, then shows a timeout error
```

**Widget** (`app/javascript/src/dashboard/pen_and_ink_suggestion_widget.jsx`). It first loads
`pen_and_ink_suggestion_settings` (`instructions_allowed`, `instructions_max_length`). When
instructions are not allowed, the textarea is replaced by a one-line explanation. Every pair it
receives is added to the rejected pairs sent with the next request ("Try again"), and the
instruction stays in the textarea. A 429 shows a throttle
message. Polling stops on the first result with a `message` or `status: "error"`, or after 60 s.

**Controller and operation.** `WidgetsController#pen_and_ink_suggestion_data` hands the
parameters to `RequestPenAndInkSuggestion`. Without a `suggestion_id` it checks the daily cap
(writing the cap message straight to the cache when it is reached) and enqueues the worker with
the enqueue time. With a `suggestion_id` it reads the cached result, loads the pen and ink through
the user's own collections, re-checks that an inked pen is still inked (and removes the
clean-it-first note from the message when it was cleaned meanwhile), and renders the message with
`FpcFormatter`.

**Worker** (`app/workers/schedule_pen_and_ink_suggestion.rb`). It runs on the `interactive`
queue, which `config/sidekiq.yml` lists before `agents`, so agent backlogs cannot starve it. It has
`retry: 0`, because a late retry would overwrite a result the user already saw. It drops the
instruction when `PenAndInkSuggester::InstructionGate` does not allow it. Its `ensure` block
always writes a result (the suggester's, or `PenAndInkSuggester.error_result`) for one hour; every
result carries a `message`, because the widget only stops polling on one.

**Suggester** (`app/agents/pen_and_ink_suggester.rb`):

1. **Daily cap** (`PenAndInkSuggester::DailyCap`): 20 runs a day, 50 for patrons and admins.
   Prechecks don't count (section 9).
2. **Snapshot.** `PenAndInkSuggestion::CollectionSnapshot` loads the user's active inks (tags,
   clusters), active pens, every inking with its usage records, per-item stats and pair history in
   a fixed number of queries. A spec pins that the query count does not grow with the collection.
3. **Precheck** (no LLM call, not counted toward the cap): no fillable ink (none, or only swabs),
   or no uninked pen and no instruction. With an instruction, an inked pen can still be named, so
   that check waits until after name resolution.
4. **Name hints.** For an instruction, `MentionMatcher` scans the text against the user's own pen
   and ink names; `NameHints` resolves each hit and writes one `names_found` line per name
   (section 4).
5. **Extractor.** `PenAndInkConstraintExtractor` reads the instruction and the hints and calls
   `set_constraints` once (section 3). When it fails, `constraints_source` is `"fallback"`: the
   constraints are empty, the matcher's hits become the mentions, the slices widen and the lists
   are headed "UNFILTERED", so the picker applies the request itself.
6. **Resolution.** `NameResolver` turns mentions into pins, brand filters and "couldn't find"
   notes (section 4). If no uninked pen is left and no pen is pinned, the run ends with a message.
7. **Selection.** `CandidateSelector` filters, relaxes, ranks and slices both sides (section 5).
   It can end the run without a pick call: every exclusion emptied a side (`excluded_all`), no
   compatible pair exists (`no_compatible_pairs`), or every shown pair was rejected
   (`all_pairs_rejected`). The end message depends on whether items were pinned or filtered.
8. **Pick.** `ask!` with `record_suggestion` as the only tool, `calls: :one` (no parallel tool
   calls) and at most 12 tool calls. The first valid call halts. `ToolCallLimitExceeded` and
   `DecisionNotReachedError` are rescued: a recorded pick is still used, otherwise the result is
   the error message.
9. **Result.** `SuggestionMessage` composes the message (section 6). The whole result is NUL
   sanitised, stored in the log's `extra_data`, the log moves to `waiting-for-approval`, and the
   user-facing keys (`message`, `ink`, `pen`, `pen_currently_inked`, `currently_inked_id`,
   `currently_inked_note`, `status`) go to the cache.

**Inked named pen.** A pen the user names is pinned even when it is inked. The answer then carries
the note "Currently inked with X — empty and clean it first.", `pen_currently_inked: true` and the
inking's id, and the widget shows "Open Currently inked" (a link to `/currently_inked`) instead of
"Ink it Up!", since a new inking of that pen would be rejected.

---

## 3. Constraints

`PenAndInkSuggestion::Constraints` is an immutable value object. The extractor prompt, the
`set_constraints` schema, `CandidateSelector`, `ConstraintCheck`, the bench labels and the bench
scorer all depend on these fields and their meaning, so a change here is a change to all of them.

| Field                                         | Values                                         | Applied as                                           |
| --------------------------------------------- | ---------------------------------------------- | ---------------------------------------------------- |
| `out_of_scope`                                | bool                                           | note, then a normal pick                             |
| `requested_count`                             | 1–10                                           | note ("one combination at a time") when > 1          |
| `keep_from_previous`                          | none, pen, ink                                 | pins that side of the newest rejected pair           |
| `pair_usage`                                  | any, new, repeat                               | pair filter, relaxed with a note                     |
| `soft_notes`                                  | text ≤ 300                                     | WISHES line for the picker only                      |
| `pen.mentions`, `ink.mentions`                | ≤ 5 names                                      | pins (or a brand filter) via `NameResolver`          |
| `pen.exclude_mentions`, `ink.exclude_mentions` | ≤ 10 names                                    | hard exclude, never relaxed                          |
| `pen.comment_exclude`                         | ≤ 3 words                                      | hard exclude on the pen comment (Ruby only)          |
| `pen.nib_grades_include` / `_exclude`         | EF F MF M B BB                                 | include: relaxed; exclude: never relaxed             |
| `pen.nib_width`                               | any, fine, broadish, broad                     | hard include, relaxed                                |
| `pen.nib_characters_include` / `_exclude`     | stub italic oblique fude flex architect music zoom naginata | include: relaxed; exclude: never relaxed |
| `ink.tags_exclude`                            | ≤ 5 tags                                       | hard exclude on the user's own tags                  |
| `ink.kinds_include` / `_exclude`              | bottle sample cartridge                        | include: relaxed; exclude: never relaxed             |
| `ink.colour_include` / `_exclude`             | red orange yellow green teal blue purple pink brown gray black | include: relaxed; exclude: never relaxed |
| `ink.shimmer`                                 | any, include, exclude                          | include: relaxed; exclude: never relaxed             |
| `ink.scented`                                 | any, include, exclude                          | include: boost only; exclude: never relaxed          |
| `pen.usage`, `ink.usage`                      | any, never_used, used_before                   | hard include, relaxed                                |
| `pen.sort`, `ink.sort`                        | default, least_recent, most_used               | replaces the novelty order                           |

**Semantics the extractor prompt, the labels and the checks share:**

- **Hard vs soft.** A field is set only when the request clearly requires it. A wish ("ideally",
  "maybe", moods, seasons, shades finer than a family, sheen, shading, wet/dry, permanence,
  filling system, "newest pen", items named only for comparison, conditional rules) goes to
  `soft_notes`. A wrong filter hides what the user wanted; a missed one only leaves the wish to
  the picker, so the extractor errs towards `soft_notes`.
- **Literal grade vs vague width.** "M nib", "M or B", "medium nib", "a broad nib" →
  `nib_grades_include` on the grade written on the pen (a Pilot M and a Pelikan M both match "M").
  "Fine", "fairly broad", "wider", "breitere Feder" → `nib_width` on the Western-equivalent width
  class: `fine` = W1–W3 without a broad-ish character, `broadish` = W4+ or any broad-ish character
  (stub, italic, fude, music, architect, zoom, naginata, parallel), `broad` = W5+. "Not broad or
  stub" → `nib_width: fine` + `nib_characters_exclude: [stub]`. Never both a grade and a width for
  one wish. Grade fallbacks for pens without a letter grade and the width tables are in
  `docs/nib-reference.md`.
- **A nib, colour or material written with a named pen describes that pen** and sets no filter
  ("my Pilot Falcon with the SEF nib" is only a pen mention). Letters inside a model name
  ("Pelikan M800") are not grades. A pen's colour, or the colour of an ink named or ruled out by
  name, sets no colour field.
- **"Use them up" is not "never used".** "Only samples, I want to use them up" →
  `kinds_include: [sample]` and nothing else; the novelty order already puts unused samples first.
  `usage: never_used` needs explicit wording ("never used", "unused", "haven't tried yet"); "haven't
  used in a while" is `sort: least_recent`; "new", "just bought" and "not currently inked" set no
  usage. Usage is about one side's item, not the pairing.
- **Pairings.** "A combination I haven't tried" → `pair_usage: new`; "a pairing I liked before" →
  `repeat`. A pen and an ink that are each "never used" is usage on each side, not `pair_usage`.
- **Names.** Items or brands the user wants used are `mentions`; ruled out by name ("not a Parker",
  "not Chiku-rin again") → `exclude_mentions`; named only for comparison or "already in a pen" →
  neither. A brand alone counts ("one of my Pilots" → `pen.mentions: ["Pilot"]`, which resolves to
  a brand filter). "Not my wife's pens" → `comment_exclude: ["wife"]`. `tags_exclude` only when the
  user says "tag(ged)".
- **Colours** use the 11 families; named hues map to them (navy → blue, turquoise → teal and blue,
  "warm colours" → red, orange, yellow, brown). An exclusion never fills the include list.
- **`keep_from_previous`** only when the request refers back to the suggestion just turned down
  without naming the item ("same pen, another ink").
- **`out_of_scope`** for shopping advice, collection questions, lists or app feedback; the other
  fields it implies are still set.

**Validation in Ruby.** `Constraints.from_h` accepts only known fields, matches enum values
case-insensitively and drops unknown ones, caps list lengths, term length (60) and `soft_notes`
(300), and fills defaults. The extractor then drops mentions that contain no name-like word or
that are also excluded, drops `keep_from_previous` unless there is a previous suggestion and no
mention on that side, and resets a colour list with more than 4 families (a sign that the model
spelled out a complement). Nothing from the extractor reaches SQL or `Regexp.new`; it is only
compared in memory.

**Tool shape.** `set_constraints` uses a JSON schema built from `Constraints` (`SetConstraints`).
`PEN_AND_INK_CONSTRAINT_EXTRACTOR_PARAMS=json` switches to a single `constraints_json` string
parameter (`SetConstraintsJson`) for providers that reject the schema; both are specced.

Example: "only ink samples, I want to use them up, and fairly broad nibs" →
`{"pen": {"nib_width": "broadish"}, "ink": {"kinds_include": ["sample"]}, "soft_notes": "wants to
use up samples"}`. The pen side keeps uninked fountain pens of W4+ or with a broad-ish character
(pens with no recognisable width are left out and counted in a note), the ink side keeps samples,
and the picker sees headers such as `PENS (25 of 46 that fit: broad-ish nibs)` and
`INKS (31 of 31 that fit: ink samples)`.

---

## 4. Names: matcher, hints and resolver

**Ruby recognises names; the extractor decides their role.** The user's own collection is the
vocabulary. `PenAndInkSuggestion::NameIndex` indexes each pen by brand, model and "extra" words
(colour, material, trim, nib) and each ink by brand, line and name.

**`MentionMatcher`** is conservative, because in fallback mode its hits become hard pins:

- it removes a stop vocabulary first (`MentionVocabulary`: colour, nib, ink-kind, season, property
  and pen words in English, German and Spanish);
- a phrase pins only with two name words, or one name word plus a brand or line word; extra words
  (pen colour, nib) never pin on their own;
- a brand followed by a model code ("Platinum 3776") is a mention;
- a mention preceded by a negation in the same clause is skipped;
- a bare instruction of at most 4 words that is only a name and matches at most 3 items is a
  mention ("Dandy");
- words of 5+ letters also match at one edit ("Murakuro" → "Murakumo").

**`NameHints`** resolves each matcher hit and writes lines such as `pen: stellar mini (Nova
Stellar Mini)` or `pen brand: pilot` (at most 2 item names per line, 5 lines, 160
characters each). Hits that do not resolve are dropped. The extractor puts each hinted name into
`mentions` or `exclude_mentions`, or leaves it out when it is a comparison or already in a pen; it
can also add names the matcher missed.

**`NameResolver`** turns each mention into pins, a brand filter or a note:

- it tries the mention's side first, then the other side for a named match;
- a match must cover a word of the item's name (model, or ink name) and every code word (digits)
  in the mention; brand, line and name words weigh 2, extra words 1;
- every item within 90% of the best score is pinned, at most 5 per side, least recently used
  first; inked pens are searched too;
- a mention that matches only a brand or line becomes a brand filter (ignored with a note when it
  leaves nothing);
- no match: the closest item names within edit distance 2 are pinned with "I couldn't find "X" in
  your collection, so I went with the closest: Y.", otherwise "I couldn't find "X" in your
  collection.";
- a pinned non-fountain pen or swab is dropped with a note.

After the pick, a "couldn't find" note is removed from the answer when the picked pen or ink
carries every content word of the mention (`PenAndInkSuggestion::PickedNames`; a one-letter
initial next to an exact word counts, nib letters don't). The pick prompt still lists the note,
and `extra_data["dropped_notes"]` records it.

---

## 5. Candidate selection

`PenAndInkSuggestion::CandidateSelector` builds the `Selection` the picker sees.

**Bases.** Pens: active, fountain-capable (`NibProfile` kind not non-inkable, rollerball or dip),
not inked. Inks: active, not swabs. A pinned side uses only its pins; a brand filter narrows the
base. Pens are kept only if they take at least one candidate ink, and inks only if at least one
candidate pen takes them: a cartridge ink needs a pen whose `filling_system` is blank or says
cartridge/converter (`CartridgeCompatibility`).

**Pins and filters.** Pins that fail the side's filters are narrowed to those that pass; if none
pass, those filters are relaxed (step `pinned`, note "…so I kept them anyway"). Exclusions are
never relaxed: when they empty a side, the run ends with "None of your inks is left after
excluding …". Inclusions are relaxed in a fixed order until the side is non-empty, each step
leaving a note:

- **pens:** usage → nib characters → nib width or grade widened by one class / neighbouring grade
  → nib width or grade dropped;
- **inks:** usage → shimmer → colour widened to neighbouring families → colour dropped → kind.

The relaxed constraints become `effective_constraints`, which the prompt headers and
`record_suggestion` use. Pens with an unknown width are left out of nib filters and counted in a
note; without a nib filter they stay eligible.

**Pairs.** `pair_usage: repeat` keeps only items with a past pairing; `new` keeps, opposite a
pinned side, only items never paired with a pin. Both relax with a note when nothing qualifies or
no shown pair satisfies them. By default, opposite a pinned side, never-tried items move ahead.
`ink.scented: include` moves scented inks ahead.

**Slices** (a pinned side sends only its pins; a filtered set that fits is sent whole):

| Tier    | Pens | Inks | Currently inked rows | Inks with a 300-char description | Fallback slices (pens / inks) |
| ------- | ---- | ---- | -------------------- | -------------------------------- | ----------------------------- |
| free    | 25   | 40   | 15                   | 5                                | 50 / 50                       |
| premium | 40   | 80   | 40                   | 10                               | 100 / 100                     |
| admin   | 60   | 120  | 40                   | 10                               | 200 / 200                     |

Patrons get the premium tier, admins the admin tier (and the premium model).

**Ranking within a slice** (`sort: default`):

1. Order by `last_activity_on` (latest of inked, archived and usage dates; today while inked),
   never-used items first in random order, then oldest first with a seeded jitter of ±60 days so
   "Try again" sees different rows. Items currently in a pen go to the back.
2. Take 80% of the slice from that order and fill the rest with favourites (most inkings first),
   then with the rest of the order.
3. An explicit `sort` replaces this with a deterministic order (least recent, or most used).
4. The chosen rows are shuffled with the seed before refs are assigned.

The seed is random per request (`SecureRandom`), passed in by the bench, and logged.

---

## 6. Pick prompt, `record_suggestion` and the answer

**System message** (`PickPrompt::SYSTEM_DIRECTIVE`): static for every user and tier (about 1.8k
tokens with the tool schema, above OpenAI's 1,024-token cache threshold, so the prefix is cached).
Sections: what you receive, how to choose, output rules, row legend, nib knowledge. Its width-class
lines must match the table in `docs/nib-reference.md` section 5; a spec pins them to the
`NibProfile` constants.

**User message** (`PickPrompt#user_message`), in this order:

- `CURRENTLY INKED (n)` rows and `RECENT FILLS` (colour families of the last 90 days);
- `PENS` and `INKS` with refs `P1…` / `I1…`; headers say how many of how many fit and which
  filters apply, "★ requested" for pins, "UNFILTERED" in fallback mode;
- pen row: `ref | name | nib: label | material | filling | last used | times inked | currently
  inked with X`;
- ink row: `ref | name | kind | colour family, lightness | properties | last used | times inked |
  in a pen | paired before with P2 (2026-05) | "description"` (descriptions 100 characters, 300
  for pins and top-ranked inks);
- `RECENT INKINGS OF ★ ITEMS` (≤ 3 each, with the user's inking note, ≤ 150 characters);
- `REJECTED` (exact pairs among the shown rows, newest first, ≤ 10);
- `SERVER NOTES` (already shown to the user), `WISHES` (`soft_notes`);
- `<request>…</request>`, or "No request from the user: choose with the defaults."

Refs, not database ids, reach the model; the ref map lives in the `Selection`.

**`record_suggestion`** (`PenAndInkSuggester::RecordSuggestion`) takes `pen_ref`, `pen_name`,
`ink_ref`, `ink_name` and `reasoning`. It returns a correction string (the model may retry) when a
ref is not shown, a name fits another shown row better (catches ref mix-ups), the pair is a
rejected one, the pair breaks `effective_constraints` or cartridge compatibility (also logged in
`extra_data["violations"]`, since the selector should have prevented it), or the reasoning is
blank. The first valid call halts; later calls get "Suggestion already recorded".

**The answer** (`SuggestionMessage`): a server-built header (`- **Pen:** …` with the nib label when
the pen has no nib text, `- **Ink:** …`, names markdown-escaped), the notes in italics, then the
reasoning after `ReasoningSanitizer` removed links (kept as text), images, raw HTML, bare URLs,
headings and width classes. Server text is not sanitised, so it can carry links (the daily-cap
message links to Patreon). Notes and paragraphs are joined with `SuggestionMessage::SEPARATOR`,
which `RequestPenAndInkSuggestion` relies on to remove the clean-it-first note.

---

## 7. Normalisers

These plain Ruby objects are computed on the fly (no DB columns), so rule changes apply at once.
The filters, the prompt rows and the bench checkers all use them, so a rule change moves both the
picks and the scores.

- **`NibProfile.parse(nib, brand:, model:)`** (`app/models/nib_profile.rb`): kind, literal grade,
  width class W1–W7, width range, characters, material, `japanese_sizing` and a display label.
  All rules are in `docs/nib-reference.md`; fix a misclassification by adding a row to the spec
  table and, if it is a rule, to the reference.
- **`ColorProfile.for(ink)`** (`app/models/color_profile.rb`): family (11 values), secondary
  family, lightness and saturation from the ink's hex colour (the cluster colour as fallback).
  Matching is lenient: the primary family, the secondary family or a cluster colour tag satisfy
  a colour filter, and `colour_exclude` uses the same match, so an exclusion errs towards the
  user's wording.
- **`PenAndInkSuggestion::InkProperties.for(ink)`**: shimmer, sheen, shading, chameleon, scented,
  water-resistant, pigmented and iron gall, from the user's tags, cluster tags, ink names and the
  cluster description. A description counts sheen or shading only as a main characteristic, not
  when hedged ("some shading", "a bit of sheen") or seen only in swatches. "Permanent" in a name or
  tag means water-resistant. The flags are lower bounds; only shimmer and scented are filterable.

---

## 8. Models, cost and latency

| Role                         | Model                                   | Settings                                             |
| ---------------------------- | --------------------------------------- | ---------------------------------------------------- |
| Picker, free                 | gpt-4.1-mini                            | `calls: :one`, ≤ 12 tool calls                       |
| Picker, patrons and admins   | gpt-4.1                                 | same                                                 |
| Extractor, every tier        | gpt-6-luna (`PenAndInkConstraintExtractor::MODEL_ID`) | temperature 0, reasoning effort `none`, `calls: :one`, ≤ 4 tool calls |

**Changing a model.**

1. Set `model_id` (picker, in `PenAndInkSuggester#model_id`) or `MODEL_ID` (extractor).
2. If RubyLLM's bundled registry does not know the model, add it to `RubyLlmModels::UNLISTED` in
   `lib/ruby_llm_models.rb` with its capabilities; `config/initializers/ruby_llm.rb` registers it
   at boot and the bench reuses the same registry. Drop the entry once the gem knows the model.
3. Use the `RubyLlmAgent` hooks: `reasoning_effort` (the extractor sends `"none"`; the gpt-5
   generation needs `"minimal"`) and `temperature` (the extractor sends 0; RubyLLM forces 1.0 on
   `gpt-5*` and `o<digit>` ids, which makes the extractor less stable).
4. Add the model's prices to `lib/bench/suggester/pricing.rb` (input, cached input, cache write,
   output) before benching it; the runner stops on an unpriced model.
5. Run the bench (section 13) and compare with the reference numbers. For the extractor,
   `bench:suggester:extractor MODEL=… REASONING_EFFORT=…` tries a model without a code change.

API keys: `OPEN_AI_DEV_TOKEN` in development; otherwise `OPEN_AI_PEN_AND_INK_SUGGESTER_TOKEN` /
`OPEN_AI_PEN_AND_INK_CONSTRAINT_EXTRACTOR_TOKEN`, falling back to `OPEN_AI_TOKEN`.

**Cost and latency to keep** (list price, no cache discount; production is somewhat cheaper
because both system prompts are static prefixes that OpenAI caches):

| Run                         | Free             | Premium        | Latency p50 / p90 (excl. queue) |
| --------------------------- | ---------------- | -------------- | ------------------------------- |
| Without an instruction      | $0.0019          | $0.0128        | 1.6 / 1.8 s                     |
| With an instruction         | ≈ $0.0023        | ≈ $0.0128      | ≈ 2.8–3.0 / 3.4–3.5 s           |
| Extractor share of that     | $0.00039         | $0.00039       | 1.3 / 1.7 s                     |

On runs without an instruction the picker reads about 4.8k input tokens on the free tier and
6.8k on premium (median); filtered and pinned runs read less. The extractor reads about 3k (mostly
its static prompt and schema) and writes about 30. Measured figures and how they were taken are in
section 13.

---

## 9. Limits

| Limit                                         | Where                                           | Why                                                              |
| --------------------------------------------- | ----------------------------------------------- | ---------------------------------------------------------------- |
| 20 runs / day, 50 for patrons and admins      | `PenAndInkSuggester::DailyCap`                  | cost; a run counts once it can make an LLM call                  |
| Prechecks and early ends without an instruction don't count | `extra_data["precheck"]`         | they make no LLM call                                            |
| 10 enqueues / minute / IP, polls exempt       | `config/initializers/rack_attack.rb`            | bounds abuse and the race between concurrent cap checks          |
| Instructions: account confirmed > 2 weeks and > 20 inks or > 20 pens (archived included) | `InstructionGate` | keeps free text away from throwaway accounts            |
| Instruction ≤ 500 characters (textarea `maxLength` too) | `WidgetsController`                  | prompt size and injection surface                                |
| ≤ 50 rejected pairs, integers only            | `WidgetsController#parse_rejected_suggestions`  | free text can never enter through this parameter                 |
| Picker ≤ 12 tool calls, extractor ≤ 4, no parallel calls | `max_tool_calls`, `tool_calls_mode` | a runaway loop ends; a valid first pick is still used            |
| 3 nudges, then `DecisionNotReachedError`      | `RubyLlmAgent#ask!`                             | forces a decision without looping                                |
| `retry: 0`, result cached 1 hour              | `SchedulePenAndInkSuggestion`                   | no late overwrite of a shown result                              |
| Widget polls 1 s, gives up after 60 s         | widget                                          | no endless spinner                                               |
| ≤ 5 pins per side, ≤ 5 name hints             | `NameResolver`, extractor                       | bounded prompt and pin sets                                      |

---

## 10. Security, prompt injection and privacy

These rules must keep holding:

- **User scoping by construction.** Every data path starts from the user's own
  `collected_pens`, `collected_inks` and `currently_inkeds` in `CollectionSnapshot`; the model sees
  refs that map only into this run's selection; no tool takes a user id or a database id; the
  cached result's ids are loaded back through the user's collections.
- **User text is data.** The instruction is wrapped in `<request>` tags (picker and extractor) and
  the hints in `<names_found>`; matching tags inside the text are removed, hint lines lose `<` and
  `>`. Both system prompts say that tagged text and row text are data and can never change the
  rules, the output format or the tool use.
- **The model can only choose.** Extractor output is enum- and length-validated and used only
  for in-memory comparisons; the picker can only return refs from the shown rows; the header is
  built by the server, so the model cannot name an item it didn't pick. A user's injection can
  only change that user's own constraints, pick and prose.
- **Community text.** Cluster descriptions and tags are wiki-edited by other users and are the
  only cross-user text in the prompt: they are truncated (100 or 300 characters) and declared
  data, and the reasoning is sanitised (no links, images, HTML) before it is shown.
- **Never sent to a model:** pen comments (used only in Ruby for `comment_exclude`), ink comments
  and private comments, other users' data. Inking notes are sent only for the last 3 inkings of
  items the user named.
- **Logging.** Transcripts and `extra_data` hold the user's request and collection rows; they stay
  in `agent_logs`. Postgres refuses `\u0000`, so `RubyLlmAgent#sanitize_for_pg` strips it
  recursively from every transcript and from both agents' `extra_data`; the user-facing result
  is sanitised the same way.
- **Errors.** The extractor rescues exactly `DecisionNotReachedError`, `ToolCallLimitExceeded`,
  `RubyLLM::Error`, `RubyLLM::ConfigurationError`, `RubyLLM::ModelNotFoundError`, `Faraday::Error`
  and `JSON::ParserError` and falls back; other exceptions reach Honeybadger, and the worker still
  writes an error result.

---

## 11. What the logs record

Each request creates one `AgentLog` named `PenAndInkSuggester`, owned by the user, ending in
`waiting-for-approval`. Instruction runs that reach the extractor add a child log named
`PenAndInkConstraintExtractor`, owned by the parent log (`agent_log.agent_logs`), so the daily cap
counts only parents. `usage` records the model id the API returned, prompt, completion, cached
and cache-write tokens per log.

Parent `extra_data` keys:

| Key                                              | Meaning                                                                  |
| ------------------------------------------------ | ------------------------------------------------------------------------ |
| `message`, `ink`, `pen`, `status`                | the result (`status: "error"` on failures)                               |
| `pen_currently_inked`, `currently_inked_id`, `currently_inked_note` | inked named pen                                       |
| `reasoning`, `notes`, `dropped_notes`            | the sanitised reasoning, notes shown, "couldn't find" notes removed      |
| `constraints`, `constraints_source`              | extractor output (`nib_width_slack` when widened); `none`, `extractor` or `fallback` |
| `extractor_error`                                | error class on fallback                                                  |
| `mentions`                                       | mentions used for resolution (instruction runs)                          |
| `pins`, `shown_pen_ids`, `shown_ink_ids`         | pinned and shown items                                                   |
| `relaxations`                                    | `field`, `step` (dropped, widened, pinned), `from`, `to`, `reason`       |
| `rejected_pairs`, `seed`                         | inputs needed to replay the run                                          |
| `violations`, `error`                            | rejected `record_suggestion` calls; `ToolCallLimitExceeded` / `DecisionNotReachedError` |
| `precheck` or `ended`                            | why a run ended without a pick (`precheck` runs don't count to the cap)  |
| `latency_ms`, `queue_ms`                         | pick call duration; enqueue-to-start time                                |

The child log's `extra_data` is `{"constraints" => …}` or `{"error" => class}`, and its
transcript holds the request and hint lines as sent.

To find a run's data: `AgentLog.where(name: "PenAndInkSuggester", owner: user).order(:id).last`,
then `.agent_logs` for the extractor. `bench:suggester:check_logs SINCE=` runs the label-free
checks (validity, leakage, novelty, cost, latency) over live logs.

### Online watch after a deploy

The bench replays old requests; only live logs show whether users are better served. After v2
first goes live, and after any later change to a prompt, a model, the candidate selection or the
extractor, watch the live logs for a week (longer if traffic is thin) and compare with the 4 weeks
of logs before that deploy. Run `check_logs` over both windows too.

These existed before v2; the values are from the logs before v2:

| Metric                                                              | Before v2                            |
| ------------------------------------------------------------------- | ------------------------------------ |
| Acceptance proxy: the suggested pair inked within 2 days of the run | 12% overall, 19% with an instruction |
| Session length in runs (a fresh run plus its "Try again" runs)      | 3.9 overall, 5.7 with an instruction |
| Share of sessions with 10+ runs                                     | 11.6%                                |

v2 starts logging these, so the first watch sets their baseline for later ones:

- extractor fallback rate (`constraints_source: "fallback"`) and relaxation rate (runs with
  `relaxations`);
- `DecisionNotReachedError` and `ToolCallLimitExceeded` rates (`error`);
- `queue_ms` p50 / p90, and the widget timeout rate: runs whose `queue_ms` plus run time exceed
  the widget's `POLL_TIMEOUT_MS` (60 s).

Success means shorter sessions with an instruction and a higher acceptance proxy, with no drop in
acceptance for runs without one. A regression is reverted with `git revert` of the change that
caused it.

---

## 12. Request categories

The bench labels tag each instruction with these categories (`Bench::Suggester::Label::CATEGORIES`,
in this order). The right-hand column is how the suggester handles each.

| Slug                  | Request                                                         | Handling                                                       |
| --------------------- | --------------------------------------------------------------- | -------------------------------------------------------------- |
| `specific_pen`        | names a pen ("ink for my Lamy 200 Broad", bare "Dandy")         | pin; inked pens included                                       |
| `colour`              | colour or hue                                                   | colour filter; finer shades in `soft_notes`                    |
| `ink_properties`      | shimmer, sheen, shading, wet/dry, scented, permanent            | shimmer/scented fields; the rest in rows and `soft_notes`      |
| `novelty_usage`       | never used, least recent, most used, ignore usage               | `usage`, `sort`, default novelty order                         |
| `exclusions`          | rules out a brand, item, tag, property or colour                | exclusions, never relaxed                                      |
| `ink_kind`            | samples only, bottles only, cartridges                          | `kinds_include` / `kinds_exclude`; cartridge compatibility     |
| `specific_ink`        | names an ink                                                    | pin                                                            |
| `season_mood`         | season, mood, theme                                             | `soft_notes` + descriptions                                    |
| `multiple_suggestions`| asks for several pairs                                          | note; one pair, pins kept for "Try again"                      |
| `nib`                 | nib grade, width or grind, as constraint or context             | nib fields; rows carry the nib label                           |
| `match_pen_colour`    | ink to match the pen                                            | soft; pen colour is in the row name                            |
| `relative_to_inked`   | relative to what is inked now                                   | currently-inked rows + recent fills                            |
| `purpose`             | work, office, journaling                                        | `soft_notes`                                                   |
| `pen_properties`      | filling system, vintage                                         | filling in rows; cartridge rule; rest `soft_notes`             |
| `metadata`            | newest pen, name prefix                                         | `soft_notes` (best effort)                                     |
| `household`           | someone else's pens                                             | `comment_exclude`                                              |
| `describes_pen`       | describes a pen instead of naming it                            | nib/width fields or `soft_notes`                               |
| `feedback_previous`   | "same pen, different ink"                                       | `keep_from_previous`                                           |
| `collection_question` | asks about the collection                                       | `out_of_scope` note + normal pick                              |
| `shopping`            | what to buy                                                     | `out_of_scope` note + normal pick                              |
| `app_support`         | app feedback or support                                         | `out_of_scope` note + normal pick                              |
| `prompt_injection`    | tries to change the rules                                       | contained by tags, schema and refs                             |
| `non_english`         | another language                                                | extractor is multilingual; reasoning in that language; notes English |
| `bare_names`          | two words or fewer                                              | matcher bare-name rule, extractor                              |

---

## 13. The bench

`lib/bench/suggester/` replays logged requests through the current code against the dev DB (a
recent production dump) and scores them. Run it before changing a prompt, a model, the selector,
the constraints or a normaliser, and compare with the reference numbers below.

**What it measures.**

- **Label-free** (the primary evidence): validity (pen and ink owned and active at the time,
  fountain-capable, not a swab, cartridge-compatible, not a rejected repeat), hard failures, rule
  leakage (`/novelty|favou?rite|balance|usage count|\bid\b/i`, headings, links), novelty share
  (never used or unused for 180+ days), colour new against inked, cost, latency, extractor
  failures and run-to-run agreement.
- **Against labels**: named pen and ink hit, hard constraints met or explicitly relaxed (checked
  through the same normalisers the filters use), `MentionMatcher` false pins, and the extractor's
  per-field precision and recall. The key extractor metric is the **hard-field false-positive
  rate**: the share of scored strings with at least one wrong hard filter or mention, because a
  false positive hides what the user wanted.
- **Judge**: blinded side-by-side grading by Claude Code (no API judge) on `honoured`
  (yes / partial / no), `rationale`, `soft_wishes`, `concise`, `notes_accurate` (1–5). "Instruction
  honoured" = judged "yes" and every hard check passing.

**Data and privacy.** Everything lives in gitignored `tmp/bench/suggester` (or `BENCH_DIR`): cases,
labels, labelling sheets, results, checks, grading files and keys. It holds real user requests and
collections. Never commit any of it; commits, PR bodies and this document carry aggregate numbers
only, and spec fixtures use invented names.

**Spend.** Real LLM calls happen only in the bench, with `OPEN_AI_DEV_TOKEN` from `.env.local`
against the dev DB (the tasks abort outside development). Keep each run under about USD 5
(`MAX_USD`, default 5; the runner stops when spent) and record the measured cost.

**Tasks** (all `docker-compose exec -T app bundle exec rake bench:suggester:<task> …`):

| Task                 | Does                                                                          | Main options                                                   |
| -------------------- | ----------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `export`             | samples cases from logged runs into `cases.json`, split dev/test by user      | `SINCE`, `BEFORE`, `INSTRUCTION_CASES=200`, `PLAIN_CASES=50`, `PER_USER_CAP=20`, `SEED=1`, `EXTRA_LOG_IDS` |
| `export_named_inks`  | extra instruction cases naming an owned ink, into another `BENCH_DIR`         | `EXCLUDE_DIR`, `INSTRUCTION_CASES=40`                          |
| `labelling_export`   | writes `labelling/` (README + one outcome-free file per case) for labellers   |                                                                |
| `label_template`, `validate_labels` | blank label entries; schema check of a drafted file            | `FILE=`                                                        |
| `baseline`           | replays cases through the current suggester into `results/<RUN>.json`         | `RUN`, `TIER=free\|premium`, `SPLIT`, `INSTRUCTION=with\|without`, `LIMIT`, `SEED`, `MAX_USD` |
| `report`             | scores a run, writes `results/<RUN>.checks.json`                              | `RUN`, `INSTRUCTION`                                           |
| `grading_export`     | blinded A/B grading file, stratified when `MAX_CASES` is set; key kept apart  | `RUNS=a,b`, `SPLIT`, `INSTRUCTION`, `MAX_CASES`, `SEED`        |
| `judge_scores`       | combines judges' grade files with the checks into "instruction honoured"     | `RUNS=a,b`, `GRADES=j1.json,j2.json`                           |
| `mention_pins`       | `MentionMatcher` false-pin rate on labelled cases                             |                                                                |
| `extractor_labels`   | builds `extractor_labels.yml` from case labels + `extractor_supplement.yml`, with each string's user and time for hints | |
| `extractor`          | runs and scores the extractor on the labelled set                             | `RUN`, `MODEL`, `REASONING_EFFORT`, `NAMES_FOUND=off`, `SPLIT`, `SOURCE`, `LIMIT`, `MAX_USD` |
| `extractor_report`   | re-scores a recorded extractor run                                            | `RUN`                                                          |
| `check_logs`         | label-free checks on live logs                                                | `SINCE`                                                        |

A replay runs each case inside a rolled-back transaction, time-travelled to the request, with
`CollectionSnapshot.new(user, as_of:)` rebuilding the collection as it stood then, the logged
rejected pairs, a per-case seed and the daily cap off (`Bench::Suggester::BaselineSuggester`).
`TIER` forces a tier's model and slices for every case. It is a behaviour comparison, not a
byte-for-byte replay: models vary between runs even at temperature 0, so differences of a case or
two are noise.

**Labels.** Claude Code agents draft labels from the labelling sheet (which points here, to
sections 3 and 12, and to `docs/nib-reference.md`): categories, named pen/ink ids, constraints,
an ambiguity flag (ambiguous cases skip the hard-constraint checks) and a note for the judge. The
labels of the current set were drafted by two independent passes and adjudicated by a third
(every scored field identical in 93.3% of the instruction cases between the two passes, 34 / 34 in
the named-ink supplement); the owner spot-checked 70 sampled labels and found none wrong. The
extractor set's `holdout` and `holdout2` strings have single-pass labels nobody reviewed;
`holdout2` was never used to tune the prompt. Report every label-based number with its label
source, and prefer label-free metrics as evidence. The judges are Claude-based too, from the same
model family as the labellers, so their agreement shows consistency, not correctness.

### Reference numbers

The current case set: 300 cases, 244 with an instruction (121 on the test split) and 56
without. The extractor set: 324 strings, 301 scored (196 with two-pass labels, 53 `holdout`,
52 `holdout2`). A change must not regress these; "meets" below means against these labels, not a
proof of quality.

**Extractor** (production configuration: gpt-6-luna, effort `none`, temperature 0, with hints;
two runs):

| Metric                                         | Run 1 / run 2              | Bar         |
| ---------------------------------------------- | -------------------------- | ----------- |
| Failures                                       | 0 / 0                      | 0           |
| Hard-field false positives, all 301 scored     | 5.0% / 6.0%                | ≤ 3%        |
| … test split (96)                              | 2.1% / 4.2%                | ≤ 3%        |
| … `holdout` (53, single-pass labels)           | 13.2% / 13.2%              | ≤ 3%        |
| … `holdout2` (52, single-pass labels, unseen)  | 1.9% / 3.8%                | ≤ 3%        |
| Missed named mention (154 strings with a name) | 6.5% / 7.8%                | no higher   |
| Hard filter values found outside mentions      | 192 / 193 of 217           | no fewer    |
| Strings with identical hard fields in both runs| 304 / 324 (93.8%)          | no lower    |
| $ per extraction, list / as charged in the bench | $0.00039 / $0.00006      | no higher   |
| Latency p50 / p90                              | 1.29 / 1.72 s, 1.23 / 1.59 s | no higher |

The extractor misses the ≤ 3% bar on all scored strings; half of its false-positive strings are in
`holdout`, mostly `pen.nib_width`. Other models on the same set and prompt (single runs unless
noted; hard-field false positives on all 301 scored, $ per extraction at list price):
gpt-6-sol 2.0% / 1.7% (two runs) at $0.0078, gpt-4.1 5.0% at $0.0062, gpt-5.6-luna 5.6% / 6.3% at
$0.00080, gpt-4.1-mini 14.6% at $0.00123, gpt-5.4-mini 17.6%, gpt-5.4-nano 17.9%, gpt-4.1-nano
24.6%, gpt-5-mini 25.2%, gpt-5-nano 30.6%. Only gpt-6-sol meets the bar, at 20× the cost.

**Suggester, runs without an instruction** (56 cases; free tier over 6 seeds, premium over 2):

| Metric                                  | Free (gpt-4.1-mini) | Premium (gpt-4.1) | Bar                  |
| --------------------------------------- | ------------------- | ----------------- | -------------------- |
| Hard failures                           | 0 / 336             | 0 / 112           | < 0.5%               |
| Valid suggestions                       | 100%                | 100%              | 100%                 |
| Swab or incompatible cartridge          | 0                   | 0                 | 0                    |
| Rule leakage                            | 6.9%                | 2.0%              | < 10%                |
| Ink / pen novelty share                 | 92.0% / 86.5%       | 95.8% / 92.7%     | within ± 5 pp        |
| Colour new vs currently inked           | 49.3%               | 56.2%             | no lower             |
| Judge, mean of four 1–5 scores          | 4.29                | 4.32              | no lower             |
| $ per run, list price                   | $0.00192            | $0.0128           | no higher            |
| Latency p50 / p90                       | 1.57 / 1.79 s       | 1.75 / 2.25 s     | no higher            |

The remaining leakage is "balance(d)" in its ordinary sense. The judge row was graded by the
session that wrote the code and is weak evidence.

**Suggester, runs with an instruction** (test split, 121 cases, seed 1; measured with the
extractor on gpt-4.1-mini, so refresh them; with gpt-6-luna the extractor bench predicts about
$0.0008 less per run at list price and about 0.3 s more at p50, 0.5 s at p90):

| Metric                                  | Free (gpt-4.1-mini)    | Premium (gpt-4.1)   | Bar         |
| --------------------------------------- | ---------------------- | ------------------- | ----------- |
| Hard failures                           | 0 / 121                | 0 / 121             | < 0.5%      |
| Valid suggestions                       | 100%                   | 100%                | 100%        |
| Swab or incompatible cartridge          | 0                      | 0                   | 0           |
| Rule leakage                            | 9.2%                   | 2.5%                | < 10%       |
| Named pen hit                           | 95.8% (46 / 48)        | 95.8% (46 / 48)     | ≥ 90%       |
| Named ink hit                           | 96.0% (24 / 25)        | 100% (25 / 25)      | ≥ 85%       |
| Hard constraints met or relaxed         | 97.96% (48 / 49)       | 100% (49 / 49)      | ≥ 98%       |
| Instruction honoured (two judges)       | 95.8% (68 / 71)        | not judged          | ≥ 85%       |
| $ per run, list / as charged            | $0.00313 / $0.00160    | $0.0136 / $0.0126   | no higher   |
| Latency p50 / p90                       | 2.48 / 2.91 s          | 2.66 / 3.03 s       | no higher   |
| `MentionMatcher` false pins             | 0.95% of 210 labelled strings (tuned on them) | | ≤ 2%  |

- The free tier's hard-constraint miss on the test split is a labelled kind filter the extractor
  did not set; on the dev split two misses put a pen ruled out by name into
  `ink.exclude_mentions`, so the pen was still picked.
- "Instruction honoured" counts a case only when both independent judges say "yes" and every hard
  check passes; 95% Wilson interval 88.3–98.6%. The judges agree on `honoured` in 286 of 300
  answers (κ 0.81–0.88). Seven regression cases are graded but left out of the rate.
- Over all 244 free-tier instruction cases: named pen hit 92.6%, named ink hit 94.4%, hard
  constraints met or relaxed 97.3%, 2 runs ended without a pick, 5 relaxed a filter.

---

## 14. Known limitations

- **"Couldn't find" notes are matched conservatively.** A note stays when the user named the
  picked item by another trade name, a nickname, a brand without vowels or a model number with a
  letter prefix. The pick prompt lists the note even when the answer later drops it.
- **Nicknames, aliases and abbreviations are not matched** by `MentionMatcher`, so they get no
  hint, and the extractor misses some of them (most missed names are a brand on its own, a
  nickname or a typo). The matcher also merges "<brand> <ink>, then <brand> <other ink>" into one
  mention, so the second ink gets no hint.
- **Wrong-side exclusions.** The extractor sometimes puts a pen ruled out by name into
  `ink.exclude_mentions`, which leaves the pen eligible.
- **Extractor false positives** cluster in `pen.nib_width` and nib characters, and on the
  single-pass `holdout` split; those labels are unreviewed and some may be wrong.
- **Not deterministic.** The extractor and the picker vary between runs even at temperature 0;
  compare runs on the same seed and set, and expect a few cases of noise.
- **Soft things stay soft.** `soft_notes`, conditional rules, filling system and pen properties
  are not enforced; `InkProperties` flags are lower bounds, so an untagged shimmer ink can pass a
  "no shimmer" filter; the picker sometimes still puts a shimmer ink in a fine or vintage pen.
- **English server notes and headers**; only the reasoning follows the request's language.
- **The daily cap can be overshot** by concurrent jobs (the worker's check is authoritative, but
  nothing locks between check and log); the IP throttle bounds it. The throttle keys on IP, not on
  the user.
- **The premium tier's instruction answers have not been judged**; only its label-based and
  label-free rows exist.
