from __future__ import annotations

import json
import math
import warnings
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
from scipy import stats
from statsmodels.formula.api import mixedlm
from statsmodels.genmod.cov_struct import Exchangeable
from statsmodels.genmod.families import Binomial, Gaussian
from statsmodels.genmod.generalized_estimating_equations import GEE
from statsmodels.stats.multitest import multipletests

ROOT = Path(__file__).resolve().parents[1]
PHASE1_DIR = ROOT / "output" / "phase1"
PHASE2_DIR = ROOT / "output" / "phase2"
TABLE_DIR = ROOT / "report" / "tables_phase2"
FIG_DIR = ROOT / "report" / "figures_phase2"

CONDITION_ORDER = ["item_only", "both", "task_only"]
BOUNDARY_ORDER = ["post", "mid", "pre"]
ITEM_ROLE_ORDER = ["target", "lure", "foil"]

CONDITION_LABELS = {
    "item_only": "Item Shift Only",
    "both": "Item + Task Shift",
    "task_only": "Task Shift Only",
}


# Silence frequent convergence warnings so outputs stay readable.
warnings.filterwarnings("ignore", category=RuntimeWarning)
warnings.filterwarnings("ignore", category=UserWarning)


def ensure_dirs() -> None:
    for path in (PHASE2_DIR, TABLE_DIR, FIG_DIR):
        path.mkdir(parents=True, exist_ok=True)


def set_plot_theme() -> None:
    sns.set_theme(style="whitegrid", context="talk")
    plt.rcParams.update(
        {
            "figure.dpi": 180,
            "savefig.dpi": 300,
            "savefig.bbox": "tight",
            "axes.spines.top": False,
            "axes.spines.right": False,
            "axes.labelsize": 12,
            "axes.titlesize": 14,
            "xtick.labelsize": 10,
            "ytick.labelsize": 10,
            "legend.fontsize": 10,
        }
    )


def load_data() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    test_trials = pd.read_csv(PHASE1_DIR / "test_trials.csv")
    encoding_trials = pd.read_csv(PHASE1_DIR / "encoding_trials.csv")
    participant_level = pd.read_csv(PHASE1_DIR / "participant_level_metrics.csv")

    test_trials["condition"] = pd.Categorical(test_trials["condition"], CONDITION_ORDER, ordered=True)
    test_trials["test_boundary_position"] = pd.Categorical(
        test_trials["test_boundary_position"], [*BOUNDARY_ORDER, "foil"], ordered=True
    )
    test_trials["item_role"] = pd.Categorical(test_trials["item_role"], ITEM_ROLE_ORDER, ordered=True)
    test_trials["correct_int"] = test_trials["correct"].astype(int)
    test_trials["responded_int"] = test_trials["responded"].astype(int)
    test_trials["response_rt"] = pd.to_numeric(test_trials["response_rt"], errors="coerce")
    test_trials["log_response_rt"] = np.log(test_trials["response_rt"].where(test_trials["response_rt"] > 0))

    encoding_trials["condition"] = pd.Categorical(encoding_trials["condition"], CONDITION_ORDER, ordered=True)
    participant_level["condition"] = pd.Categorical(participant_level["condition"], CONDITION_ORDER, ordered=True)

    return test_trials, encoding_trials, participant_level


def run_qc(test_trials: pd.DataFrame, participant_level: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    qc_rows: list[dict[str, object]] = []

    # Missingness summary for key variables.
    key_vars = [
        "correct",
        "response_label",
        "response_rt",
        "test_boundary_position",
        "item_role",
        "stimulus_class",
        "lure_bin",
    ]
    for var in key_vars:
        qc_rows.append(
            {
                "check": "missingness_test_trials",
                "variable": var,
                "n_missing": int(test_trials[var].isna().sum()),
                "pct_missing": float(test_trials[var].isna().mean()),
            }
        )

    # Missing covariates at participant level.
    covariate = "encoding_task_accuracy"
    qc_rows.append(
        {
            "check": "missingness_participant_level",
            "variable": covariate,
            "n_missing": int(participant_level[covariate].isna().sum()),
            "pct_missing": float(participant_level[covariate].isna().mean()),
        }
    )

    # RT artifact flags.
    rt = test_trials["response_rt"]
    very_fast = (rt < 0.2).sum()
    very_slow = (rt > 30).sum()
    qc_rows.append(
        {
            "check": "rt_artifacts",
            "variable": "response_rt",
            "n_missing": int(rt.isna().sum()),
            "pct_missing": float(rt.isna().mean()),
            "n_very_fast_lt_0.2": int(very_fast),
            "n_very_slow_gt_30": int(very_slow),
        }
    )

    # Participant outlier flags using mean RT z-score.
    by_participant = (
        test_trials.groupby("participant_uid", observed=True)["response_rt"]
        .mean()
        .rename("mean_test_rt_trial")
        .reset_index()
    )
    mean_rt = by_participant["mean_test_rt_trial"]
    z = (mean_rt - mean_rt.mean()) / mean_rt.std(ddof=1)
    by_participant["rt_zscore"] = z
    by_participant["rt_outlier_abs_z_gt_3"] = by_participant["rt_zscore"].abs() > 3

    qc_rows.append(
        {
            "check": "participant_rt_outliers",
            "variable": "mean_test_rt_trial",
            "n_outlier_abs_z_gt_3": int(by_participant["rt_outlier_abs_z_gt_3"].sum()),
            "n_participants": int(len(by_participant)),
        }
    )

    # Quick normality diagnostic on participant mean log RT.
    log_rt = np.log(by_participant["mean_test_rt_trial"].replace(0, np.nan).dropna())
    if len(log_rt) >= 3:
        w_stat, p_val = stats.shapiro(log_rt)
        qc_rows.append(
            {
                "check": "normality_shapiro",
                "variable": "participant_mean_log_rt",
                "statistic": float(w_stat),
                "p_value": float(p_val),
                "n": int(len(log_rt)),
            }
        )

    return pd.DataFrame(qc_rows), by_participant


def gee_correctness_model(test_trials: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    working = test_trials.loc[
        test_trials["test_boundary_position"].isin(BOUNDARY_ORDER)
        & test_trials["item_role"].isin(["target", "lure"])
    ].copy()

    # Center lure_bin so intercept is interpretable.
    working["lure_bin"] = pd.to_numeric(working["lure_bin"], errors="coerce")
    working["lure_bin_c"] = working["lure_bin"] - working["lure_bin"].mean()

    model = GEE.from_formula(
        "correct_int ~ C(condition) * C(test_boundary_position) + C(item_role) + C(stimulus_class) + lure_bin_c",
        groups="participant_uid",
        data=working,
        family=Binomial(),
        cov_struct=Exchangeable(),
    )
    result = model.fit()

    table = pd.DataFrame(
        {
            "term": result.params.index,
            "coef": result.params.values,
            "std_err": result.bse.values,
            "z": result.tvalues.values,
            "p_value": result.pvalues.values,
        }
    )
    table["odds_ratio"] = np.exp(table["coef"])
    table["ci_low_or"] = np.exp(table["coef"] - 1.96 * table["std_err"])
    table["ci_high_or"] = np.exp(table["coef"] + 1.96 * table["std_err"])
    table["analysis_family"] = "primary_correctness"

    # Participant-level fallback: Friedman within each condition for target correctness by boundary.
    fallback_rows: list[dict[str, object]] = []
    target = working.loc[working["item_role"] == "target"].copy()
    grouped = (
        target.groupby(["participant_uid", "condition", "test_boundary_position"], observed=True)["correct_int"]
        .mean()
        .reset_index()
    )

    for condition in CONDITION_ORDER:
        subset = grouped.loc[grouped["condition"] == condition]
        pivot = subset.pivot(index="participant_uid", columns="test_boundary_position", values="correct_int")
        pivot = pivot.reindex(columns=BOUNDARY_ORDER).dropna()
        if len(pivot) >= 3:
            stat, p_value = stats.friedmanchisquare(pivot["post"], pivot["mid"], pivot["pre"])
            kendall_w = float(stat) / (len(pivot) * (len(BOUNDARY_ORDER) - 1))
            fallback_rows.append(
                {
                    "analysis_family": "fallback_nonparametric",
                    "condition": condition,
                    "test": "friedman_target_correctness",
                    "n": int(len(pivot)),
                    "statistic": float(stat),
                    "p_value": float(p_value),
                    "effect_size_kendall_w": kendall_w,
                }
            )

    return table, pd.DataFrame(fallback_rows)


def mixed_rt_model(test_trials: pd.DataFrame) -> pd.DataFrame:
    working = test_trials.loc[
        test_trials["test_boundary_position"].isin(BOUNDARY_ORDER)
        & test_trials["responded"]
        & test_trials["response_rt"].notna()
        & (test_trials["response_rt"] > 0)
    ].copy()

    # Start with a rich mixed model; back off to simpler models if singular.
    formulas = [
        "log_response_rt ~ C(condition) * C(test_boundary_position) * C(item_role) + correct_int",
        "log_response_rt ~ C(condition) * C(test_boundary_position) + C(item_role) + correct_int",
    ]

    result = None
    model_used = ""
    for formula in formulas:
        try:
            model = mixedlm(formula, data=working, groups=working["participant_uid"])
            result = model.fit(reml=False, method="lbfgs")
            model_used = f"mixedlm::{formula}"
            break
        except Exception:
            continue

    if result is None:
        # Final fallback: clustered Gaussian GEE keeps participant dependency handling.
        gee_model = GEE.from_formula(
            "log_response_rt ~ C(condition) * C(test_boundary_position) + C(item_role) + correct_int",
            groups="participant_uid",
            data=working,
            family=Gaussian(),
            cov_struct=Exchangeable(),
        )
        result = gee_model.fit()
        model_used = "gee_gaussian::log_response_rt ~ C(condition)*C(test_boundary_position)+C(item_role)+correct_int"

    table = pd.DataFrame(
        {
            "term": result.params.index,
            "coef": result.params.values,
            "std_err": result.bse.values,
            "z": result.tvalues.values,
            "p_value": result.pvalues.values,
        }
    )
    table["ratio_change_rt"] = np.exp(table["coef"])
    table["ci_low_ratio"] = np.exp(table["coef"] - 1.96 * table["std_err"])
    table["ci_high_ratio"] = np.exp(table["coef"] + 1.96 * table["std_err"])
    table["analysis_family"] = "primary_rt"
    table["model_used"] = model_used
    return table


def response_profile_tests(test_trials: pd.DataFrame) -> pd.DataFrame:
    # Categorical test taught in class: chi-square for response category by boundary.
    rows: list[dict[str, object]] = []
    working = test_trials.loc[test_trials["test_boundary_position"].isin(BOUNDARY_ORDER)].copy()

    for condition in CONDITION_ORDER:
        for item_role in ["target", "lure", "foil"]:
            subset = working.loc[(working["condition"] == condition) & (working["item_role"] == item_role)]
            if subset.empty:
                continue
            contingency = pd.crosstab(subset["test_boundary_position"], subset["response_label"])
            if contingency.shape[0] < 2 or contingency.shape[1] < 2:
                continue
            chi2, p_value, dof, _ = stats.chi2_contingency(contingency)
            n = contingency.to_numpy().sum()
            # Cramer's V for effect size.
            min_dim = min(contingency.shape[0] - 1, contingency.shape[1] - 1)
            cramer_v = math.sqrt(chi2 / (n * min_dim)) if min_dim > 0 else math.nan
            rows.append(
                {
                    "analysis_family": "secondary_response_profile",
                    "condition": condition,
                    "item_role": item_role,
                    "test": "chi_square_independence",
                    "chi2": float(chi2),
                    "dof": int(dof),
                    "p_value": float(p_value),
                    "cramers_v": float(cramer_v),
                    "n": int(n),
                }
            )

    return pd.DataFrame(rows)


def lure_bin_gee(test_trials: pd.DataFrame) -> pd.DataFrame:
    lure = test_trials.loc[
        (test_trials["item_role"] == "lure")
        & test_trials["test_boundary_position"].isin(BOUNDARY_ORDER)
        & test_trials["lure_bin"].notna()
    ].copy()
    lure["similar_resp"] = lure["response_label"].eq("similar").astype(int)
    lure["lure_bin"] = pd.to_numeric(lure["lure_bin"], errors="coerce")

    model = GEE.from_formula(
        "similar_resp ~ lure_bin * C(test_boundary_position) + C(condition) + C(stimulus_class)",
        groups="participant_uid",
        data=lure,
        family=Binomial(),
        cov_struct=Exchangeable(),
    )
    result = model.fit()

    table = pd.DataFrame(
        {
            "term": result.params.index,
            "coef": result.params.values,
            "std_err": result.bse.values,
            "z": result.tvalues.values,
            "p_value": result.pvalues.values,
        }
    )
    table["odds_ratio"] = np.exp(table["coef"])
    table["ci_low_or"] = np.exp(table["coef"] - 1.96 * table["std_err"])
    table["ci_high_or"] = np.exp(table["coef"] + 1.96 * table["std_err"])
    table["analysis_family"] = "secondary_lure_bin"
    return table


def speed_accuracy_summary(test_trials: pd.DataFrame) -> pd.DataFrame:
    working = test_trials.loc[
        test_trials["test_boundary_position"].isin(BOUNDARY_ORDER)
        & test_trials["response_rt"].notna()
    ].copy()

    summary = (
        working.groupby(["participant_uid", "condition", "item_role", "correct"], observed=True)["response_rt"]
        .mean()
        .reset_index()
        .pivot(index=["participant_uid", "condition", "item_role"], columns="correct", values="response_rt")
        .reset_index()
        .rename(columns={False: "mean_rt_incorrect", True: "mean_rt_correct"})
    )
    if "mean_rt_correct" not in summary.columns:
        summary["mean_rt_correct"] = np.nan
    if "mean_rt_incorrect" not in summary.columns:
        summary["mean_rt_incorrect"] = np.nan
    summary["delta_rt_incorrect_minus_correct"] = summary["mean_rt_incorrect"] - summary["mean_rt_correct"]
    return summary


def apply_family_corrections(
    primary_correctness: pd.DataFrame,
    primary_rt: pd.DataFrame,
    secondary_profile: pd.DataFrame,
    secondary_lure: pd.DataFrame,
) -> pd.DataFrame:
    families: list[pd.DataFrame] = []

    def _correct(df: pd.DataFrame, family_name: str) -> pd.DataFrame:
        if df.empty or "p_value" not in df.columns:
            return df
        corrected = df.copy()
        _, p_holm, _, _ = multipletests(corrected["p_value"].to_numpy(), method="holm")
        _, p_bh, _, _ = multipletests(corrected["p_value"].to_numpy(), method="fdr_bh")
        corrected["p_value_holm"] = p_holm
        corrected["p_value_bh"] = p_bh
        corrected["family"] = family_name
        return corrected

    families.append(_correct(primary_correctness, "primary_correctness"))
    families.append(_correct(primary_rt, "primary_rt"))
    families.append(_correct(secondary_profile, "secondary_response_profile"))
    families.append(_correct(secondary_lure, "secondary_lure_bin"))

    combined = pd.concat([df for df in families if df is not None and not df.empty], ignore_index=True)
    return combined


def plot_correctness(test_trials: pd.DataFrame) -> None:
    working = test_trials.loc[
        test_trials["item_role"].isin(["target", "lure"])
        & test_trials["test_boundary_position"].isin(BOUNDARY_ORDER)
    ].copy()

    summary = (
        working.groupby(["condition", "test_boundary_position"], observed=True)["correct_int"]
        .mean()
        .reset_index()
    )

    fig, ax = plt.subplots(figsize=(9.5, 5.4))
    sns.barplot(
        data=summary,
        x="test_boundary_position",
        y="correct_int",
        hue="condition",
        order=BOUNDARY_ORDER,
        hue_order=CONDITION_ORDER,
        ax=ax,
    )
    ax.set_ylim(0, 1)
    ax.set_xlabel("Boundary position")
    ax.set_ylabel("Mean correctness")
    ax.set_title("Phase 2: Correctness by boundary and condition")
    ax.legend(title="Condition", labels=[CONDITION_LABELS[c] for c in CONDITION_ORDER])
    fig.savefig(FIG_DIR / "phase2_correctness_boundary_condition.png")
    plt.close(fig)


def plot_rt(test_trials: pd.DataFrame) -> None:
    working = test_trials.loc[
        test_trials["test_boundary_position"].isin(BOUNDARY_ORDER)
        & test_trials["response_rt"].notna()
        & test_trials["response_rt"].between(0.2, 30)
    ].copy()

    fig, axes = plt.subplots(1, 3, figsize=(14.2, 4.8), sharey=True)
    for ax, condition in zip(axes, CONDITION_ORDER):
        subset = working.loc[working["condition"] == condition]
        sns.violinplot(
            data=subset,
            x="test_boundary_position",
            y="response_rt",
            order=BOUNDARY_ORDER,
            inner="quartile",
            cut=0,
            ax=ax,
        )
        ax.set_title(CONDITION_LABELS[condition])
        ax.set_xlabel("Boundary")
        ax.grid(axis="y", alpha=0.2)
    axes[0].set_ylabel("Response RT (s)")
    axes[1].set_ylabel("")
    axes[2].set_ylabel("")
    fig.suptitle("Phase 2: Test RT distributions by boundary")
    fig.savefig(FIG_DIR / "phase2_test_rt_violin.png")
    plt.close(fig)


def plot_lure_bins(test_trials: pd.DataFrame) -> None:
    lure = test_trials.loc[
        (test_trials["item_role"] == "lure")
        & test_trials["test_boundary_position"].isin(BOUNDARY_ORDER)
        & test_trials["lure_bin"].notna()
    ].copy()
    lure["similar_resp"] = lure["response_label"].eq("similar").astype(float)

    fig, ax = plt.subplots(figsize=(9.8, 5.4))
    sns.pointplot(
        data=lure,
        x="lure_bin",
        y="similar_resp",
        hue="test_boundary_position",
        hue_order=BOUNDARY_ORDER,
        errorbar=("ci", 95),
        dodge=0.2,
        ax=ax,
    )
    ax.set_ylim(0, 1)
    ax.set_xlabel("Lure bin (1=more similar, 5=less similar)")
    ax.set_ylabel("P(similar response)")
    ax.set_title("Phase 2: Lure-bin slopes by boundary")
    fig.savefig(FIG_DIR / "phase2_lure_bin_slopes.png")
    plt.close(fig)


def write_analysis_registry() -> pd.DataFrame:
    rows = [
        {
            "model_name": "primary_correctness_gee",
            "purpose": "confirmatory",
            "assumption_focus": "clustered binary outcome; robust sandwich SE",
            "included_in_report": True,
        },
        {
            "model_name": "primary_rt_mixedlm",
            "purpose": "confirmatory",
            "assumption_focus": "normality of residuals for log RT",
            "included_in_report": True,
        },
        {
            "model_name": "fallback_friedman_target_correctness",
            "purpose": "robustness",
            "assumption_focus": "nonparametric repeated-measures alternative",
            "included_in_report": True,
        },
        {
            "model_name": "secondary_response_profile_chi_square",
            "purpose": "exploratory",
            "assumption_focus": "categorical independence tests",
            "included_in_report": True,
        },
        {
            "model_name": "secondary_lure_bin_gee",
            "purpose": "exploratory",
            "assumption_focus": "clustered binary outcome with lure difficulty",
            "included_in_report": True,
        },
    ]
    registry = pd.DataFrame(rows)
    return registry


def save_outputs(
    qc_summary: pd.DataFrame,
    participant_rt_flags: pd.DataFrame,
    primary_correctness: pd.DataFrame,
    primary_rt: pd.DataFrame,
    fallback_np: pd.DataFrame,
    secondary_profile: pd.DataFrame,
    secondary_lure: pd.DataFrame,
    speed_accuracy: pd.DataFrame,
    corrected: pd.DataFrame,
    registry: pd.DataFrame,
) -> None:
    qc_summary.to_csv(PHASE2_DIR / "qc_summary.csv", index=False)
    participant_rt_flags.to_csv(PHASE2_DIR / "participant_rt_outlier_flags.csv", index=False)
    primary_correctness.to_csv(TABLE_DIR / "phase2_primary_correctness_gee.csv", index=False)
    primary_rt.to_csv(TABLE_DIR / "phase2_primary_rt_mixedlm.csv", index=False)
    fallback_np.to_csv(TABLE_DIR / "phase2_fallback_nonparametric.csv", index=False)
    secondary_profile.to_csv(TABLE_DIR / "phase2_secondary_response_profile_chisq.csv", index=False)
    secondary_lure.to_csv(TABLE_DIR / "phase2_secondary_lure_bin_gee.csv", index=False)
    speed_accuracy.to_csv(TABLE_DIR / "phase2_speed_accuracy_summary.csv", index=False)
    corrected.to_csv(TABLE_DIR / "phase2_all_tests_corrected.csv", index=False)
    registry.to_csv(PHASE2_DIR / "analysis_registry.csv", index=False)

    notes = {
        "confirmatory_primary": [
            "Correctness modeled via clustered logistic GEE with participant-level clustering.",
            "Response speed modeled via mixed-effects linear model on log RT.",
        ],
        "fallbacks_and_secondary": [
            "Friedman nonparametric tests for target correctness within condition.",
            "Chi-square response-profile tests with Cramer's V.",
            "Lure-bin slope model using GEE on similar-response probability.",
        ],
    }
    with (PHASE2_DIR / "analysis_notes.json").open("w") as handle:
        json.dump(notes, handle, indent=2)


def main() -> None:
    ensure_dirs()
    set_plot_theme()

    test_trials, encoding_trials, participant_level = load_data()
    qc_summary, participant_rt_flags = run_qc(test_trials, participant_level)

    primary_correctness, fallback_np = gee_correctness_model(test_trials)
    primary_rt = mixed_rt_model(test_trials)
    secondary_profile = response_profile_tests(test_trials)
    secondary_lure = lure_bin_gee(test_trials)
    speed_accuracy = speed_accuracy_summary(test_trials)

    corrected = apply_family_corrections(
        primary_correctness=primary_correctness,
        primary_rt=primary_rt,
        secondary_profile=secondary_profile,
        secondary_lure=secondary_lure,
    )

    plot_correctness(test_trials)
    plot_rt(test_trials)
    plot_lure_bins(test_trials)

    registry = write_analysis_registry()
    save_outputs(
        qc_summary=qc_summary,
        participant_rt_flags=participant_rt_flags,
        primary_correctness=primary_correctness,
        primary_rt=primary_rt,
        fallback_np=fallback_np,
        secondary_profile=secondary_profile,
        secondary_lure=secondary_lure,
        speed_accuracy=speed_accuracy,
        corrected=corrected,
        registry=registry,
    )

    print("Saved Phase 2 outputs to", PHASE2_DIR)
    print("Saved Phase 2 tables to", TABLE_DIR)
    print("Saved Phase 2 figures to", FIG_DIR)


if __name__ == "__main__":
    main()
