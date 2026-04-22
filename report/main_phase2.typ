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
    In Phase 2 we moved from the exploratory summaries of Phase 1 to a more focused confirmatory analysis built only from class-aligned methods. The primary analyses were participant-level repeated-measures ANOVA, Friedman tests, and Holm-corrected paired t-tests; secondary analyses used chi-square tests for response profiles and Spearman correlations for lure-bin trends. The clearest result is a post-boundary target-recognition cost in the Item + Task Shift condition, confirmed by both repeated-measures ANOVA ($F(2,96) = 6.45$, $p$ = .002) and Friedman testing (#sym.chi$""^2$(2) = 11.47, $p$ = .003, Kendall's $W$ = 0.117). Holm-corrected pairwise tests showed that post-boundary target accuracy was lower than both mid-event ($d_z$ = −0.48, corrected $p$ = .005) and pre-boundary ($d_z$ = −0.36, corrected $p$ = .029) accuracy in that condition. Test-phase RT showed no reliable boundary-position effect after correction, while lure-bin summaries showed the expected increase in mnemonic discrimination as lures became less similar.
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

This phase therefore uses a simpler statistical strategy than the earlier advanced draft. The final version of Phase 2 relies on participant-level repeated-measures ANOVA, Friedman tests, Holm-corrected paired t-tests, chi-square tests, and Spearman correlations. This keeps the analysis aligned with class material on variable types, repeated-measures designs, nonparametric alternatives, multiple-comparison correction, and effect-size reporting. The theoretical framing remains the same: event segmentation #link(<ref-zacks2007event>)[(Zacks and Swallow, 2007)] #link(<ref-swallow2009boundaries>)[(Swallow et al., 2009)] and mnemonic similarity / pattern separation #link(<ref-stark2019mst>)[(Stark et al., 2019)] #link(<ref-yassa2011pattern>)[(Yassa and Stark, 2011)] with the Morse et al. replication target #link(<ref-morse2023event>)[(Morse et al., 2023)].

== Phase 2 research questions
1. Does boundary position affect target recognition accuracy at test?
2. Does boundary position affect test-phase response speed?
3. Do response-category profiles (`old/new/similar`) differ by boundary position?
4. Do lure bins behave as expected, such that less similar lures are easier to identify?
5. Which effects replicate Phase 1 and which do not?

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

== Integrative interpretation
Phase 2 sharpens the Phase 1 story in a simpler and more defensible way.

1. The strongest boundary-related memory effect is a post-boundary target-recognition cost in the Item + Task Shift condition.
2. That effect is visible with both repeated-measures ANOVA and Friedman testing, so it does not depend on one specific statistical framework.
3. Test-phase RT does not show a parallel boundary effect, which means the clearest RT disruption remains at encoding rather than retrieval.
4. Response-category analyses point in the same direction: only Item + Task Shift target trials show a clear boundary-linked shift.
5. Lure-bin trends behave as expected, supporting the validity of the task and of the extracted measures.

= Conclusion
Phase 2 is now aligned with the statistical toolkit taught in class and no longer depends on advanced clustered modeling. The project’s central confirmatory claim survives this simplification: when both the item stream and the task rule shift together, memory for post-boundary target items is worse than memory for mid-event and pre-boundary targets.

Main takeaways:
1. *Post-boundary recognition cost confirmed in Item + Task Shift:* $F(2,96) = 6.45$, $p$ = .002; Friedman $chi^2$(2) = 11.47, $p$ = .003, Kendall's $W$ = 0.117.
2. *Corrected pairwise contrasts support the same story:* post vs mid $d_z$ = −0.48, corrected $p$ = .005; post vs pre $d_z$ = −0.36, corrected $p$ = .029.
3. *Task Shift Only shows a weaker and less stable pattern:* ANOVA significant but Friedman non-significant, so this should be interpreted cautiously.
4. *No reliable test-phase RT boundary effect:* all Friedman tests non-significant and no Holm-corrected pairwise contrast survived.
5. *Lure-bin behaviour is valid:* discrimination improves as lures become less similar, which is consistent with MST expectations.

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
