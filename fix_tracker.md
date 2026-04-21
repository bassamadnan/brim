# Phase 2 Fix Tracker

> Started: 2026-04-22 | Completed: 2026-04-22
> Reference: `phase2_review.md` for full details on each issue.

---

## Status Legend
- `[ ]` — Not started
- `[~]` — In progress
- `[x]` — Done

---

## Block A — Bug Fixes (Code Correctness)

### A1 — Fix RT model naming and report language `[B1]`
- [x] Rename output file → `phase2_primary_rt_gee.csv` (old `phase2_primary_rt_mixedlm.csv` deleted)
- [x] Update `save_outputs()` in `phase2_analysis.py` to use the new filename
- [x] Report `main_phase2.typ` consistently says "Gaussian GEE" for the RT model throughout
- [x] Added one sentence clarifying LMM singularity and GEE population-average estimand

### A2 — Fix foil category leaking into GEE models `[B2]`
- [x] Added `_clean_boundary_cat()` helper using `.cat.remove_unused_categories()`
- [x] Applied in `gee_correctness_model()` — verified: no `[T.foil]` rows for boundary in output
- [x] Applied in `mixed_rt_model()`
- [x] Applied in `response_profile_tests()`
- [x] Applied in `lure_bin_gee()`
- [x] Applied in `robustness_reruns()` (split model inner loops)
- [x] Re-ran `phase2_analysis.py` — all tables confirmed clean
- [x] Used `isinstance(df[col].dtype, pd.CategoricalDtype)` instead of deprecated `is_categorical_dtype`

### A3 — Fix lure_bin_c in combined target+lure GEE `[B3]`
- [x] Removed `lure_bin_c` from the combined correctness GEE formula
- [x] Added `C(stimulus_class) * C(test_boundary_position)` interaction instead (Gap G3)
- [x] Regenerated `phase2_primary_correctness_gee.csv` — clean, no ambiguous lure_bin term
- [x] Report updated to cite lure_bin effect from the lure-specific split model

---

## Block B — New Analyses (Substance)

### B1 — Encoding RT → Test Accuracy Carry-Over Analysis `[G1]`
- [x] `encoding_rt_carryover()` function written in `phase2_analysis.py`
  - Joins `encoding_trials.csv` to `test_trials.csv` on `(participant_uid, item_number)`
  - Logistic GEE: `correct_int ~ log_encoding_rt + boundary + condition + item_role + stimulus_class`
  - **Result: OR = 0.988, p = .646 — null (encoding RT does not predict test correctness)**
  - Boundary position mid > post remains significant (OR = 1.106, p = .013) in this model
- [x] Saved `report/tables_phase2/phase2_encoding_rt_carryover_gee.csv`
- [x] Scatter plot saved as `phase2_encoding_rt_vs_correctness_scatter.png`
- [x] `report/tables_phase2/phase2_encoding_rt_correctness_scatter.csv` saved
- [x] Carry-over null reported and interpreted in `main_phase2.typ`

### B2 — Participant-Level Heterogeneity Analysis `[G2]`
- [x] `participant_heterogeneity()` function written
  - Per-participant (post − mid) and (post − pre) target correctness by condition
  - 63% of `both` condition participants show negative post-mid contrast
- [x] Saved `report/tables_phase2/phase2_participant_boundary_contrasts.csv` (158 rows)
- [x] Histogram figure `phase2_participant_contrast_distribution.png` generated
- [x] Results reported in `main_phase2.typ`

### B3 — Stimulus Class × Boundary Interaction `[G3]`
- [x] Added `C(stimulus_class) * C(test_boundary_position)` to primary correctness GEE
- [x] **New finding: Scenes × mid OR = 0.785 (p = .005); Scenes × pre OR = 0.754 (p = .003)**
- [x] Interpretation: post-boundary cost concentrated in Objects; Scenes show weaker/reversed pattern
- [x] Reported in `main_phase2.typ` as a new finding

### B4 — Speed-Accuracy by Boundary Position `[G4]`
- [x] `speed_accuracy_summary()` now returns two DataFrames: collapsed + by-boundary
- [x] Saved `report/tables_phase2/phase2_speed_accuracy_by_boundary.csv`
- [x] Figure `phase2_speed_accuracy_by_boundary.png` generated
- [x] Result: speed-accuracy gap (~0.278 s) is consistent across boundary positions (no boundary-driven change)

### B5 — Cohen's dz for Key Boundary Contrasts `[R4]`
- [x] `cohens_dz` column added directly inside `robustness_reruns()` (d = t / sqrt(n))
- [x] Updated `phase2_robustness_boundary_contrasts.csv` — all rows have `cohens_dz`
- [x] Key result: both × target × post-mid: dz = −0.477, Holm p = .020
- [x] Report updated with Cohen's dz throughout boundary contrast text

---

## Block C — Missing Visualizations

### C1 — Target-Only Correctness by Boundary Figure `[V1]`
- [x] `plot_target_correctness()` written
  - Participant-level scatter + pointplot mean+95% CI
  - 3-panel, one per condition, shared y-axis
- [x] Saved `report/figures_phase2/phase2_target_correctness_by_boundary.png`
- [x] Referenced in `main_phase2.typ`

### C2 — Within-Participant Contrast Distribution `[V2]`
- [x] `plot_participant_contrasts()` written
  - Histogram + KDE per condition, zero-line + mean-line
- [x] Saved `report/figures_phase2/phase2_participant_contrast_distribution.png`
- [x] Referenced in `main_phase2.typ`

### C3 — Phase 1 REC vs Phase 2 Correctness Side-by-Side `[G5, V3]`
- [x] `plot_phase1_vs_phase2_bridge()` written
  - Left: REC by boundary from `participant_level_metrics.csv` (both condition)
  - Right: Phase 2 target correctness by boundary (both condition)
- [x] Saved `report/figures_phase2/phase2_phase1_vs_phase2_bridge.png`
- [x] Referenced in `main_phase2.typ` as primary confirmatory figure

### C4 — Encoding RT vs Test Correctness Scatter `[G1, V4]`
- [x] `plot_encoding_rt_vs_correctness()` written
  - Participant-level scatter: mean encoding RT (post) vs mean target correctness (post)
  - Per-condition regression lines + overall Pearson r annotation
- [x] Saved `report/figures_phase2/phase2_encoding_rt_vs_correctness_scatter.png`
- [x] Referenced in `main_phase2.typ`

---

## Block D — Report and Framing Fixes

### D1 — Reorder Results Section `[R1, R2]`
- [x] Friedman test + Holm contrasts moved to FIRST results section ("Primary result")
- [x] Bridge figure (Phase 1 REC + Phase 2 correctness) shown immediately after
- [x] Target correctness figure shown after bridge figure
- [x] GEE model now described as confirmatory support, not the headline

### D2 — Reframe LDI Non-Replication `[R3]`
- [x] Conclusion section explicitly states: "With N = 158 across three boundary types — a sample considerably larger than the original study — this null should be treated as a genuine non-replication rather than a power limitation"

### D3 — Effect Size Table `[R4]`
- [x] Cohen's dz reported inline in all boundary contrast text in `main_phase2.typ`
- [x] `cohens_dz` column in `phase2_robustness_boundary_contrasts.csv`
- [x] Kendall's W, OR+CI, Cramér's V all reported in appropriate sections

---

## Block E — Re-run and Regenerate

### E1 — Full Pipeline Re-run
- [x] Ran `uv run python analysis/phase2_analysis.py` — exit code 0
- [x] All 16 output tables present in `report/tables_phase2/`
- [x] All 12 figures present in `report/figures_phase2/`
- [x] Old `phase2_primary_rt_mixedlm.csv` deleted
- [x] No phantom foil rows in GEE tables
- [x] `analysis_registry.csv` updated with all new models and fix notes

---

## Post-Review Bug: RT Model Degeneracy (Fixed 2026-04-22)

### Extra Bug Discovered During Final Audit

- [x] **RT model was silently using a degenerate mixedlm output (Group Var = 0)**
  - Root cause: `mixedlm.fit()` succeeded without raising an exception, but the random-effect variance collapsed to zero (Group Var = 0 in output). The GEE fallback was never triggered.
  - Effect: condition-level terms had p = 1.0, std_err > 600,000; `model_used` column said `mixedlm` instead of `gee_gaussian`
  - Fix: Added `group_var = float(fit.cov_re.iloc[0,0]); if abs(group_var) < 1e-6: continue` check in the mixedlm loop — degenerate fits now fall through to GEE
  - Verified: `model_used` now shows `gee_gaussian::...` in `phase2_primary_rt_gee.csv`; all condition-level terms have valid estimates (task_only p = .013, both p = .083)
  - Report numbers were already correct (1.105, 0.880, 0.922) — they matched the GEE values, not the degenerate mixedlm

- [x] **item_role Categorical foil leakage was still present** (fixed same session)
  - `_clean_boundary_cat()` was only cleaning `test_boundary_position`, not `item_role`
  - Fix: Updated helper to loop over both `[col, "item_role"]` — removes unused levels from both
  - Verified: All GEE tables clean (no `C(item_role)[T.foil]` rows anywhere)
## Progress Summary

| Block | Items | Done | Remaining |
|---|---|---|---|
| A — Bug Fixes | 13 subtasks | 13 | 0 |
| B — New Analyses | 15 subtasks | 15 | 0 |
| C — Missing Visuals | 8 subtasks | 8 | 0 |
| D — Report Fixes | 8 subtasks | 8 | 0 |
| E — Re-run | 4 subtasks | 4 | 0 |
| **Extra bugs found in final audit** | **2 additional** | **2** | **0** |
| **Total** | **50 subtasks** | **50** | **0** |
---

## New Results Summary (Key Numbers for Poster)

| Finding | Statistic | Significance |
|---|---|---|
| Post-boundary recognition cost (both × target) | Friedman χ²(2) = 11.47, W = 0.117 | p = .003 |
| Post-minus-mid contrast (both × target) | t(48) = −3.34, dz = −0.477 | Holm p = .020 |
| 63% of both-condition participants show negative post-mid contrast | — | — |
| Scenes × mid boundary interaction (new) | OR = 0.785 | p = .005 |
| Scenes × pre boundary interaction (new) | OR = 0.754 | p = .003 |
| Encoding RT carry-over (null) | OR = 0.988 | p = .646 |
| Mid-event advantage in correctness GEE | OR = 1.186 | p = .024 |
| Lure-bin slope (lure-only model) | OR = 1.192/bin | p < .001 |
| Correct faster than incorrect (RT GEE) | exp(β) = 0.922 | p < .001 |
