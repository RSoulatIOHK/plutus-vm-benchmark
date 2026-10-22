# Report page UI review (2026-10-22)

Scope: `report/template.html` rendered by `report/generate_report.py`, the static page at
plutus-vm-bench.lantr.io. Reviewed on the fixture runs `2026-10-22` and `2026-11-01` (5 scripts,
9 ranked VMs + Scalus JIT experimental) at 1400 px and 420 px wide.

Audience: Cardano library and node authors who choose a Plutus evaluator. They must see fast:
who is fastest, what is measured (decode + eval vs eval only), whether the results are
trustworthy (correctness gate, environment, harness commit), and the change over time. The page
must stay neutral: Lantr maintains it and also maintains Scalus.

Semantics that do not change: the ranking uses decode + eval (D3); the per-script table shows
eval only first; Scalus JIT is experimental (hatched in the bars, dashed in the history, never the
1.00× reference, never "fastest"); the history is speed relative to Haskell, higher is faster;
credits and the harness commit link stay in the footer; the Aiken notes and the badges stay.

## Must

**M1. The VM colours fail colour-vision checks.** The 9 hues fail the dataviz validator on the
dark surface `#09090f`:

```
[FAIL] CVD separation       worst all-pairs #00d4aa↔#ff8fab ΔE 1.7 (deutan)
[FAIL] Normal-vision floor  worst all-pairs #e44d7b↔#ff6b6b ΔE 9.1 (normal)
[WARN] Contrast vs surface  #5e5086 2.81:1
```

Four VMs are red or pink (Scalus JIT, Scalus CEK, Scalus.js, Aiken); plutus-core is a dark
violet below 3:1. Fix: the validated 8-slot dark palette, one fixed colour per VM (the colour
follows the VM in every run). plutus-core is the reference (neutral grey); experimental Scalus JIT
is neutral light grey, dashed and hatched, so 8 hues cover the other 8 VMs. Validated result
(`validate_palette.js --mode dark --surface #09090f`, adjacent pairs): ALL CHECKS PASS, worst
adjacent CVD ΔE 8.4, normal-vision ΔE 19.3, all ≥ 3:1. The same on `#111119`.

**M2. Muted text is below the contrast floor.** `--text-muted #5c5c78` is 2.9:1 on the card
surface, and it carries most of the metadata (runtime, eval only, ratios, axis labels, table
sub-headers) at 10–12 px. WCAG wants 4.5:1. Fix: `#8484a2` (5.2:1) and no text below ~11 px.

**M3. The card's headline number has no label.** The big number is the decode + eval geometric
mean, and the ratio is "× the fastest ranked VM in the category", but the card says neither. The
"eval only" line above it reads like the headline's label. Fix: label the number
("decode + eval, geo mean") and the ratio ("× fastest"); show eval only as a labelled secondary row.

**M4. The geometric-mean bars mislead.** The bar length is log-scaled with a 5 % floor, and there
is no axis: Aiken's bar looks ~1.5× blaze-plutus (Bun), the real ratio is 6×. The labels sit on
the coloured fills (grey on yellow, grey on red), and some cross the fill edge. Each bar has a VM
hue, which re-encodes the label. Fix: a visible log axis with ratio ticks (1×, 2×, 5×, …), one
neutral hue for ranked bars, Scalus JIT hatched; the name and the numbers in columns outside the
bar; a caption that says what is plotted (decode + eval geo mean, ratio to the fastest ranked VM).

**M5. Mobile overflows and becomes unreadable.** At 420 px the page is 477 px wide (header, the
Contribute button, the cards cut). The history SVG has a fixed 960 px viewBox, so its 10 px text
becomes ~4 px. The bar rows wrap the name into the time column. Fix: a responsive header, single
column cards below ~520 px, the history drawn at the container width (end labels dropped when
narrow; the legend and the tooltip carry them), the bar rows stacked.

**M6. The per-script table is hard to read with 10 VMs.** 19 columns; the script column scrolls
away; nothing shows that "Plutigo eval only" and "Plutigo" belong together; the sub-headers repeat
the runtime and "decode + eval" on every column. Fix: a two-row header (the VM spans its eval-only
and decode + eval columns), a sticky script column, a divider between VMs, short sub-headers.

**M7. What is measured and why to trust it is at the bottom.** The decode + eval vs eval-only
definition and the correctness gate are only in Method. Fix: a short "what is measured" strip
under the header: the ranking metric, the gate result (N of N VMs passed), the drift, the
harness commit, and a link to Method.

## Should

**S1. History end labels detach from their lines.** Plutigo, Scalus CEK and uplc-turbo converge;
the labels are pushed apart without a connector. The Haskell baseline is dashed, the same code as
experimental. Fix: leader lines from the pushed label to the line end; the baseline a solid,
brighter hairline labelled "Haskell = 1×"; tooltip rows sorted with a line key.

**S2. Medal colours amplify small gaps.** Gold, silver and bronze borders and numbers on #1–#3
(1.00×, 1.11×, 1.34×) look like a podium; bronze and gold are close hues and silver is the text
colour. For a neutral page, use one subtle accent for #1 only and plain rank numbers (the 18 %
opacity rank is illegible).

**S3. Controls that do nothing.** The category filter has one chip ("Interpreters") when only one
category has ranked VMs; the overall cross-category ranking then repeats the cards. Hide both when
there is only one ranked category.

**S4. Section order.** The history chart comes before the geometric-mean chart, and the
experimental card sits between the ranking and the charts. Order: ranking, geometric-mean chart,
history, per-script table, experimental, execution model, toolchain, method. A failed-check list
stays right after the ranking (a trust signal).

**S5. The script count is hard-coded.** "89 scripts" is in `DISCLOSURE` (HTML and report.md) and
in the Method note. Fix: use the run's script count in both places.

**S6. The Aiken note makes its card twice as tall.** Fix: smaller, clamped note area below the
number, so the number stays at the same height in every card.

## Nice (not done)

- N1. Sortable per-script columns and an "eval only / decode + eval / both" column toggle.
- N2. A table view of the history (report.md has it), and keyboard focus for the tooltips.
- N3. Self-hosted fonts (the page loads Geologica and JetBrains Mono from Google Fonts; the task
  keeps the fonts as they are).
- N4. A light theme and a print style.
- N5. Anchor links on the section titles.
