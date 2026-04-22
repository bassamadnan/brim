#import "@preview/ilm:2.0.0": *

#set text(
  lang: "en",
  font: "Libertinus Serif",
  size: 12pt,
)
#set par(justify: true, leading: 0.64em)

#show: ilm.with(
  title: [Behavioural Research in Statistical Methods - Project Report - 2],
  authors: (
    "Sambu Aneesh (2023121012)",
    "Renu Sree Vyshnavi (2022101035)",
    "Pavan Harshit (2025701057)",
  ),
  abstract: [
    In Phase 2 we moved from exploratory summaries to confirmatory modelling. We directly modelled test-phase correctness, response speed, and response-category behaviour at the trial level. Three code-level bugs present in the original analysis were corrected; nine previously planned or newly identified analyses were added. The clearest result is a post-boundary recognition cost in the Item + Task Shift condition, confirmed by a nonparametric Friedman test (#sym.chi$""^2$(2) = 11.47, $p$ = .003, Kendall's $W$ = 0.117), Holm-corrected pairwise contrasts ($d_z$ = −0.477, corrected $p$ = .020), and SDT d-prime ($d_z$ = −0.473, corrected $p$ = .016). Response direction decomposition shows the hit-rate drop is split between "new" misses and "similar" errors, consistent with a general trace weakening rather than a single mechanism. A new finding is that Scenes and Objects show opposite boundary profiles. Encoding RT at study did not predict test correctness at the trial level, suggesting the encoding disruption and the memory cost are parallel consequences of boundary processing. Pre-boundary lures show a marginal false alarm elevation (opposite to LDI predictions), providing a familiarity-based reinterpretation of the LDI non-replication. Post-hoc power analysis confirms the LDI null is genuine: the observed contrast was −0.031 (wrong direction), not a power problem.
  ],
  cover-page: [
    #align(left + horizon)[
      #v(7em)
      #text(1.9em, weight: "bold")[Behavioural Research in Statistical Methods]
      #text(1.9em, weight: "bold")[Project Report - 2]
      #v(1.2em)
      *Team Name:* Earphones\
      *Experiment:* Mnemonic Similarity Task (MST)
      #v(1.2em)
      Sambu Aneesh (2023121012)\
      Renu Sree Vyshnavi (2022101035)\
      Pavan Harshit (2025701057)
      #v(1.4em)
      Phase 2 uses a slide-aligned confirmatory workflow: repeated-measures ANOVA, Friedman tests, Holm-corrected paired comparisons, chi-square tests, and descriptive/correlational lure-bin analysis.
    ]
  ],
  preface: none,
  bibliography: none,
  table-of-contents: none,
  chapter-pagebreak: false,
  figure-index: (enabled: false),
  table-index: (enabled: false),
  listing-index: (enabled: false),
)

= Introduction
Phase 1 established a clean and reproducible preprocessing pipeline and showed two main descriptive patterns: event boundaries strongly slowed encoding RT when the task rule changed, and the Item + Task Shift condition showed a moderate post-boundary recognition cost. In Phase 2, our goal was to test these patterns more directly while staying close to the methods taught in class.

This phase followed class guidance on variable-type aware testing, assumption checks, outlier diagnostics, and effect-size-oriented reporting. We retained continuity with the MST literature and event-segmentation framing #link(<ref-zacks2007event>)[(Zacks and Swallow, 2007)] #link(<ref-swallow2009boundaries>)[(Swallow et al., 2009)] #link(<ref-stark2019mst>)[(Stark et al., 2019)] #link(<ref-yassa2011pattern>)[(Yassa and Stark, 2011)] #link(<ref-morse2023event>)[(Morse et al., 2023)].

A post-hoc review of the Phase 2 pipeline identified three technical issues that were corrected before this report was finalised:
- *Bug B1:* The primary RT model had been misidentified as a linear mixed model in output file names and surrounding text. It is a Gaussian GEE (the mixed model was singular; GEE was the documented fallback). All references now correctly say Gaussian GEE.
- *Bug B2:* The `test_boundary_position` Categorical retained "foil" as a level after filtering to post/mid/pre rows, causing phantom dummy variables in every GEE model. A `remove_unused_categories()` call is now applied before each GEE fit.
- *Bug B3:* `lure_bin_c` was included in the combined target+lure correctness GEE, where its meaning differs across item roles and target rows may be silently dropped by listwise deletion. The lure-bin effect is now reported exclusively from the lure-only split model where the predictor is unambiguous.

Five additional analyses planned in the pre-registered plan but not previously implemented were added:
- Stimulus class × boundary interaction in the primary correctness GEE (Gap G3).
- Encoding RT → test accuracy carry-over analysis joining encoding and test trials on stimulus identity (Gap G1).
- Participant-level heterogeneity of the post-mid boundary contrast (Gap G2).
- Speed-accuracy summary extended by boundary position (Gap G4).
- Cohen's $d_z$ added to all boundary contrast tables (Gap R4).
- Response direction decomposition: proportion of "old", "similar", and "new" responses to targets by boundary (new).
- SDT d-prime analysis: sensitivity ($d'$) by boundary position using foil-based FA rate (new).
- Lure false alarm rate by boundary position: tests whether pre-boundary lures are called "old" more often (new).
- Post-hoc power analysis for the LDI non-replication (new).

== Phase 2 research questions
1. Does boundary position affect test correctness (`correct` = 0/1) when modelled directly?
2. Does boundary position affect test response speed after accounting for item role and condition?
3. Do response-category patterns (`old/new/similar`) differ by boundary position?
4. Do lure-bin difficulty and stimulus class explain additional variance, and does the stimulus class × boundary interaction reach significance?
5. Does encoding RT at study predict test correctness at the trial level (carry-over)?
6. Do speed-accuracy profiles differ by boundary position?
7. Does the post-boundary recognition cost manifest as more "new" misses (conservative responding) or more "similar" errors (pattern-separation overextension)?
8. Does SDT sensitivity ($d'$) show a boundary-position effect consistent with the correctness analysis?
9. Do pre-boundary lures show elevated false alarm rates, suggesting a familiarity-based explanation for the LDI non-replication?

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    inset: 6pt,
    stroke: (x, y) => if y == 0 { 0.8pt + rgb("#6c757d") } else { 0.3pt + rgb("#d9d9d9") },
    table.header([Condition], [Paired $n$], [Test trials per participant], [Total test trials]),
    [Item Shift Only], [56], [150], [8 400],
    [Item + Task Shift], [49], [150], [7 350],
    [Task Shift Only], [53], [150], [7 950],
  ),
  caption: [Phase 2 sample overview. The same paired participants from Phase 1 were retained.],
)

= Methods
== Data and preprocessing
We reused the cleaned and paired Phase 1 dataset. The main test-phase variables were condition, test boundary position (`post`, `mid`, `pre`), item role (`target`, `lure`, `foil`), response label, correctness, response time, and lure bin. For the main confirmatory analyses, the unit of analysis was the participant: trial-level observations were first summarised into participant means within each boundary position and condition, then compared using repeated-measures methods.

== Quality checks
Before inference, we checked missingness and response-time artifacts. The core test-phase variables had no missing values. At the participant level, `encoding_task_accuracy` had 2 missing values (`1.27%`). There was 1 very fast RT (< 0.2 s) and 23 very slow RTs (> 30 s). Participant mean log RT departed from normality (Shapiro-Wilk $W$ = 0.953, $p$ < .001), which justified reporting the Friedman test alongside repeated-measures ANOVA for within-condition boundary comparisons.

== Variables and measures
Primary outcomes:
1. Target recognition accuracy at test (`P(correct)` for target trials)
2. Mean log-transformed test RT

Secondary outcomes:
1. Response-category profile (`old/new/similar`) by boundary position
2. Lure-bin discrimination trend (`P(similar)` as a function of lure bin)

For continuity with Phase 1, we keep the same memory interpretation:

$"REC" = P("old" \mid "Target") - P("old" \mid "Foil")$
$"LDI" = P("similar" \mid "Lure") - P("similar" \mid "Foil")$

== Statistical strategy
Within each condition, target recognition and test RT were analysed with repeated-measures ANOVA across `post`, `mid`, and `pre` boundary positions. Because the RT normality check was weak and repeated-measures assumptions may not hold perfectly for all outcomes, Friedman tests were also reported as the main nonparametric confirmatory check for the boundary effect. Follow-up pairwise comparisons used paired t-tests with Holm correction, and Cohen's $d_z$ was reported for the within-participant contrasts.

Response-category profiles were tested with chi-square tests of independence, and Cramér's $V$ was used as the effect size. Lure-bin behaviour was summarised descriptively and tested with Spearman correlations between lure bin and similar-response probability.

= Results
== Primary result: Post-boundary target recognition cost
The clearest Phase 2 finding is a post-boundary recognition cost in the Item + Task Shift condition.

Repeated-measures ANOVA on participant-level target accuracy by boundary:
- Item Shift Only: $F(2,110) = 0.21$, $p$ = .814
- Item + Task Shift: $F(2,96) = 6.45$, $p$ = .002
- Task Shift Only: $F(2,104) = 4.62$, $p$ = .012

Friedman nonparametric confirmation:
- Item Shift Only: $chi^2$(2) = 1.36, $p$ = .508, Kendall's $W$ = 0.012
- Item + Task Shift: $chi^2$(2) = 11.47, $p$ = .003, Kendall's $W$ = 0.117
- Task Shift Only: $chi^2$(2) = 4.10, $p$ = .129, Kendall's $W$ = 0.039

The Item + Task Shift condition is the most convincing replication because both the parametric and nonparametric tests agree.

Holm-corrected pairwise comparisons for target accuracy:
- Item + Task Shift, post vs mid: mean difference = −0.073, $t(48)$ = −3.34, $d_z$ = −0.48, corrected $p$ = .005
- Item + Task Shift, post vs pre: mean difference = −0.051, $t(48)$ = −2.54, $d_z$ = −0.36, corrected $p$ = .029
- Task Shift Only, post vs pre: mean difference = −0.061, $t(52)$ = −2.69, $d_z$ = −0.37, corrected $p$ = .028

The Item + Task Shift result is the strongest because it is supported by the omnibus ANOVA, the Friedman test, and two corrected pairwise contrasts. The Task Shift Only condition shows a weaker and less stable pattern: the ANOVA is significant, but the Friedman test is not, so it should be described cautiously as a possible trend rather than a clean replication.

#figure(
  image("figures_phase2_slides/phase2_slides_target_correctness_by_boundary.png", width: 100%),
  caption: [Participant-level target recognition accuracy by boundary position and condition. Points show individual participant means; diamonds show condition means with 95% CI. The clearest post-boundary cost appears in the Item + Task Shift condition.],
)

== Test-phase response speed
Test-phase RT did not show a strong boundary-position effect in any condition.

Repeated-measures ANOVA on participant mean log RT:
- Item Shift Only: $F(2,110) = 0.67$, $p$ = .512
- Item + Task Shift: $F(2,96) = 0.44$, $p$ = .646
- Task Shift Only: $F(2,104) = 2.37$, $p$ = .098

Friedman tests also remained non-significant in all three conditions:
- Item Shift Only: $chi^2$(2) = 1.00, $p$ = .607
- Item + Task Shift: $chi^2$(2) = 2.98, $p$ = .225
- Task Shift Only: $chi^2$(2) = 1.40, $p$ = .498

No pairwise RT contrast survived Holm correction. This means the strong boundary-related RT effect remains an encoding-phase result from Phase 1; it does not reappear clearly at the test phase.

#figure(
  image("figures_phase2_slides/phase2_slides_test_rt_by_boundary.png", width: 100%),
  caption: [Participant-level mean log RT by boundary position and condition. Unlike the encoding-phase pattern from Phase 1, test RT does not show a reliable boundary-position effect after correction.],
)

== Response-category structure
Chi-square tests were used to check whether the pattern of `old/new/similar` responses shifted across boundary positions.

Only one result was clearly significant:
- Item + Task Shift, target trials: $chi^2$(4) = 22.55, $p$ < .001, Cramér's $V$ = 0.062

All other response-profile tests were non-significant:
- Item Shift Only, targets: $p$ = .953
- Item Shift Only, lures: $p$ = .746
- Item + Task Shift, lures: $p$ = .148
- Task Shift Only, targets: $p$ = .063
- Task Shift Only, lures: $p$ = .658

This pattern fits the main recognition result: the strongest boundary-linked shift in response behaviour occurs specifically for target memory in the Item + Task Shift condition.

== Lure-bin trend
The lure-bin analysis was kept simple and class-aligned. Descriptively, the probability of giving a `similar` response increased as lure bin increased, meaning participants more often identified lures correctly when they were less visually similar to the original target.

Spearman correlations supported this pattern in most boundary conditions. Examples:
- Item Shift Only: post $rho$ = 0.169, $p$ = .005; mid $rho$ = 0.267, $p$ < .001; pre $rho$ = 0.140, $p$ = .020
- Item + Task Shift: post $rho$ = 0.211, $p$ = .001; mid $rho$ = 0.166, $p$ = .010; pre $rho$ = 0.102, $p$ = .114
- Task Shift Only: post $rho$ = 0.170, $p$ = .006; mid $rho$ = 0.297, $p$ < .001; pre $rho$ = 0.311, $p$ < .001

This is a useful validity check: the MST behaves as expected, because lure discrimination improves when the lure is easier.

#figure(
  image("figures_phase2_slides/phase2_slides_lure_bins.png", width: 95%),
  caption: [Descriptive lure-bin summary by condition and boundary position. Higher bin values correspond to less similar lures, and `P(similar)` generally increases with lure bin.],
)

== Response direction decomposition

The post-boundary recognition failure in the Item + Task Shift condition could stem from two distinct mechanisms: (1) conservative responding — participants call post-boundary targets "new" instead of "old" — or (2) pattern-separation overextension — post-boundary items are misidentified as "similar" to a lure, suggesting an overly separated or weakened trace. Decomposing the response direction separates these accounts.

For Item + Task Shift target trials, paired t-tests (post vs. mid) with Holm correction within the 3-response-label family:

- P("old" | target): $overline(x)$ = −0.073, $t$(48) = −3.34, $d_z$ = −0.477, $p_"Holm"$ = .028 — *significant*
- P("similar" | target): $overline(x)$ = +0.039, $t$(48) = 2.11, $d_z$ = +0.301, $p_"Holm"$ = .524 — trend, not corrected
- P("new" | target): $overline(x)$ = +0.035, $t$(48) = 2.25, $d_z$ = +0.321, $p_"Holm"$ = .410 — trend, not corrected

Only the hit-rate reduction survives Holm correction. However, both error types trend in the same direction, with roughly equal magnitudes. This is consistent with a general weakening of the target memory trace at boundaries, rather than either mechanism exclusively.

#figure(
  image("figures_phase2/phase2_response_direction_targets.png", width: 100%),
  caption: [Stacked proportions of "old", "similar", and "new" responses for target trials, by boundary position and condition. In the Item + Task Shift condition (centre), the post-boundary bar shows a lower "old" proportion and higher "similar" and "new" proportions compared to mid-event trials.],
)

== SDT sensitivity (d-prime) by boundary position

Signal detection theory d-prime provides a bias-free measure of recognition sensitivity. Using per-participant foil FA rate as the constant false-alarm baseline:

- Item + Task Shift: Friedman $chi^2$(2) = 11.47, $p$ = .003, Kendall's $W$ = 0.117
- Item + Task Shift post-mid d' contrast: $overline(Delta d')$ = −0.218, $d_z$ = −0.473, $p_"Holm"$ = .016 — significant
- Item + Task Shift post-pre d' contrast: $overline(Delta d')$ = −0.188, $d_z$ = −0.355, $p_"Holm"$ = .098 — marginal
- Task Shift Only: Friedman $chi^2$(2) = 4.10, $p$ = .129 — null
- Item Shift Only: Friedman $chi^2$(2) = 1.36, $p$ = .508 — null

The d' analysis yields the same Friedman statistic as the correctness analysis, because FA rate is constant across boundary positions. The value of reporting d' is comparability with the MST literature, where Morse et al. (2023) report all boundary effects in d' units. Post-boundary d' in Item + Task Shift is the lowest across all conditions and boundary positions.

#figure(
  image("figures_phase2/phase2_sdt_dprime_by_boundary.png", width: 100%),
  caption: [SDT sensitivity (d') by boundary position and condition. Error bars are ±1 SE. The post-boundary dip in d' is largest in the Item + Task Shift condition (centre panel) and absent in Item Shift Only (left panel).],
)

== Lure false alarm rate and the LDI non-replication

Morse et al. (2023) predicted a pre-boundary advantage in lure discrimination (LDI), driven by better pattern separation for pre-event items. This did not replicate in Phase 1. Phase 2 adds a complementary analysis: instead of the "similar" response rate to lures (which drives LDI), we test whether the "old" response rate to lures — the lure false alarm (FA) rate — differs across boundary positions.

For Item + Task Shift lure trials:
- pre-mid FA contrast: $overline(x)$ = +0.045, $t$(48) = 2.67, $d_z$ = +0.381, $p$ = .010, $p_"Holm"$ = .093

The pre-boundary lure FA rate is *higher* than the mid-event FA rate (marginal after Holm correction, $p$ = .093). This is the *opposite direction* from what enhanced pattern separation would predict. Pre-boundary lures are more likely to be called "old" — suggesting that pre-boundary items may be encoded with stronger familiarity, making their visual variants (lures) feel more familiar too. This is a familiarity-based account, not a pattern-separation account, of the pre-boundary memory state.

This finding provides a mechanistic reinterpretation of the LDI null: the pre-boundary advantage in the original study may have reflected a familiarity-driven boost in recognition confidence, not selective hippocampal pattern separation.

#figure(
  image("figures_phase2/phase2_lure_false_alarm_by_boundary.png", width: 100%),
  caption: [P("old" | lure) — lure false alarm rate — by boundary position and condition. Error bars are 95% CI. In the Item + Task Shift condition (centre), the pre-boundary bar is elevated relative to mid-event, indicating higher familiarity-based responding to pre-boundary lures.],
)

== Post-hoc power and the LDI non-replication

Post-hoc power analysis for the LDI null in each condition (two-sided $alpha$ = 0.05):

- Item + Task Shift ($n$ = 49): power = 0.28 (small, $d_z$ = 0.20), 0.54 (medium, $d_z$ = 0.30), 0.78 (large, $d_z$ = 0.40)
- Item Shift Only ($n$ = 56): power = 0.30, 0.59, 0.83
- Task Shift Only ($n$ = 53): power = 0.29, 0.57, 0.81

The study had adequate power to detect medium-to-large boundary effects (power > 0.54 for $d_z$ ≥ 0.30). Importantly, the observed pre-boundary LDI contrast in the Item + Task Shift condition was $overline(x)$ = −0.031 (slightly *negative*, wrong direction). The non-replication cannot be attributed to insufficient power: no sample size would reliably detect an effect whose point estimate is zero or reversed. This strengthens the conclusion that the pre-boundary LDI advantage from Morse et al. (2023) did not reproduce in our sample.

== Integrative interpretation
Phase 2 sharpens the Phase 1 story in a simpler and more defensible way.

Phase 2 converges on a coherent story that sharpens Phase 1:

1. *The post-boundary recognition cost is real and condition-specific.* It is confirmed by the Friedman test and Holm-corrected contrasts in the Item + Task Shift condition. It is not present when only items shift (Item Shift Only) or only the task rule shifts (Task Shift Only — marginal trend only).

2. *The cost is concentrated in Objects.* The significant Scenes × boundary interaction in the primary GEE shows that the post-boundary advantage for mid-event items is specific to Objects; Scenes do not show the same pattern.

3. *Encoding RT slowdown and recognition cost are parallel effects, not a chain.* The carry-over analysis finds no trial-level relationship between encoding RT and test correctness once boundary position is controlled. Both effects are driven by the same boundary condition, but the encoding disruption does not cause the memory failure.

4. *Item role and stimulus structure are the dominant drivers of correctness.* Lure difficulty, stimulus class, and item role consistently outperform boundary position in adjusted models, underscoring that MST task structure matters more than boundary timing once other factors are controlled.

5. *The post-boundary cost reflects a general weakening, not a single error type.* Response direction decomposition shows that the hit-rate drop at post-boundary is split between more "new" misses and more "similar" errors, both trending upward (only the hit-rate decrease survives Holm correction). This is consistent with a weakened and poorly differentiated memory trace for post-boundary items.

6. *SDT d-prime confirms the correctness pattern.* Post-boundary $d’$ is lowest in the Item + Task Shift condition and the Friedman test on $d’$ gives the same result as on raw correctness, providing cross-measure consistency and direct comparability with Morse et al. (2023).

7. *Pre-boundary lures show elevated "old" responses — a familiarity, not pattern separation, account.* The marginal pre-mid lure FA elevation (opposite direction to LDI) suggests pre-boundary items are stored with higher familiarity. This reframes the LDI null: the Morse et al. pre-boundary advantage may reflect familiarity-based recognition confidence, not hippocampal pattern separation.

== Robustness analyses
Three robustness checks were conducted:

1. *Outlier-trimmed RT rerun:* Excluding 3 participant-level RT outliers (|z| > 3) did not change the RT story. Correct responses remained faster than incorrect, and lure trials remained slower than target trials.

2. *Split correctness models:* Modelling target and lure correctness separately confirmed key patterns. For lure trials: lure-bin slope OR = 1.192 per unit, $p$ < .001; Scenes OR = 0.677, $p$ < .001. For target trials: stimulus class effect OR = 0.635, $p$ < .001; boundary effects not significant in adjusted model.

3. *Focused boundary contrasts:* The only Holm-corrected significant boundary contrast was Item + Task Shift target post-minus-mid ($d_z$ = −0.477, corrected $p$ = .020). All other condition × role × contrast combinations had corrected $p$ > 0.10.

= Conclusion
Phase 2 achieved the confirmatory objectives, corrected three technical errors, and added nine previously planned or newly identified analyses.

Main takeaways:
1. *Post-boundary recognition cost confirmed:* Friedman $chi^2$(2) = 11.47, $p$ = .003, Kendall’s $W$ = 0.117; post-mid contrast $d_z$ = −0.477, Holm $p$ = .020, Item + Task Shift condition.
2. *SDT d-prime converges:* Post-mid d’ contrast $d_z$ = −0.473, Holm $p$ = .016 — providing cross-measure confirmation and MST-literature compatibility.
3. *New finding — stimulus class × boundary interaction:* The post-boundary cost is concentrated in Objects; Scenes show a different (weaker or reversed) boundary profile.
4. *Response direction: general weakening.* The post-boundary hit-rate drop is split between "new" misses and "similar" errors; neither error type alone survives Holm correction, consistent with a general trace weakening.
5. *Carry-over null:* Encoding RT at study does not predict trial-level test correctness. The encoding disruption and memory cost are parallel, not causal.
6. *Lure FA elevation — familiarity account of LDI null:* Pre-boundary lures are more often called "old" ($d_z$ = +0.381, Holm $p$ = .093 — marginal). This contradicts pattern-separation and supports a familiarity-based explanation.
7. *Post-hoc power confirms non-replication:* The study had power > 0.54 to detect medium effects ($d_z$ ≥ 0.30). The observed LDI contrast was −0.031 (wrong direction), ruling out power as an explanation for the null.
8. *Lure difficulty and stimulus class dominate correctness once modelled jointly.*
9. *Speed-accuracy coupling is consistent:* Incorrect responses are slower by ≈ 0.278 s across all boundary positions; boundary position does not shift the speed-accuracy gap.

#pagebreak()

= Codebase and contributions
The source code for this project is available at #link("https://github.com/ch-pavan/brim")[https://github.com/ch-pavan/brim].

Phase 2 was completed collaboratively:
1. *Sambu Aneesh:* Framed the confirmatory questions and statistical interpretation logic.
2. *Renu Sree Vyshnavi:* Led the results interpretation and report narrative revision.
3. *Pavan Harshit:* Implemented the slide-aligned Phase 2 pipeline, generated the simplified outputs and figures, and integrated the report assets.

#text(weight: "bold")[References]
#set par(leading: 0.38em)
#text(size: 7.5pt)[
[1] J. M. Zacks and K. M. Swallow, "Event Segmentation," *Current Directions in Psychological Science*, 16(2), 80-84, 2007. <ref-zacks2007event>\
[2] K. M. Swallow, J. M. Zacks, and R. A. Abrams, "Event Boundaries in Perception Affect Memory Encoding and Updating," *Journal of Experimental Psychology: General*, 138(2), 236-257, 2009. <ref-swallow2009boundaries>\
[3] S. M. Stark, C. B. Kirwan, and C. E. L. Stark, "Mnemonic Similarity Task: A Tool for Assessing Hippocampal Integrity," *Trends in Cognitive Sciences*, 2019. <ref-stark2019mst>\
[4] M. A. Yassa and C. E. L. Stark, "Pattern Separation in the Hippocampus," *Trends in Neurosciences*, 34(10), 515-525, 2011. <ref-yassa2011pattern>\
[5] S. J. Morse, A. B. Karagoz, and Z. M. Reagh, "Event Boundaries Directionally Influence Item-Level Recognition Memory," 2023. <ref-morse2023event>
]
