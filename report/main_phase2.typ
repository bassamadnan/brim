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
    In this phase, we moved from exploratory summaries to confirmatory modeling. We directly analyzed test-phase correctness, response-category behavior, and response speed, while retaining REC and LDI for continuity. The strongest pattern was that response structure depended more on item role and lure difficulty than on a broad boundary main effect.
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
      In this phase, we implemented confirmatory models centered on correctness and response speed.\
      We also tested additional variables beyond REC and LDI, including response-category structure and lure-bin effects.
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
Phase 1 established a clean, reproducible base and suggested a post-boundary cost for some memory outcomes. In Phase 2, our aim was stricter: test correctness and response speed directly at the test-trial level, include additional predictors, and enforce explicit correction for multiple testing.

This phase followed class guidance on variable-type aware testing, assumption checks, outlier diagnostics, and effect-size oriented reporting. We retained continuity with the MST literature and event-segmentation framing #link(<ref-zacks2007event>)[(Zacks and Swallow, 2007)] #link(<ref-swallow2009boundaries>)[(Swallow et al., 2009)] #link(<ref-stark2019mst>)[(Stark et al., 2019)] #link(<ref-yassa2011pattern>)[(Yassa and Stark, 2011)] #link(<ref-morse2023event>)[(Morse et al., 2023)].

== Phase 2 questions
1. Does boundary position affect test correctness (`correct` = 0/1) when modeled directly?
2. Does boundary position affect test response speed (`response_rt`) after accounting for item role and condition?
3. Do response-category patterns (`old/new/similar`) differ by boundary position?
4. Do lure-bin difficulty and stimulus class explain additional variance?
5. Do speed-accuracy summaries support meaningful differences between correct and incorrect responses?

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    inset: 6pt,
    stroke: (x, y) => if y == 0 { 0.8pt + rgb("#6c757d") } else { 0.3pt + rgb("#d9d9d9") },
    table.header([Condition], [Paired $n$], [Test trials per participant], [Total analyzed test trials]),
    [Item Shift Only], [56], [150], [8400],
    [Item + Task Shift], [49], [150], [7350],
    [Task Shift Only], [53], [150], [7950],
  ),
  caption: [Phase 2 sample overview derived from paired participants and test-trial data used in confirmatory modeling.],
)

= Methods
== Data and preprocessing
We reused the paired dataset from Phase 1 and operated primarily on test trials. Key analysis columns were correctness (`correct`), response label (`response_label`), response time (`response_rt`), condition, boundary position, item role, lure bin, and stimulus class.

Quality checks included missingness summaries, RT artifact flags, participant-level RT outlier checks, and normality diagnostics of participant mean log RT. We observed no missingness in core test-trial fields and only minimal missingness in a participant-level covariate (`encoding_task_accuracy`, 2 participants).

== Variables and measures
Phase 2 primary outcomes were:
1. Test correctness (`correct`)
2. Log-transformed response speed (log of `response_rt`)

Secondary outcomes were:
1. Response-category profile (`old/new/similar`)
2. Lure-specific similar-response probability as a function of lure bin
3. Speed-accuracy summary: mean correct RT, mean incorrect RT, and their difference

For continuity, REC and LDI remained available as bridge metrics:
$"REC" = P("old" \mid "Target") - P("old" \mid "Foil")$
$"LDI" = P("similar" \mid "Lure") - P("similar" \mid "Foil")$

== Statistical strategy
Primary correctness was modeled with clustered logistic GEE (participant-level clustering, exchangeable working correlation). Primary RT was modeled on log RT with participant-aware modeling; due singularity in the richest mixed specification, a robust Gaussian GEE fallback model was used and reported.

Secondary analyses included chi-square tests for response-category profile changes and a lure-bin GEE model for similar responses on lure trials. Multiple comparisons were corrected within analysis families using Holm, with BH/FDR also reported in outputs.

== Precision and power context
To make null and weak effects interpretable, we added a precision-context summary by condition. For proportion-like outcomes, the worst-case 95% CI half-width at $p=0.5$ was approximately 0.131 (`item_only`), 0.140 (`both`), and 0.135 (`task_only`). For participant-mean RT, 95% CI half-widths were approximately 0.308s (`item_only`), 0.240s (`both`), and 0.153s (`task_only`).

These values provide a practical interpretation layer: effects smaller than these ranges are harder to distinguish cleanly without larger samples, especially for proportion endpoints.

= Results
== Quality-control checks
Core test-phase variables had no missingness. RT artifact counts were low relative to dataset size (1 very fast trial < 0.2s; 23 very slow trials > 30s). Participant-level mean log RT departed from perfect normality (Shapiro-Wilk $W = 0.953$, $p < .001$), so robust model choices and fallback logic were retained.

Additional RT diagnostics using an OLS approximation for residual checks showed non-normal residual structure (Shapiro-Wilk $W = 0.949$, $p < .001$) and a weak absolute-residual versus fitted correlation (about 0.086), consistent with mild heteroscedasticity. This further justified reporting the robust clustered RT model and robustness reruns.

#figure(
  image("figures_phase2/phase2_diagnostic_logrt_hist.png", width: 100%),
  caption: [Diagnostic histogram of participant-level mean log RT used for distributional assessment.],
)

#figure(
  image("figures_phase2/phase2_diagnostic_qq_residuals.png", width: 100%),
  caption: [QQ plot of RT-model residuals (diagnostic approximation), showing departures from strict normality.],
)

#figure(
  image("figures_phase2/phase2_diagnostic_residuals_vs_fitted.png", width: 100%),
  caption: [Residual-versus-fitted diagnostic for RT model approximation, indicating only mild structure in residual spread.],
)

== Primary model 1: Correct/incorrect responses
In the confirmatory correctness model, broad boundary-position main effects were not the dominant signal after adjustment. Instead, correctness varied strongly with item role and stimulus structure.

Key coefficients (uncorrected model-level terms):
1. `lure` vs `target`: OR = 0.58, $p < .001$
2. `Scenes` vs `Objects`: OR = 0.66, $p < .001$
3. Lure-bin centered slope: OR = 1.09, $p < .001$
4. `both` vs `item_only`: OR = 0.80, $p = .021$

After Holm correction, the strongest retained terms were item role, stimulus class, and lure-bin effect.

#figure(
  image("figures_phase2/phase2_correctness_boundary_condition.png", width: 100%),
  caption: [Phase 2 correctness by boundary and condition. The boundary pattern is present descriptively but weaker than item-role and lure-difficulty effects in adjusted modeling.],
)

== Primary model 2: Response speed
For response speed, the final fitted primary model used the Gaussian GEE fallback on log RT. The major robust effects were:
1. Correct responses were faster than incorrect responses (exp(beta) = 0.922, $p < .001$).
2. Lure trials were slower than target trials (exp(beta) = 1.105, $p < .001$).
3. Task Shift Only condition showed faster RT than Item Shift Only in adjusted comparison (exp(beta) = 0.880, $p = .013$).

Boundary main effects were not the strongest adjusted terms.

#figure(
  image("figures_phase2/phase2_test_rt_violin.png", width: 100%),
  caption: [Phase 2 response-time distributions by boundary and condition. Distribution-aware plots were used instead of mean-only summaries.],
)

== Secondary analyses beyond REC and LDI
Response-category structure (chi-square tests) showed a significant boundary-linked shift only for target trials in the Item + Task Shift condition: chi-square(4) = 22.55, $p < .001$, Cramer's V = 0.062.

In the lure-focused model, similar-response probability increased with lure-bin level (OR = 1.17, $p < .001$), indicating stronger discrimination as lure similarity reduced. Scene stimuli showed lower similar-response probability than objects (OR = 0.68, $p < .001$).

The speed-accuracy summary also showed a consistent pattern: incorrect responses were slower on average than correct responses (overall mean difference about 0.278 s).

#figure(
  image("figures_phase2/phase2_lure_bin_slopes.png", width: 100%),
  caption: [Phase 2 lure-bin slopes by boundary position. Similar-response probability increases with lure bin, indicating expected MST difficulty behavior.],
)

== Integrative interpretation
Phase 2 did not show a dominant omnibus boundary main effect across all adjusted models. Instead, the main robust structure came from item role, stimulus class, lure difficulty, and speed-accuracy coupling. This sharpens Phase 1 interpretation: boundary effects are present but conditional, and should be interpreted alongside stimulus and response-process variables rather than in isolation.

== Robustness analyses
The high-impact robustness package was added in three parts.

1. *Outlier-trimmed RT rerun:* Excluding participant-level RT outliers did not materially change the RT story. Correct responses remained faster than incorrect responses, and lure trials remained slower than target trials.
2. *Split correctness models:* Modeling target and lure correctness separately preserved key patterns. For lure trials, lure-bin and stimulus-class effects remained strong. For target trials, the strongest adjusted effects remained condition/stimulus dependent rather than a uniform boundary main effect.
3. *Focused boundary contrasts:* In corrected contrast testing, the clearest retained boundary effect was in Item + Task Shift target trials for post-minus-mid correctness (Holm-corrected significance retained).

Overall, the confirmatory conclusions were stable under these robustness checks.

= Conclusion
Phase 2 achieved the confirmatory objectives and expanded coverage beyond REC and LDI by modeling correctness, response speed, and response categories directly.

Main takeaways:
1. Correctness and RT analyses are now trial-level and model-based.
2. Strongest robust effects are item-role and lure-difficulty related.
3. Speed-accuracy coupling is meaningful (incorrect responses slower on average).
4. Boundary-related effects appear context-dependent rather than uniformly dominant.

This phase completes the methodological progression from exploratory to confirmatory analysis while aligning with class expectations for assumptions, categorical testing, multiple-comparison control, and effect-size reporting.

#pagebreak()

= Codebase and contributions
The source code for this project is available at #link("https://github.com/ch-pavan/brim")[https://github.com/ch-pavan/brim].

This phase was completed collaboratively:
1. *Sambu Aneesh:* Framed confirmatory questions and statistical interpretation logic.
2. *Renu Sree Vyshnavi:* Led results interpretation and quality-control narrative.
3. *Pavan Harshit:* Implemented Phase 2 analysis pipeline, generated outputs, and integrated report assets.

#text(weight: "bold")[References]
#set par(leading: 0.38em)
#text(size: 7.5pt)[
[1] J. M. Zacks and K. M. Swallow, "Event Segmentation," *Current Directions in Psychological Science*, 16(2), 80-84, 2007. <ref-zacks2007event>\
[2] K. M. Swallow, J. M. Zacks, and R. A. Abrams, "Event Boundaries in Perception Affect Memory Encoding and Updating," *Journal of Experimental Psychology: General*, 138(2), 236-257, 2009. <ref-swallow2009boundaries>\
[3] S. M. Stark, C. B. Kirwan, and C. E. L. Stark, "Mnemonic Similarity Task: A Tool for Assessing Hippocampal Integrity," *Trends in Cognitive Sciences*, 2019. <ref-stark2019mst>\
[4] M. A. Yassa and C. E. L. Stark, "Pattern Separation in the Hippocampus," *Trends in Neurosciences*, 34(10), 515-525, 2011. <ref-yassa2011pattern>\
[5] S. J. Morse, A. B. Karagoz, and Z. M. Reagh, "Event Boundaries Directionally Influence Item-Level Recognition Memory," 2023. <ref-morse2023event>
]
