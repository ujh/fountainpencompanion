# Criteria: is this ignored ink correctly ignored?

An ignored micro cluster is a group of collected inks that share the same simplified brand, line and
ink name and are kept out of the public ink catalogue (macro clusters). The clusterer agent
(`app/agents/ink_clusterer.rb`), its checker (`app/agents/check_ink_clustering/ignore.rb`) and admins
set the flag. Their rules are the starting point, but their decisions are often wrong for small or new
makers, so every decision here is made from the data and independent evidence.

Brands in `UpdateMicroCluster::IGNORED_BRANDS` (e.g. Sirius, hundreds of one user's own inks) are
excluded from the review entirely; `export.rb` leaves them out.

## Correctly ignored (verdict `keep_ignored`, with a category)

| Category         | What it looks like                                                                                                                                                                  |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `generic`        | No identifiable maker: "Generic", "Unbranded", "No name", "Cartridge", a stationery chain's no-name cartridges, a pen brand's anonymous bundled cartridges with only a colour       |
| `unidentified`   | The owner does not know which ink it is: "Unknown", "?", "Mystery", "Sample from a swap", "Unlabelled", or a colour-only name that matches no ink (see below)                       |
| `mix`            | Two or more inks combined: ratios, "mix", "+", "&" or "/" joining two existing ink names, "50/50", "x drops of", named recipes of a mixing line (see below)                         |
| `diy`            | Self-made inks or recipes: "my own", "homemade", "custom" as line name, personal recipe names, an owner's own name as brand with no shop behind it                                  |
| `personal_brand` | One person's own label: a brand name a user gives their own mixes or DIY inks that no maker or shop sells. Counts alone never make a brand one (see below)                          |
| `incomplete`     | Only part of a name: brand plus line only (the line typed into the ink field), a name that is the line of existing catalogue inks, a word that means "ink" ("Montblanc Inchiostro") |
| `not_ink`        | Not an ink: pens, rollerball/ballpoint/gel refills, pencils, converters, pen flush/cleaning solution, water, paints. Ink additives and dilution liquids are inks (see below)        |
| `placeholder`    | Test entries, gibberish, notes to self, "placeholder", "asdf"                                                                                                                       |
| `other`          | Anything else that is clearly not a catalogue ink; explain in the reason                                                                                                            |

Generic and placeholder brand names (`MicroCluster::PLACEHOLDER_BRAND_NAMES`: generic, unknown, noname,
unbranded and similar) never count as catalogued brands; `brand_stats.catalogue_inks` is 0 for them and
`brand_known` is false.

### Colour-only names

A colour-only name is a brand (and optionally a line) plus only a plain colour word or colour phrase
("Green", "Dark Purple", "Blue Black"). Descriptive names (woods, places, moods, objects) are not
colour-only even when they suggest a colour ("Madera oscura" is a product name), and neither is a line's
own colour name, even in another language.

- It is a real ink when the maker sells an ink of exactly that name (Lamy Blue, Waterman Serenity Blue,
  Writech Black): `assign` or `create`.
- With a line given, it is shorthand for the line's ink of that colour when the catalogue has exactly one
  (Platinum Mixable Red): `assign` there.
- Otherwise it is `unidentified` ("Sailor Pink" when Sailor has dozens of pinks and none is called just
  "Pink"; "Lamy Yellow" when Lamy sells no yellow). Never assign it to the brand's nearest named ink
  (Montblanc Green is not Montblanc Irish Green).

### One-person labels (`personal_brand`)

A personal brand is described by what it is: a label for one person's own mixes or DIY inks (names that
look like recipes, notes or numbering, no shop or maker behind it), often many ignored inks entered by one
or two users and no catalogue inks (`brand_stats`, e.g. penink, mymix). Counts alone never make a brand
one: new makers, collaborations and misspelled brand names start with few users and no catalogue inks,
so research those. These brands are not added to `IGNORED_BRANDS`; the category is revisited when more
users add the ink.

### Mixing lines

In lines made for mixing, everything the maker sells as its own product (a bottle or a pen bundle) is an
ink; named recipes that users mix themselves from the maker's published formulas, and personal mixes, are
`mix`. For Platinum Mixable: the base colours, the Dilution Liquid and specials sold as their own product
(Dark Syrup, Mellow Green, Witches Potion) are inks; named recipes (Emerald Bay, Mendocino Twilight,
Pacifica Sunset) are mixes.

## Not correctly ignored

Ink additives sold to mix into ink (shimmer, glitter, sheen or similar, e.g. Birmingham Twinkle Sprinkle,
Pennonia Csillám) and dilution liquids sold as an ink product are catalogued like inks. A dilution liquid
is not a cleaning solution.

- `assign` — the same ink as an existing macro cluster: spelling variants, typos, translations or
  transliterations, a missing or extra line name ("Sailor / Yoi" is "Sailor Yurameku Yoi"), the brand
  written differently. Judge by the name most users entered, not a stray entry. Same line but a different
  colour is a different ink. A shimmer, glitter or sheen edition of an ink is a different ink unless the
  cluster already contains that edition. Names that differ only in line or format words (bottle,
  cartridge, standard line, product codes such as T52/T10) are one ink, not several. A similar-looking
  name is not enough: a name that could blend two of the maker's ink names is a possible mix, not a typo.
- `create` — a real ink with no macro cluster yet. Group micro clusters that are the same new ink with
  `group_with` so they end up in one cluster.
- Duplicate macro clusters (two clusters for the same ink, e.g. a renamed ink or a translated name) are
  merged: suggest them as `merge_suggestions` whenever you come across them, even when the ignored ink
  itself stays ignored.
- `unignore` — only for ignored micro clusters that still sit in a macro cluster (an inconsistent state
  from a race between the agent and an admin) when that macro cluster is the right one.

## Evidence

Strong signals that an ink is real:

- Several independent users entered the same name (excluding generic/unknown names).
- The brand already has clustered inks, especially recently created ones: a maker that is releasing new
  inks. Small makers (Etsy/Instagram shops, Korean, Chinese, Japanese, Taiwanese, Hungarian makers) often
  have little English web presence; search their shop, their Instagram, and native-language names.
- Retailer or pen-show exclusives and limited editions are real inks with their own names.

Weak or misleading signals:

- Agent log explanations. The checker often rejected "create" because a web search found nothing, and the
  clusterer then ignored the ink because creating was no longer allowed. That is not evidence the ink does
  not exist. Read the logs for hints (search terms, candidate clusters), never as facts.
- The closest embedding match. A small distance only means similar words; check the names.
- Search results that do not contain the exact ink name, or are about a different product sharing a word
  (a tattoo ink, a car seat): no evidence either way.

A `create` or `assign` needs at least one evidence entry. Prefer a page that names the exact ink (maker,
retailer, review, forum post with photos). Database facts count as `db:` evidence, e.g.
`db:macro_cluster/8207` with the note "Sailor Yurameku Yoi, 198 users, same ink name". A `create` that
rests on `db:` evidence only (users and the brand's catalogue, no page naming the ink) says so in its
reasoning.

## Known cases

Patterns learned in runs (pattern, verdict, why). Keep it short.

- Ignored right after a rejected create (about half of all ignores): the checker found nothing on the web.
  Research these; new small makers (Frostbell, Unchroma, Volfblack) have no findable web presence, so
  several users plus a brand catalogue is the evidence, and the verifier checks it.
- Users leave out the line ("Pilot Apricot Orange", "Robert Oster Polish", "Cafe Cally Spring Rain"):
  `assign` when the maker sells that ink name in one line only.
- Line typed as ink ("Sailor Tea Time", "Stipula Calamo", "Monteverde Piet Mondrian", "De Atramentis
  Deepwater Obsession"): `incomplete`.
- Renamed, translated or romanised inks with their own clusters (Noodler's Azure = Ottoman Azure, Kingdom
  Note Japanese vs romanised vs English names, Pennonia Hungarian vs English): `merge_suggestions`.
- Ignored but still assigned to the right macro cluster (Writech Black, Phoenix Feathers numbered inks):
  `unignore`.
- "Pen Ink" / 钢水 (Chinese for fountain pen ink) as brand, a pen brand's bundled cartridges (Riimoo
  Black), a cartridge size as brand (Standard International): `generic`.
- Korean makers (3 Oysters, ST.SHELTER): search Naver and Korean shops; catalogue names often carry the
  English name in parentheses.
