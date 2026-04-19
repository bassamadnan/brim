# Phase 2 Analysis Plan (BRSM Project)

## 1) Goal for Phase 2
Move from exploratory summaries to a confirmatory and well-documented analysis that directly tests:
- test-phase correctness (correct/incorrect)
- response patterns (old/new/similar)
- response speed (RT)
- effects of variables beyond only LDI and REC

Also align the full workflow with class-taught principles:
- explicit hypotheses before testing
- population/sample framing and inclusion logic
- assumption checks and parametric vs nonparametric choices
- effect-size-first reporting and corrected p-values
- avoidance of data dredging (no post-hoc hypothesis switching)

This plan follows class guidance on:
- choosing tests by variable type (categorical vs continuous)
- checking assumptions and outliers before inference
- controlling multiple comparisons
- reporting effect sizes with p-values

## 2) Core Research Questions
1. Does boundary position (post/mid/pre) affect test correctness?
2. Does boundary position affect test RT (response speed)?
3. Do condition effects differ across item_only, both, and task_only?
4. Do lure-bin difficulty and stimulus class (Objects/Scenes) explain additional variance?
5. Are findings robust when analyzed with methods suited to categorical outcomes?

## 3) Variables to Use in Phase 2

### 3.1 Outcomes (Dependent Variables)
- `correct` (binary: 0/1) on test trials
- `response_label` (categorical: old/new/similar)
- `response_rt` (continuous; test phase)
- `encoding_rt` (continuous; encoding phase, for carry-over checks)

### 3.2 Predictors (Independent Variables)
- `condition` (item_only, both, task_only)
- `test_boundary_position` (post, mid, pre; foil analyzed separately)
- `item_role` (target, lure, foil)
- `lure_bin` (1-5 for lure trials)
- `stimulus_class` (Objects, Scenes)
- `encoding_task_accuracy` (participant-level covariate)

### 3.3 Additional Derived Variables
- speed-accuracy metrics by participant and condition:
  - mean correct RT
  - mean incorrect RT
  - delta_RT_incorrect_minus_correct
- per-participant response bias profile:
  - P(old), P(similar), P(new) by item type and boundary
- boundary contrast variables:
  - post-minus-mid and pre-minus-mid for correctness and RT

## 4) Data Quality and Assumption Checks (Mandatory First)
1. Verify pairing and exclusions exactly as in Phase 1.
2. Document population and sample statement explicitly:
   - population of inference
   - observed sample and exclusions
   - whether inference is confirmatory or exploratory
2. Detect outliers:
   - participant-level RT outliers (IQR rule and z-score sensitivity)
   - implausible RT values at trial level (very fast/very slow)
3. Distribution checks for continuous outcomes:
   - histogram/QQ for RT and transformed RT
4. If normality/homoscedasticity are weak:
   - use robust/nonparametric alternatives from class guidance
5. Confirm no hidden missingness patterns by condition and boundary.
6. Check model assumptions explicitly:
   - residual diagnostics (for linear models)
   - influential-point diagnostics (Cook's distance style checks where applicable)
   - multicollinearity checks (VIF/correlation matrix) when using multi-predictor regressions

## 5) Statistical Analysis Strategy

## 5.1 Primary Confirmatory Analyses

### A. Test correctness (correct/incorrect)
Use categorical-outcome modeling as primary:
- trial-level logistic mixed model:
  - outcome: `correct`
  - fixed effects: `condition * test_boundary_position`, plus `item_role`
  - include `lure_bin` and `stimulus_class` where applicable
  - random intercept for participant

If mixed model is unstable, fallback:
- participant-level proportions + repeated-measures ANOVA (or Friedman if assumptions fail)

Categorical fallback (class-consistent):
- chi-square tests for contingency comparisons of response categories
- effect size with phi/Cramer's V for categorical tables

### B. Test response speed
- model `response_rt` (log-transform if skewed)
- fixed effects: `condition * test_boundary_position * item_role`
- add correctness term (`correct`) to test speed-accuracy coupling
- report post vs mid and pre vs mid contrasts

## 5.2 Secondary Analyses (Beyond LDI/REC)
1. Multinomial response analysis:
   - outcome: `response_label` (old/new/similar)
   - check if boundaries shift response strategy, not just accuracy
2. Lure-bin slope analysis:
   - test whether higher bin (less similar) improves correctness and similar-response probability
   - test interaction with boundary position
3. Stimulus class analysis:
   - Objects vs Scenes effects on correctness and RT
4. Speed-accuracy tradeoff:
   - compare RT among correct vs incorrect by boundary/condition
5. Reliability/stability checks:
   - split-half or block-wise consistency for key effects where possible
6. Subject-level heterogeneity:
   - identify responder subgroups (for example, strong post-cost vs weak/no post-cost)
   - test whether subgrouping is associated with condition or baseline performance

## 5.3 Legacy Metrics for Comparability
Keep REC and LDI as bridge metrics to Phase 1, but not as only endpoints.
- REC = P(old|Target) - P(old|Foil)
- LDI = P(similar|Lure) - P(similar|Foil)
- ALT_LDI as sensitivity metric

## 6) Multiple Comparisons and Reporting Rules
1. Define test families before running:
   - Family 1: primary correctness hypotheses
   - Family 2: primary RT hypotheses
   - Family 3: secondary exploratory set
2. Correct within each family:
   - Holm correction (preferred)
   - BH/FDR allowed for larger exploratory sets
3. Always report:
   - effect sizes (odds ratios for logistic, eta-squared/partial eta-squared or standardized betas where relevant)
   - confidence intervals
   - corrected p-values
4. Also report power-oriented context:
   - expected direction and magnitude from Phase 1
   - achieved sample size per condition and effective sample in each model
   - interpretation of null findings as low-power vs true-null where relevant

## 6.1 Pre-registration and analysis discipline
1. Freeze primary outcomes, model formulas, and correction families before running confirmatory tests.
2. Label all post-hoc additions as exploratory.
3. Keep an analysis log of every model run that was considered for final reporting.
4. Do not replace hypotheses after seeing outcomes.

## 7) Visualization Plan (From Class Principles)
1. Correctness:
   - condition x boundary plots with participant-level overlays
2. RT:
   - distribution-aware plots (violin/box + points), not mean-only bars
3. Response profiles:
   - old/new/similar heatmaps by item type and boundary
4. Lure bins:
   - bin-wise curves with confidence intervals
5. Diagnostic visuals:
   - outlier and residual diagnostics for key models

## 8) Implementation Steps
1. Create `analysis/phase2_analysis.py` with modular sections:
   - load/clean
   - QC/assumptions
   - modeling
   - tables
   - figures
2. Create output folders:
   - `output/phase2/`
   - `report/tables_phase2/`
   - `report/figures_phase2/`
3. Save reproducible artifacts:
   - model summary tables
   - corrected comparison tables
   - effect-size table
   - diagnostics table
4. Add concise report notes for each model:
   - why this test was used
   - whether assumptions held
   - how correction was applied
5. Add a compact analysis registry file:
   - `output/phase2/analysis_registry.csv`
   - model name, purpose (confirmatory/exploratory), assumptions status, included in report (yes/no)

## 9) Deliverables for Phase 2
- Confirmatory results section centered on correctness + RT
- Secondary section on response strategy and additional variables
- Updated conclusions on whether boundary effects persist beyond LDI/REC
- A short limitations section: assumptions, sample, and model sensitivity

## 10) Immediate Next Actions
1. Freeze confirmatory hypotheses and correction families in writing.
2. Implement correctness and RT primary models first.
3. Add secondary variables (lure_bin, stimulus_class, response_label) next.
4. Run sensitivity analyses (outliers/nonparametric fallback).
5. Generate final tables and figures for Phase 2 report.

## 11) Code-Driven Notes from Re-check
1. Current Phase 1 code is strong for descriptive and ANOVA summaries but does not run trial-level categorical models for correctness, which Phase 2 now adds.
2. Participant-level file currently has 2 missing values in `encoding_task_accuracy`; Phase 2 models using this covariate must use explicit missing-data handling.
3. Existing outputs are sufficient to start Phase 2 immediately without changing Phase 1 preprocessing logic.
