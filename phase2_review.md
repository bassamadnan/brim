# Phase 2 Critical Review — Issues, Gaps, and Improvements

> Generated: 2026-04-22
> Scope: Full critical review of Phase 2 analysis for poster presentation preparation.

---

## Overall Verdict

The Phase 2 work is **methodologically competent** — GEE for clustered binary outcomes, log-RT modeling, Holm/BH correction within analysis families, robustness reruns, and diagnostic plots are all appropriate choices. However there are **3 technical bugs** in the code, **5 substantive analysis gaps** that were planned but never executed, **4 reporting/framing problems** that will hurt the poster, and **4 missing visualizations** that are essential for a poster-quality presentation.

---

## Section 1: Technical Bugs (Things That Are Wrong)

### Bug 1 — Primary RT Model Is a GEE, Not a Mixed Model (Misreported)

**Location:** `analysis/phase2_analysis.py:282-309`, `report/main_phase2.typ:93`, `report/tables_phase2/phase2_primary_rt_mixedlm.csv`

**What happened:** `mixed_rt_model()` tries `mixedlm` with two formula variants and silently falls back to a Gaussian GEE when both fail. The output CSV is named `phase2_primary_rt_mixedlm.csv` and the model_used column confirms it ran as `gee_gaussian`. The report mentions the fallback but then continues to call it a "mixed" model in surrounding text.

**Why it matters:** Presenting a GEE as a mixed effects model is a factual error. GEE and LMM have different estimands (population-average vs subject-specific) and different assumptions. An examiner will ask directly which model was run.

**What needs fixing:** Rename the output file, fix the report language to clearly state "Gaussian GEE" was the final RT model throughout, and add a one-sentence justification for why the LMM was singular (likely too many random effects relative to cluster size).

---

### Bug 2 — "Foil" Category Leaks Into All GEE Models Producing Degenerate Rows

**Location:** `analysis/phase2_analysis.py:70-72`, all GEE model output tables

**What happened:** `test_boundary_position` is encoded as a pandas Categorical with levels `["post", "mid", "pre", "foil"]` at load time. Even after filtering the working dataset to only include `post/mid/pre` rows, the "foil" level persists in the Categorical metadata. Statsmodels GEE then generates a dummy variable `C(test_boundary_position)[T.foil]` for the absent category, producing degenerate estimates:
- `phase2_primary_correctness_gee.csv:7` — foil row has coefficient ~0, NaN SE
- `phase2_primary_rt_mixedlm.csv:7` — foil row coefficient = 3.8e-17, p = 0.295
- `phase2_robustness_correctness_split.csv:7` — **foil row shows p = 0.002 for target split** — this is a numerical artifact being read as a significant result

**Why it matters:** These phantom rows contaminate every model output table. The p = 0.002 for a foil dummy in the target-split model could be misread as a real finding. Any reader examining the raw tables will see degenerate rows and question the entire analysis.

**What needs fixing:** After filtering to BOUNDARY_ORDER rows, recast the Categorical to drop the "foil" level:
```python
working["test_boundary_position"] = working["test_boundary_position"].cat.remove_unused_categories()
```
Apply this in `gee_correctness_model()`, `mixed_rt_model()`, `response_profile_tests()`, `lure_bin_gee()`, and `robustness_reruns()`.

---

### Bug 3 — lure_bin_c Included in Combined Target+Lure GEE (Ambiguous Specification)

**Location:** `analysis/phase2_analysis.py:217-221`, `report/tables_phase2/phase2_primary_correctness_gee.csv`

**What happened:** The combined correctness GEE includes `lure_bin_c` as a predictor over target+lure trials. Lure bin describes how visually similar a lure is to its target — its meaning for target trials is fundamentally different (a target is the exact same image, not a graded similarity). If target trials have NaN lure_bin, GEE does listwise deletion and target rows are silently dropped, making the "combined" model effectively a lure-only model with a spurious item_role comparison. If targets have a bin value (e.g., bin=1 or bin=0), the predictor mixes two different constructs across item roles.

**Why it matters:** Either the item_role coefficient in the combined GEE is estimated without proper target data, or lure_bin_c is measuring something different for targets vs lures. The cleaner version of this result already exists in the robustness split — the lure-only GEE (`phase2_robustness_correctness_split.csv:28`) shows lure_bin_c OR = 1.192, p < 0.001, which is the unambiguous finding.

**What needs fixing:** Remove `lure_bin_c` from the combined model formula. Run the primary correctness GEE without it (condition × boundary + item_role + stimulus_class), and report the lure_bin effect from the dedicated lure-specific model which is already computed and correct.

---

## Section 2: Analysis Gaps (Planned But Not Done)

### Gap 1 — Encoding RT → Test Accuracy Carry-Over Analysis (Highest Priority Missing Analysis)

**Planned in:** `plan.md:36-37` (encoding_rt listed as a planned predictor)

**What it is:** Join `encoding_trials.csv` and `test_trials.csv` on stimulus identity. For each test trial, attach the encoding RT from when that item was studied. Then model whether higher encoding RT for an item predicts worse test-phase correctness for that same item, over and above boundary position.

**Why it matters:** Phase 1 shows encoding RT spikes at post-boundary. Phase 2 shows test correctness drops at post-boundary. But these are currently two *separate* observations on different trials — they do not establish that the RT spike is the mechanism. Trial-level linking would make this a genuine mediation question and is the most scientifically interesting analysis in the dataset.

**What to add:** A logistic GEE with `correct_int ~ encoding_rt + test_boundary_position + condition + item_role` on the merged trial-level dataset. Also a scatter plot of participant-mean encoding RT vs participant-mean test correctness.

---

### Gap 2 — Participant-Level Heterogeneity Not Analysed

**Planned in:** `plan.md:113-115` ("identify responder subgroups; test whether subgrouping is associated with condition or baseline performance")

**What it is:** For each participant, compute the post-mid boundary contrast for target correctness. Plot the distribution of these individual contrasts. Identify what fraction of participants show a boundary cost vs no effect vs reversed effect.

**Why it matters:** A model coefficient says the average effect is negative. A heterogeneity plot shows whether this is a consistent pattern across people or driven by a minority. For a poster, a histogram of individual boundary contrasts is far more compelling than a model table — it shows the phenomenon is real at the person level.

**What to add:** Histogram of per-participant (post_correct − mid_correct) for target trials, faceted by condition. Overlay mean and 95% CI. Flag participants with strong vs weak boundary costs.

---

### Gap 3 — Stimulus Class × Boundary Interaction Not Tested

**Location:** Not implemented anywhere in `phase2_analysis.py`

**What it is:** Objects and Scenes show a very large performance gap (Scenes vs Objects OR = 0.66, p < 0.001 — one of the biggest effects in the whole dataset). The model should test whether boundary effects differ by stimulus class.

**Why it matters:** If boundary effects only appear for one stimulus type, that significantly refines the theoretical interpretation. If they're uniform, that strengthens the boundary effect claim.

**What to add:** Add `stimulus_class × test_boundary_position` interaction to the correctness GEE. Report whether the interaction is significant.

---

### Gap 4 — Speed-Accuracy by Boundary Position Not Computed

**Planned in:** `plan.md:107-109` ("compare RT among correct vs incorrect by boundary/condition")

**What it is:** The current `speed_accuracy_summary()` collapses across boundary positions. The interesting question is: at post-boundary, are incorrect responses disproportionately slower than at mid-boundary? This would show whether post-boundary items cause a deliberative slowdown specifically on failed trials.

**What to add:** Extend the speed-accuracy summary to include `test_boundary_position` as a grouping variable. Plot mean correct RT and mean incorrect RT as a function of boundary position (for target trials, in the `both` condition).

---

### Gap 5 — REC/LDI Bridge Between Phase 1 and Phase 2 Never Implemented

**Location:** `report/main_phase2.typ:88-90` (mentions REC/LDI "for continuity" but they are never computed or shown in Phase 2)

**What it is:** Phase 2 claims to carry REC and LDI as bridge metrics to Phase 1 but the Phase 2 code never generates updated REC/LDI figures or tables. The participant_level_metrics.csv contains these values but they are only used for the encoding_task_accuracy covariate.

**What to add:** A side-by-side figure: left panel = Phase 1 REC by boundary (existing figure), right panel = Phase 2 correctness (target trials) by boundary. This makes the "Phase 2 confirms Phase 1" story immediately visible.

---

## Section 3: Reporting and Framing Problems

### Problem 1 — Strongest Finding Is Buried in the Robustness Section

**Location:** `report/main_phase2.typ:167-174`

The clearest, most confident result in Phase 2 is the Friedman test (χ²(2) = 11.47, p = 0.003, Kendall's W = 0.117) combined with the Holm-corrected post-mid contrast for `both` condition targets (t = -3.34, p_holm = 0.020). This is the direct confirmatory evidence for the post-boundary recognition cost. It is reported under "Robustness analyses" as if it were a sensitivity check rather than the primary result.

**Fix:** Restructure the results section. The Friedman + post-mid contrast should be the lead finding under "Primary Results." The GEE model should be described as "consistent with but attenuated compared to" this direct test.

---

### Problem 2 — Report Leads With the Weakest Finding

**Location:** `report/main_phase2.typ:124-132`

The first result reported is "broad boundary-position main effects were not the dominant signal after adjustment." This is technically accurate but is the most hedged, least informative statement in the paper. A poster reader who sees this first will mentally file the project as "we found nothing."

**Fix:** Lead with what WAS found: task-rule boundaries caused a post-boundary recognition cost, confirmed at both the participant-level (Phase 1 ANOVA, Phase 2 Friedman) and trial level (GEE contrast). Then note that this effect is conditional on condition and co-occurs with strong stimulus-structure effects.

---

### Problem 3 — Non-Replication of LDI Advantage Not Framed as a Positive Finding

**Location:** `report/main_phase2.typ:164-165`, `report/main.typ:153-156`

The failure to replicate the Morse et al. (2023) pre-boundary LDI advantage is mentioned but treated as a negative. A well-framed null result — "our larger sample (N=158) with three boundary types finds no evidence for the LDI advantage" — is actually a scientifically valuable contribution.

**Fix:** Add a short paragraph explicitly discussing this as a potential non-replication finding with sample and design context. Report a Bayes Factor or equivalence test result if possible to characterize the strength of the null.

---

### Problem 4 — Effect Sizes Are Missing or Inconsistently Reported for Key Results

**Location:** Throughout `report/main_phase2.typ`

The RT model reports `exp(β)` (ratio change) but no standardized effect size. The boundary contrasts in robustness section report t-values but no Cohen's d. The Friedman test reports Kendall's W. There is no consistent effect-size framework across models.

**Fix:** For the post-mid contrast in the `both` condition targets, compute and report Cohen's d (d = t / sqrt(n)). For the GEE correctness model, report OR with 95% CI as the primary effect metric. Create a single "effect sizes" summary table.

---

## Section 4: Missing Visualizations for the Poster

### Missing Figure 1 — Target Correctness by Boundary, Separated by Condition

The existing `phase2_correctness_boundary_condition.png` collapses target and lure trials together. A poster needs to show target correctness (%) separately by boundary and condition, with participant-level data points overlaid. This is the direct visual representation of the post-boundary recognition cost.

---

### Missing Figure 2 — Within-Participant Post-Mid Contrast Distribution

For the `both` condition, a histogram or raincloud plot of individual participant (post − mid) target correctness values, showing where zero falls relative to the distribution. This makes the boundary effect compelling at the person level.

---

### Missing Figure 3 — Phase 1 REC vs Phase 2 Correctness Side-by-Side

A two-panel figure showing the same story told by two different methods: Phase 1 REC by boundary (existing) and Phase 2 target correctness by boundary (new). Demonstrates that confirmatory Phase 2 replicates the exploratory Phase 1 finding.

---

### Missing Figure 4 — Encoding RT → Test Correctness Scatter

Scatter plot of participant-mean encoding RT for post-boundary items vs participant-mean target correctness for post-boundary items, coloured by condition. If there is a negative correlation, this is the strongest single figure in the project — it links the encoding disruption to the memory cost at the participant level.

---

## Section 5: Results Summary for Poster — What to Lead With

The correct order of findings by strength for a poster:

| Priority | Finding | Key Statistic | Interpretation |
|---|---|---|---|
| 1 | Task-rule boundaries slow encoding dramatically | F(2,96) = 68.36, p < .001 (`both`); F(2,104) = 60.21 (`task_only`); F(2,110) = 2.22, p = .11 (`item_only`) | The item content shift alone does nothing; the task-rule shift is the driver |
| 2 | Post-boundary target recognition cost confirmed | Friedman χ²(2) = 11.47, p = .003, W = 0.117; post-mid t = -3.34, d ≈ 0.48, Holm p = .020 (both condition) | Phase 2 confirms Phase 1 ANOVA finding with nonparametric test |
| 3 | Lure difficulty dominates correctness once modeled | lure_bin_c OR = 1.086 per bin step, p < .001 | Internal task validity confirmed; MST difficulty gradient works |
| 4 | Correct responses faster than incorrect | exp(β) = 0.922, p < .001 | Normal speed-accuracy coupling; task was engaged |
| 5 | No pre-boundary LDI advantage (non-replication) | All conditions p > .25 for LDI boundary effect | Morse et al. (2023) LDI advantage not replicated across all boundary types |

---

## Section 6: What Is Already Good (Do Not Change)

- GEE with exchangeable working correlation for clustered binary outcomes — correct choice
- Holm + BH/FDR corrections within pre-specified analysis families — correct
- QC pipeline (missingness checks, RT artifact flags, Shapiro-Wilk on participant mean log RT) — comprehensive
- Precision context table (CI half-widths by condition) — genuinely useful, most students don't do this
- Analysis registry — good methodological discipline
- Lure-bin GEE finding — clean, well-executed, unambiguous result
- Friedman nonparametric fallback — correct robustness move given non-normal residuals
- Robustness split by item role — the lure-only GEE is the correct way to handle lure_bin

---

## Quick Reference — All Issues by Category

| # | Category | Issue | Severity |
|---|---|---|---|
| B1 | Bug | RT model misreported as mixed model (it's a GEE) | High |
| B2 | Bug | Foil category leaks into GEE models, produces phantom significant rows | High |
| B3 | Bug | lure_bin_c in combined target+lure model is ambiguous / causes silent row drops | Medium |
| G1 | Gap | Encoding RT → test accuracy carry-over analysis not done | High |
| G2 | Gap | Participant-level heterogeneity not analysed | Medium |
| G3 | Gap | Stimulus class × boundary interaction not tested | Medium |
| G4 | Gap | Speed-accuracy by boundary position not computed | Low |
| G5 | Gap | REC/LDI bridge figure between Phase 1 and Phase 2 missing | Medium |
| R1 | Reporting | Strongest finding (Friedman + post-mid contrast) buried in robustness section | High |
| R2 | Reporting | Report leads with weakest finding | High |
| R3 | Reporting | LDI non-replication not framed as a scientific contribution | Medium |
| R4 | Reporting | Effect sizes inconsistent/missing across models | Medium |
| V1 | Visual | Target-only correctness by boundary figure missing | High |
| V2 | Visual | Within-participant contrast distribution figure missing | Medium |
| V3 | Visual | Phase 1 REC vs Phase 2 correctness side-by-side missing | Medium |
| V4 | Visual | Encoding RT → test correctness scatter missing | High |
