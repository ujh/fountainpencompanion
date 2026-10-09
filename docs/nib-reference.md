# Nib Reference

Status: reference agreed 2026-10-09. This file is the **source of truth** for the future
`NibProfile` class (`app/models/nib_profile.rb`, P1 of `docs/pen-and-ink-suggester-plan.md`) and
for the "Nib knowledge" section of the PenAndInkSuggester system prompt. When a rule here and the
code disagree, fix one of them in the same PR; when the prompt-sized extract changes, update both.

What it covers: how users write nib sizes in the free-text `collected_pens.nib` field (and the
`currently_inked.nib` snapshot), what those sizes mean across brands, how they map onto one
Western-equivalent width scale, and what the nib means for choosing an ink.

Widths are approximate. Sources disagree by ±0.1 mm, and paper, ink and wetness move a line about
one grade. The classification only has to be good enough to filter and explain; it doesn't need to
be perfect, and a misclassification is fixed by adding a row to the spec table.

---

## 1. Western grades

Jowo/Bock steel, Lamy, TWSBI, Kaweco, Pelikan, Montblanc, Diplomat and most Chinese makers.

| Grade             | Approx. line (mm) | Notes                                                      |
| ----------------- | ----------------- | ---------------------------------------------------------- |
| EEF / XXF         | ≤ 0.25            | rare; Osprey, Scribo, custom grinds                        |
| EF / XF           | 0.3–0.4           | Lamy EF is about a Japanese F–MF                           |
| F                 | 0.4–0.5           |                                                            |
| MF / FM           | ~0.5              | Diplomat FM; a Sailor or Pilot MF is on the Japanese scale |
| M                 | 0.55–0.7          |                                                            |
| B                 | 0.75–0.9          |                                                            |
| BB / double broad | 1.0–1.2           | Kaweco BB is the most common BB in the data                |
| BBB / 3B          | 1.3+              | Pelikan (re-introduced 3B), Montblanc                      |

- **Brand drift.** Pelikan (especially the gold M400 to M1000 nibs), Kaweco, Visconti and
  Montblanc run broad and wet. Lamy's steel Z50 runs mid. Chinese EF/F vary a lot: Hongdian and
  Wing Sung EF are very fine, Jinhao #6 F/M run broad. Drift is described in prompt text only; it
  never shifts a width class, so the classes stay interpretable.
- **Number-only "sizes"** describe the nib unit, not the line: `#5`, `#6`, `#8`, "Jowo #6",
  "Bock #6", and Conway Stewart / Sheaffer / Waterman `1`–`5`. They carry no width.

## 2. Japanese grades

Pilot/Namiki, Sailor, Platinum and Nakaya, plus Taccia, Nagasawa, Bungubox and Wancher, which use
Sailor or Platinum nibs.

**The one-step-finer rule.** Japanese grades run about one grade finer than Western ones: Japanese
F ≈ Western EF, Japanese M ≈ Western F, Japanese B ≈ Western M. `NibProfile` applies this through
a separate Japanese grade → mm table (section 5) whenever the brand is a Japanese-sizing brand.
About 21.6% of active pens are from these brands. The millimetre figures below are brand listings
for orientation; the class always comes from the grade table in section 5, so Pilot M (listed
0.45–0.5) and Pilot SM (0.5) are both Japanese M → 0.48 mm → W3, and Platinum `05` is W3 too.

| Brand                   | Grades, fine to broad (approx. mm)                                                                                |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Pilot (gold #5/#10/#15) | EF 0.25, F 0.3, SF 0.32, FM 0.4, SFM 0.4, M 0.45–0.5, SM 0.5, B 0.6, BB 0.8, C (coarse) 0.85 (Custom 912 listing) |
| Pilot steel             | Metropolitan / Prera / Kakuno F and M run finer than the gold nibs                                                |
| Sailor                  | EF, F, MF, M, B; MF is the most common Sailor grade                                                               |
| Platinum                | UEF, EF, F, SF (soft fine), M, SM (soft medium), B, C (coarse, about BB), Music                                   |
| Platinum Preppy/Plaisir | `02` / `03` / `05` = 0.2 / 0.3 / 0.5 mm, read as the Japanese grades EF / F / M (W1 / W2 / W3)                    |
| Nakaya                  | Platinum nibs (UEF to C, SF, SM, Music); often custom-ground (naginata-style, Elastic)                            |

## 3. Brand-specific codes

| Brand                             | Code                                      | Meaning                                                                                                    | Class / character                   |
| --------------------------------- | ----------------------------------------- | ---------------------------------------------------------------------------------------------------------- | ----------------------------------- |
| Pilot                             | `FA`                                      | Falcon-style cut-outs on the Custom 742/743/912; flexible, fine base                                       | W2, flex (range up to W5)           |
| Pilot                             | `SEF`, `SF`, `SFM`, `SM`, `SB`            | soft grades (Falcon/Elabo and soft gold nibs); bouncy, not true flex                                       | base grade, soft                    |
| Pilot                             | `WA`                                      | Waverly: up-turned tip, about 0.5 mm                                                                       | W4, waverly                         |
| Pilot                             | `PO`                                      | Posting: hard, down-turned, about 0.25 mm                                                                  | W1, posting                         |
| Pilot                             | `SU`                                      | Stub, about 0.63 mm                                                                                        | W4, stub                            |
| Pilot                             | `C`                                       | Coarse, about 0.85–0.9 mm                                                                                  | W5                                  |
| Pilot                             | `MS`                                      | Music: two slits, about 0.9 mm, very wet                                                                   | W5, music                           |
| Pilot                             | `CM`                                      | Calligraphy medium on the Metropolitan/Prera/Kakuno, about 0.6 mm italic                                   | W4, italic                          |
| Pilot                             | `S` (bare, Pilot/Namiki only)             | Signature: very broad, about BB                                                                            | W6, signature                       |
| Pilot                             | Parallel 1.5 / 2.4 / 3.8 / 6.0            | parallel-plate calligraphy pens                                                                            | W7, parallel                        |
| Sailor                            | `H-EF`, `H-F`, `H-MF`, `H-M`              | "hard" versions of the base grade                                                                          | base grade                          |
| Sailor                            | Soft F / Soft MF / Soft M                 | soft versions of the base grade                                                                            | base grade, soft                    |
| Sailor                            | `NEF`, `NF`, `NMF`, `NM`, `NB`            | Naginata Togi: fine when upright, broad when lowered                                                       | base grade, naginata (−1/+2)        |
| Sailor                            | Zoom                                      | rounded tall tip, about 0.5–1.5 mm depending on angle                                                      | W5, zoom (−2/+1)                    |
| Sailor                            | Music                                     | three tines, very wet                                                                                      | W5, music                           |
| Sailor                            | Fude de Mannen                            | bent at 40° or 55°, about F to 2 mm                                                                        | W5 nominal, fude (W3–W7)            |
| Sailor                            | Cross Point / Cross Concord / Cross Music | multi-layer gold, extremely wet and broad                                                                  | naginata family                     |
| Sailor                            | Emperor                                   | an extra gold plate under the nib, even wetter                                                             | naginata family                     |
| Sailor                            | King Eagle / King Cobra                   | rare, very broad, layered                                                                                  | naginata family                     |
| Platinum                          | `UEF`                                     | ultra extra fine                                                                                           | W1                                  |
| Platinum                          | `SF`, `SM`                                | soft fine, soft medium                                                                                     | W2 / W3, soft                       |
| Platinum                          | `C`                                       | coarse, about BB                                                                                           | W5                                  |
| Platinum                          | `02` / `03` / `05`                        | Preppy/Plaisir line widths 0.2 / 0.3 / 0.5 mm, read as EF / F / M                                          | W1 / W2 / W3                        |
| Pelikan                           | `KF`, `KM`, `KB`                          | vintage ball-tipped ("Kugel") nibs                                                                         | base grade                          |
| Pelikan                           | `IM`, `IB`                                | italic                                                                                                     | base grade, italic                  |
| Pelikan                           | `OF`, `OM`, `OB`, `OBB`, `O3B`            | oblique                                                                                                    | base grade, oblique                 |
| Esterbrook (vintage Renew Points) | four digits: series + style               | first digit is the series (1xxx/2xxx Dura-Crome steel, 9xxx Master/iridium); the last three give the style | see next table                      |
| Esterbrook (modern)               | Journaler                                 | stub by Gena Salorino, 0.57 mm vertical / 0.33 mm horizontal                                               | W4, stub (cross-stroke W2)          |
| Esterbrook (modern)               | Scribe                                    | architect-style, 0.38 mm vertical, broad horizontal                                                        | W3, architect                       |
| Esterbrook (modern)               | Needlepoint                               | hair-line                                                                                                  | W1, needlepoint                     |
| Esterbrook (modern)               | Techo                                     | naginata-style grind (CY / Tokyo Station Pens)                                                             | naginata family                     |
| Esterbrook (modern)               | Mini stub                                 | about 0.7 mm                                                                                               | W5, stub                            |
| Lamy                              | EF / F / M / B / BB                       | Western grades                                                                                             | Western table                       |
| Lamy                              | `LH`                                      | left-handed, about M                                                                                       | W4, left_handed                     |
| Lamy                              | `A`                                       | beginner nib (Lamy ABC), about M                                                                           | W4, beginner                        |
| Lamy                              | 1.1 / 1.5 / 1.9                           | calligraphy steps (the 1.1 writes a little under 1.1)                                                      | W6 / W7 / W7, stub                  |
| Lamy                              | Kanji, Cursive                            | Japan-market nibs with mild line variation, about 0.6 mm                                                   | W4, italic                          |
| TWSBI                             | EF … BB, Stub 1.1                         | Western grades; "1.1" and "1.1 Stub" are among the most common nib values                                  | Western table; W6, stub             |
| Jowo / Bock                       | EF … BB, 1.1 / 1.5 / 1.9                  | Western grades and stub steps; `#5`/`#6`/`#8` are unit sizes; Bock also makes titanium nibs                | Western table; stubs W6 / W7 / W7   |
| Franklin-Christoph                | SIG (also written `S.I.G.`)               | stub-italic gradient, between stub and italic                                                              | base grade, italic                  |
| Schon DSGN                        | Monoc                                     | titanium nib (grades F, M and Cursive exist)                                                               | material titanium; width from grade |
| Parker                            | Hooded                                    | Parker 51-style nib type                                                                                   | no width                            |
| Diplomat                          | FM                                        | Western fine-medium                                                                                        | Western MF                          |

**Esterbrook style digits** (last three digits of the Renew Point number):

| Digits | Style                 | Grade / character |
| ------ | --------------------- | ----------------- |
| 550    | extra fine            | EF                |
| 556    | firm fine             | F                 |
| 668    | firm medium           | M                 |
| 128    | flexible extra fine   | EF, flex          |
| 314    | relief (oblique stub) | M, oblique, stub  |
| 048    | Falcon stub           | F, stub           |
| 442    | medium stub           | M, stub           |

So `2668` is a Dura-Crome firm medium and `9550` a Master extra fine.

## 4. Grinds and characters

Characters are independent of width; a nib can carry several (a "1.1 Stub Steel" is stub + steel).

| Character       | Recognised as                                                                                                                                                        | What it does                                                                                | Width treatment                                        | Broad-ish?             |
| --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | ------------------------------------------------------ | ---------------------- |
| stub            | stub, Pilot SU, Journaler, mini stub, any width ≥ 0.9 mm                                                                                                             | flat rounded tip: broad verticals, thin horizontals; the number is the vertical stroke      | default 1.0 mm; range down to the cross-stroke (0.35×) | yes                    |
| italic          | italic, crisp italic, CI / FCI / MCI / BCI, CSI, cursive, SIG / S.I.G., Pelikan IM/IB, Kanji, calligraphy, Pilot CM                                                  | sharper edges than a stub: more contrast, less forgiving; CI and CSI are rounded italics    | default 0.9 mm; range down to the cross-stroke         | yes                    |
| parallel        | Pilot Parallel 1.5 / 2.4 / 3.8 / 6.0                                                                                                                                 | two parallel plates, calligraphy                                                            | W7                                                     | yes                    |
| architect       | architect, arch, Scribe, Hebrew, Arabic                                                                                                                              | reversed stub: broad horizontals, thin verticals                                            | default 0.6 mm; range up by 2 classes                  | yes                    |
| reverse grind   | reverse                                                                                                                                                              | written on the back of the nib: finer and drier                                             | none                                                   | no                     |
| oblique         | oblique, OEF / OF / OM / OB / OBB / O3B, left-foot, relief                                                                                                           | tip ground at an angle for rotated grips; mild stub-like variation                          | base grade                                             | no                     |
| left-handed     | LH, left-hand                                                                                                                                                        | Lamy left-handed nib, about M                                                               | default 0.6 mm                                         | no                     |
| fude            | fude, bent, brush                                                                                                                                                    | tip bent up; about F upright to 1.5–2 mm+ lowered ("brush" is often a brush pen, not a nib) | default 0.9 mm (W5); range W3–W7                       | yes                    |
| naginata family | naginata, nag, togi, Sailor N-prefixed grades, Kodachi, Long Knife / Long Blade, blade, Techo, Keiryu, Cross Concord / Cross Point, Emperor, King Cobra / King Eagle | fine upright, broader lowered; usually wet                                                  | default 0.55 mm; range −1 / +2 classes                 | yes                    |
| zoom            | zoom; bare `Z` on a Japanese-sizing brand                                                                                                                            | Sailor: rounded tall tip, wider the lower the angle                                         | default 0.8 mm; range −2 / +1                          | yes                    |
| music           | music, MS                                                                                                                                                            | two slits / three tines; very wet, broad verticals, narrower horizontals                    | default 0.9 mm; range −2 / +1                          | yes                    |
| flex            | flex (not semi-flex), FA, Falcon, wet noodle, Zebra G, Omniflex, Ultra Flex, Ahab / Konrad "Flex", Esterbrook 128                                                    | fine at rest, 1–2 mm under pressure; needs wet, free-flowing ink or it railroads            | default 0.45 mm (Pilot FA 0.35); range up by 3 classes | no                     |
| soft            | soft, elastic, semi-flex, SEF / SF / SFM / SM / SB, Sailor soft grades                                                                                               | bouncy, mild variation; not flex                                                            | base grade; range up by 1 class                        | no                     |
| needlepoint     | needlepoint                                                                                                                                                          | hair-line, ≤ 0.25 mm                                                                        | default 0.22 mm                                        | no                     |
| posting         | posting, Pilot PO                                                                                                                                                    | hard, down-turned, very fine                                                                | default 0.22 mm                                        | no                     |
| waverly         | waverly, waverley, Pilot WA                                                                                                                                          | up-turned tip, smooth                                                                       | default 0.5 mm                                         | no                     |
| signature       | signature, bare `S` on Pilot/Namiki                                                                                                                                  | very broad                                                                                  | default 1.0 mm                                         | no (W6 already counts) |
| beginner        | Lamy or Pelikan `A`, beginner, Anfänger                                                                                                                              | beginner nib, about M                                                                       | default 0.6 mm                                         | no                     |

**Material** (independent of width and character): gold for a karat number (9–22 k/kt/ct) or
585/750/875/916; steel for steel (and the typo "steal"), SS, stainless, Edelstahl, inox, acier,
"iridium point" and gold-plated, gold-tone or gold-coated; titanium for titan, Ti and Monoc; then a
bare "gold" or palladium. Gold nibs tend to be softer and springier than steel, but most modern gold
nibs are still firm; titanium is springy.

"Broad-ish" in the right-hand column is the set used for vague width requests (section 9): a nib
counts as broad-ish when its class is W4 or more, or it carries one of these characters.

## 5. Width classes W1–W7

One Western-equivalent scale. Japanese sizing is applied before the class is assigned, so a Pilot
M and a Lamy F land in the same class.

| Class | Label | Line (mm) | Western grades | Japanese grades    | Specialist and brand nibs (nominal)                       |
| ----- | ----- | --------- | -------------- | ------------------ | --------------------------------------------------------- |
| W1    | XXF   | ≤ 0.27    | UEF, EEF       | UEF, EEF, EF, SEF  | needlepoint, Pilot PO (posting)                           |
| W2    | EF    | 0.27–0.37 | EF             | F, SF              | Pilot FA (flex)                                           |
| W3    | F     | 0.37–0.49 | F              | MF, FM, SFM, M, SM | —                                                         |
| W4    | M     | 0.49–0.69 | MF, M          | B                  | Pilot WA, SU, CM; Journaler                               |
| W5    | B     | 0.69–0.94 | B              | BB, C (coarse)     | Zoom, Music, fude (nominal)                               |
| W6    | BB    | 0.94–1.24 | BB             | BBB                | 1.0–1.2 mm stubs/italics; Pilot S (Signature)             |
| W7    | BBB+  | > 1.24    | BBB/3B         | —                  | stubs from 1.3 mm (1.5, 1.9), Pilot Parallel, calligraphy |

This table and the width-class lines of the suggester's system prompt
(`docs/pen-and-ink-suggester-plan.md`, section 3.2) say exactly the same thing; P7 of that plan
adds a spec that pins the prompt lines to the `NibProfile` constants. Every other code's class is
in section 3 (for example Platinum `02`/`03`/`05` → W1/W2/W3, Esterbrook Scribe → W3, Lamy A/LH →
W4, mini stub → W5). Western MF (0.50 mm) sits just above the W3/W4 boundary.

**Grade → mm, Western and Japanese:**

| Grade      | Western mm | Japanese mm |
| ---------- | ---------- | ----------- |
| UEF        | .20        | .17         |
| EEF        | .25        | .20         |
| EF         | .35        | .25         |
| F          | .45        | .32         |
| MF         | .50        | .40         |
| M          | .60        | .48         |
| B          | .80        | .62         |
| BB         | 1.05       | .80         |
| BBB        | 1.3        | 1.0         |
| C (coarse) | n/a        | .90         |

Worked examples: Pilot F → W2, Lamy F → W3; Sailor MF → W3, Pelikan M → W4; Pilot C and Platinum C
→ W5; Pilot M and Sailor M → W3.

**Ranges.** Nibs whose line varies keep the nominal class for filtering and a `width_min` /
`width_max` for display and reasoning: stubs and italics down to the cross-stroke (about 0.35× the
stated width), architect up 2 classes, flex up 3, soft up 1, fude W3–W7, naginata −1/+2, zoom and
music −2/+1. A row shows them as e.g. `1.1 Stub → W6 stub (cross-strokes W3)` or
`Fude → W5 fude (W3–W7)`.

## 6. Synonyms and spellings

| Grade | English and abbreviations                                         | Other languages                              |
| ----- | ----------------------------------------------------------------- | -------------------------------------------- |
| UEF   | ultra extra fine, ultra fine, UEF                                 |                                              |
| EEF   | extra extra fine, EEF, XXF                                        |                                              |
| EF    | extra fine, extra-fine, EF, XF, X F                               | extra fino (es/it)                           |
| F     | fine, F                                                           | fino, fina (es/it/pt), fein (de)             |
| MF    | medium fine, med fine, fine medium, fine-medium, MF, FM, F/M, M/F |                                              |
| M     | medium, med, M                                                    | medio, mediano, mediana (es/it), mittel (de) |
| B     | broad, bold, B                                                    | breit (de), ancho (es)                       |
| BB    | double broad, extra broad, BB, EB, XB                             |                                              |
| BBB   | triple broad, BBB, 3B                                             |                                              |
| C     | coarse; bare `C` only on a Japanese-sizing brand                  |                                              |

**Prefixes that carry a character and leave the base grade:**

| Prefix / suffix       | Example          | Meaning                      |
| --------------------- | ---------------- | ---------------------------- |
| `S` (soft)            | SEF, SF, SFM, SM | soft version of the grade    |
| `H-` (Sailor hard)    | H-MF             | hard version of the grade    |
| `N` (Sailor naginata) | NMF              | Naginata Togi on that grade  |
| `K` (Pelikan Kugel)   | KF, KM, KB       | ball-tipped vintage grade    |
| `I` (Pelikan italic)  | IM, IB           | italic on that grade         |
| `O` (oblique)         | OM, OB, OBB, O3B | oblique on that grade        |
| `CI` (cursive italic) | FCI, MCI, BCI    | cursive italic on that grade |

`F/M` is ambiguous (fine-medium, or a pen with two nibs) and is read as MF.

**Request vocabulary** (what users type to the suggester, not into the nib field):

- **Literal grades** name a grade: "M nib", "medium nib", "a M or B nib", "B nib". They match the
  grade parsed from the pen's own nib text, whatever its width class.
- **Vague width words** hedge or compare: "fairly broad", "broad-ish", "something wide", "wider",
  "breitere Feder" (de), "something fine". They use the width class: broad-ish, broad (W5+) or fine
  (W1–W3 without a broad-ish character).
- **Characters** are named directly: "stub", "soft", "flex", "architect", "fude". "Not broad or
  stub" excludes the broad-ish width and the stub character.

**Typos.** A misspelling such as "Mediium" stays unknown. An optional Levenshtein ≤ 1 match on the
full words fine/medium/broad would catch most of them.

## 7. Parsing rules

The order matters; each step works on what earlier steps left.

| Step | Rule                                                                                                                                                                                                                                                                                                                                                                    |
| ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | **Clean-up.** Drop the prose words `of` and `im` (any case but all caps) unless they are the whole nib text; lowercase; `1,1` → `1.1`; letter `o.6` → `0.6`; `.6` → `0.6` unless the dot follows a letter, digit or dot (`No.6`, `Nr.8` stay unit sizes); `s.i.g.` → `sig`; `<>()[]{},;:+\|_` → space; collapse whitespace.                                                                                                                                                                                                                                                 |
| 2    | **Kind.** Junk values (section 8) → `unknown`. Ballpoint, BP, ballpen, pencil, highlighter, marker, felt, fineliner, gel, stylus, or a gel/rollerball brand with a mm number → `non_inkable`. Rollerball, roller, RB → `rollerball`. Glass, dip, Zebra G, Nikko, crow quill → `dip`. Everything else → `fountain`.                                                      |
| 3    | **Material.** First match wins: karat number or 585/750/875/916 → gold; steel words and gold-plated/tone/coated → steel; titan/Ti/Monoc → titanium; bare gold or palladium → gold.                                                                                                                                                                                      |
| 4    | **Prefixes.** `[efmb]ci` → cursive italic + base grade; Sailor `n(ef\|f\|mf\|m\|b)` → naginata + base grade; Sailor `h-` → base grade; the German `k`/`i`/`o` prefixes (Pelikan, but also Lamy, Montblanc, Kaweco, Parker, Waterman and others, so on every brand) and soft `s` prefixes → character + base grade.                                                                                                                                                              |
| 5    | **Characters.** Every pattern in section 4 that matches is added. "Semi-flex" is soft only, never flex. A bare `s` is Signature only on Pilot/Namiki.                                                                                                                                                                                                                   |
| 6    | **Grade.** First match wins, in this order: UEF, EEF, EF, MF, BBB, BB, C (Japanese brands only), F, M, B, using the synonyms in section 6.                                                                                                                                                                                                                              |
| 7    | **Numbers.** A mm value or a decimal is a line width. ≥ 0.9 mm means stub, except Pilot 1.5 / 2.4 / 3.8 / 6.0, which are Parallel. `02`/`03`/`05` (and `.03`, `0.03`) are read as the grades EF / F / M and sized by brand (Platinum: W1 / W2 / W3); on Platinum the decimals `0.2` / `0.3` / `0.5` are read the same way. Bare integers (`2`, `#6`, `No.6`, `5`) are unit sizes and ignored. Esterbrook four-digit codes go through the style table (on an Esterbrook brand, or when the whole nib text is the code). |
| 8    | **Width.** An explicit mm wins; then a code with its own width (Pilot SU 0.63, Pilot CM 0.6, Pilot FA 0.35, Journaler 0.57, mini stub 0.7, Scribe 0.45, Lamy Kanji/Cursive 0.6); then the grade through the Western or Japanese table (by brand); then the character's default width (section 4). The mm value is then bucketed into W1–W7 (section 5).                 |
| 9    | **Range.** Applied from the characters (section 5).                                                                                                                                                                                                                                                                                                                     |
| 10   | **Empty nib.** Fall back to strong tokens in the model name only: flex, fude, parallel, music, zoom, stub, an explicit `\d.\dmm`, or a trailing grade in parentheses ("Noodler's Ahab Flex", "Pilot Parallel 2.4 mm", "Nemosine .6mm Stub"). Loose matching is wrong: "Year **of** the Rabbit" would read as oblique fine.                                              |
| 11   | **Confidence.** `high` with a grade, mm or code width; `medium` from a character default; `material_only`, `character_only` or `none` otherwise.                                                                                                                                                                                                                        |

**Japanese-sizing brands:** Pilot, Namiki, Sailor, Platinum (also misspelt "Platinium"), Nakaya,
Taccia, Nagasawa, Bungubox (also "Bungbox"), Wancher, Kuretake, Eboya, Kakimori, Sakura, Ohashi,
Kyuseido, and the misspelling "Platnum". Extend the list from the data.

**Representation** returned by `NibProfile.parse(nib, brand:, model:)`:

| Field                    | Values                                                                             |
| ------------------------ | ---------------------------------------------------------------------------------- |
| `raw`                    | the original text                                                                  |
| `kind`                   | `fountain`, `rollerball`, `dip`, `non_inkable`, `unknown`                          |
| `grade`                  | literal grade before sizing: UEF, EEF, EF, F, MF, M, B, BB, BBB, C, or nil         |
| `width`                  | nominal class 1–7 (W1–W7), or nil                                                  |
| `width_min`, `width_max` | 1–7, for nibs whose line varies                                                    |
| `characters`             | list from section 4                                                                |
| `material`               | `gold`, `steel`, `titanium`, or nil                                                |
| `japanese_sizing`        | true when the width came from the grade through the brand's Japanese table         |
| `confidence`             | `high`, `medium`, `material_only`, `character_only`, `none`                        |
| `label`                  | display text, e.g. `MF → W3 (Japanese)` or `1.1 Stub → W6 stub (cross-strokes W3)` |
| `source`, `source_text`  | `nib`, or `model` for the empty-nib fallback, and the cleaned text that was parsed |

The profile is computed on the fly, with no DB column. Persisting it (`nib_width_class`,
`nib_characters`, `nib_kind` and a version for re-backfills) is only worth it if SQL-side filtering
or site-wide stats need it; a rule change would then mean a backfill of about 187k rows.

**Past inkings** use `currently_inked.nib.presence || collected_pen.nib`. The snapshot column is
written only when an inking is archived and is blank while the inking is active
(`currently_inked.rb:146-149`); for archived inkings it matters, because 8.7% of them differ from
the pen's current nib (nib swaps and edits).

## 8. Non-fountain, junk and unknown values

| Value class      | Examples                                                                                                                                                     | `kind` / width       | Treatment                                                                                                                     |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Junk / unknown   | `?`, `-`, `---`, None, Unknown, N/A, idk, tbd, Various, Multiple, Interchangeable, Double Ended, unmarked, standard, stock, default                          | `unknown`, no width  | eligible for suggestions; excluded from nib filters and counted, never dropped silently                                       |
| Material only    | Steel, 14K, 18K, Gold, Brass, Stainless Steel                                                                                                                | `fountain`, no width | as unknown width; the material is kept                                                                                        |
| Nib unit only    | Jowo, Jowo #6, Bock, #6, Bock #6, Monoc, Hooded, Warranted, bare `1`–`5`                                                                                     | `fountain`, no width | as unknown width                                                                                                              |
| Rollerball       | Rollerball, roller, RB                                                                                                                                       | `rollerball`         | not suggested by the suggester; a few take fountain pen ink (J. Herbin with converter, Super5), so they are not `non_inkable` |
| Not inkable      | Ballpoint, BP, pencil, highlighter, marker, felt tip, fineliner, gel, stylus; gel brands with a mm number (uni-ball, Pentel EnerGel, Zebra Sarasa, Muji gel) | `non_inkable`        | never suggested                                                                                                               |
| Dip / glass      | Glass, dip, Zebra G, Nikko, crow quill                                                                                                                       | `dip`                | not suggested                                                                                                                 |
| Unresolved codes | Sankakusen (a triangle grind), Script, Scythe, Speerpoint, Monoline, 1A, N, XS, XL, E, L, Perspective, Imperial, Triumph                                     | `fountain`, no width | each under 0.01% of pens; add rules on demand                                                                                 |

Do not use a bare "0.38" to detect gel pens: Chinese fountain pens are labelled that way too
("EF (0,38 mm)").

## 9. Using the profile in filters

- **Literal grades** compare the parsed `grade`, never the width class. "M nib" matches a Pilot
  Custom 74 M (W3) and a Pelikan M (W4) alike.
- **No grade parsed** (a bare mm value, a numbered stub): a literal grade request falls back to the
  width class, matching when the pen's class equals the grade's Western class (B → W5).
- **Vague widths** use the class: `broadish` = W4+ or a broad-ish character (stub, italic, fude,
  music, architect, zoom, naginata, parallel); `broad` = W5+; `fine` = W1–W3 with no broad-ish
  character.
- **Nominal width** decides, so a flex F is not broad.
- **Unknown** widths and grades are excluded from nib filters and counted in a note; they stay
  eligible when no nib filter applies.

## 10. Ink-to-nib guidance

Soft guidance for reasoning, not hard rules.

- **Visible effects need ink volume.** Sheen, shimmer and shading show best in W4+ and wet nibs,
  stubs, music, fude and flex. In EF/F they mostly vanish.
- **Shimmer** needs W4+ and a wet feed; particles clog fine feeds. Use pens that are easy to flush
  (cartridge/converter). Avoid vintage, vacuum, eyedropper and expensive piston fillers, and pens
  that will sit.
- **Pigmented / permanent inks** (Platinum Carbon, Sailor Kiwa-guro, Souboku): use pens that are
  used often and seal well (Platinum slip-and-seal caps), and flush regularly.
- **Iron gall** (Platinum Classic, R&K Salix/Scabiosa, ESSRI): safe in modern gold and steel nibs.
  Corrosion and staining come from leaving it in for months, so flush regularly. Vintage pens are a
  judgment call.
- **Pale colours** (yellows, light pinks, pastels, light greys) need W4+ or a stub to be legible.
- **Fine, dry or hard nibs** (Japanese EF/F, posting, needlepoint) suit saturated, well-lubricated,
  darker inks. Never pair a dry ink with a dry fine nib.
- **Wet broad nib + wet ink** gives slow dry times and feathering on cheap paper; that is fine for
  sheen on Tomoe River-type paper.
- **Flex and stubs** show off shading inks. Flex needs a wet, lubricated ink to avoid railroading.

## 11. Coverage (all 186,669 active pens, prod, 2026-10-09)

A Python prototype of these rules was used to measure coverage; the Ruby port is P1 of the
suggester plan. On the same export the Ruby port gives a width class to 92.6% of active pens (96.5%
of pens with a nib entered), with every class within 0.2k pens of the distribution below.

- **92.8%** of active pens get a width class (96.8% of pens with a nib entered). 4.1% have an empty
  nib, about 2.5% are material or unit only or junk, and 0.6% are non-fountain (512 rollerballs,
  573 ballpoints and the like). 14.9% carry at least one character.
- The most common raw values are F, M, EF, Fine, Medium, B, Broad, Extra Fine, MF, "1.1 Stub",
  Stub, "1.1", Flex, BB and Fude.
- **Width distribution:** W1 3.8k, W2 31.0k, W3 61.2k, W4 48.9k, W5 17.0k, W6 8.7k, W7 2.5k. So
  W4+ ("fairly broad") is about 41% of all 186,669 active pens (44% of the pens that get a class)
  and W5+ about 15% (16%).
- **Characters:** stub 9.8k, flex 5.5k, italic 4.6k, soft 2.3k, fude 1.6k, architect 1.4k,
  naginata family 1.1k, oblique 0.9k, music 0.7k, parallel 0.5k, zoom 0.5k, needlepoint 0.2k,
  waverly 0.2k.
- **Material:** gold 12.5k, steel 10.3k, titanium 0.5k (12.4% of pens say anything about material).
- **Japanese-sizing brands:** 40.3k pens (21.6%).
- **Historical suggestions:** 5 of 12,476 were rollerballs or ballpoints and 14 dip/glass pens;
  816 were pens with an unknown or empty nib, which should stay eligible.

## Sources

- Pilot nib codes and mm (Custom 912 / 743):
  https://www.penboutique.com/collections/pilot-custom-912/products/pilot-namiki-custom-912-black-fountain-pen ;
  https://yosekastationery.com/products/pilot-custom-heritage-912 ;
  https://fountainpennetwork.com/forum/topic/134017-the-pilot-custom-74x8xx-family
- Japanese vs Western sizing:
  https://www.fountainpennetwork.com/forum/topic/325015-line-sizes-pilotsailorplatinum/ ;
  https://www.purepens.co.uk/blogs/news/fountain-pen-nib-width-guide-ef-f-m-b-and-beyond ;
  https://goldspot.com/blogs/magazine/pilot-custom-74-vs-sailor-1911s-vs-platinum-3776-century-comparison
- Platinum 3776 grades:
  https://www.thejournalshop.com/blogs/guides/platinum-3776-century-complete-guide ;
  https://akkermandenhaag.nl/en/products/3776-platinum-century-zwart-vulpen ;
  https://blog.gouletpens.com/wed-review-platinum-3776-extra-fine/
- Sailor specialty nibs: https://yosekastationery.com/blogs/news/naginata-togi ;
  https://www.parkablogs.com/content/sailor-specialty-nib-new-2018-vs-old-pre-2016 ;
  https://www.parkablogs.com/picture/review-sailor-profit-21-zoom-nib-fountain-pen ;
  https://www.parkablogs.com/picture/review-sailor-naginata-fude-de-mannen-nib-fountain-pen
- Kodachi: https://bungubox.shop/products/nib-customize ;
  https://vanness1938.com/products/vanness-jowo-6-nibs
- Esterbrook Journaler / Scribe / Needlepoint / Techo:
  https://goldspot.com/blogs/magazine/esterbrook-fountain-pen-nib-size-comparison ;
  https://www.penboutique.com/blogs/blog/esterbrooks-estie-the-possibilities-are-almost-endless?page=2
- Esterbrook Renew Point numbers:
  https://gopens.com/blogs/the-gopens-blog/esterbrook-point-selection-chart ;
  https://vintagepens.com/Esterbrook.shtml
- Franklin-Christoph SIG: https://www.penaddict.com/blog/2016/8/5/the-franklin-christoph-sig-nib-a-review ;
  https://wellappointeddesk.com/2019/01/pen-review-franklin-christoph-sig-nib-from-audrey
- Schon DSGN Monoc:
  https://www.gentlemanstationer.com/blog/2023/9/13/pen-review-the-schon-dsgn-monoc-nib-fine-tip
- Pelikan / Montblanc width drift:
  https://fountainpennetwork.com/forum/topic/166788-pelikan-nibs-how-do-they-compare-in-width-to-other-makes ;
  https://thepelikansperch.com/2019/09/19/pelikan-expands-nib-lineup/ ;
  https://www.fountainpen.de/faq-en/94f34f-how-do-the-nib-widths-m-and-b-compare-with-each-other-at.htm
