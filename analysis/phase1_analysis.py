from __future__ import annotations

import ast
import csv
import json
import math
import re
from dataclasses import dataclass
from datetime import datetime
from itertools import combinations
from pathlib import Path
from typing import Iterable

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
from scipy import stats
from statsmodels.stats.anova import AnovaRM
from statsmodels.stats.multitest import multipletests

ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "output" / "phase1"
FIG_DIR = ROOT / "report" / "figures"
TABLE_DIR = ROOT / "report" / "tables"

CONDITIONS = {
    "item_only": {
        "label": "Item Shift Only",
        "folder": ROOT / "MST_Data" / "item_only" / "item_only_data",
        "object_bins": ROOT / "MST_Data" / "item_only" / "Set6 bins.txt",
        "scene_bins": ROOT / "MST_Data" / "item_only" / "SetScC bins.txt",
        "scenes_mapping": ROOT / "MST_Data" / "item_only" / "scenes_mapping.txt",
    },
    "both": {
        "label": "Item + Task Shift",
        "folder": ROOT / "MST_Data" / "Both_item_task" / "both_data",
        "object_bins": ROOT / "MST_Data" / "Both_item_task" / "Set6 bins.txt",
        "scene_bins": ROOT / "MST_Data" / "Both_item_task" / "SetScC bins.txt",
        "scenes_mapping": None,
    },
    "task_only": {
        "label": "Task Shift Only",
        "folder": ROOT / "MST_Data" / "task_only" / "task_only_data",
        "object_bins": ROOT / "MST_Data" / "task_only" / "Set6 bins_ob.txt",
        "scene_bins": None,
        "scenes_mapping": None,
    },
}

BOUNDARY_ORDER = ["post", "mid", "pre"]
BOUNDARY_LABELS = {"post": "Post-boundary", "mid": "Mid-event", "pre": "Pre-boundary"}
RESPONSE_MAP = {"o": "old", "n": "new", "s": "similar"}
EXPECTED_RESPONSE = {"target": "old", "lure": "similar", "foil": "new"}
CONDITION_ORDER = ["item_only", "both", "task_only"]
CONDITION_LABELS = {key: value["label"] for key, value in CONDITIONS.items()}
CONDITION_PALETTE = {
    "item_only": "#247b7b",
    "both": "#c96b3b",
    "task_only": "#355c7d",
}
BOUNDARY_PALETTE = {
    "post": "#d1495b",
    "mid": "#6c8b8b",
    "pre": "#edae49",
}
RESPONSE_PALETTE = {
    "old": "#355c7d",
    "new": "#6c8b8b",
    "similar": "#c96b3b",
}


@dataclass
class PairSelection:
    participant_id: str
    task_file: Path | None
    test_file: Path | None
    selection_note: str


@dataclass(frozen=True)
class FileStamp:
    path: Path
    participant_id: str
    phase: str
    timestamp: datetime


FILE_RE = re.compile(
    r"(?P<pid>\d{5})_MST_(?P<phase>task|test)_(?P<date>\d{4}-\d{2}-\d{2})_(?P<hour>\d{2})h(?P<minute>\d{2})\.(?P<second>\d{2})\.(?P<millis>\d{3})\.csv"
)


def ensure_dirs() -> None:
    for path in (OUTPUT_DIR, FIG_DIR, TABLE_DIR):
        path.mkdir(parents=True, exist_ok=True)


def parse_stamp(path: Path) -> FileStamp:
    match = FILE_RE.fullmatch(path.name)
    if not match:
        raise ValueError(f"Unexpected file name: {path.name}")
    timestamp = datetime.strptime(
        (
            f"{match.group('date')} {match.group('hour')}:{match.group('minute')}:{match.group('second')}."
            f"{match.group('millis')}"
        ),
        "%Y-%m-%d %H:%M:%S.%f",
    )
    return FileStamp(
        path=path,
        participant_id=match.group("pid"),
        phase=match.group("phase"),
        timestamp=timestamp,
    )


def safe_float(value: str | None) -> float:
    if value in (None, "", "None"):
        return math.nan
    try:
        return float(value)
    except ValueError:
        return math.nan


def load_bin_map(path: Path | None) -> dict[int, int]:
    if path is None:
        return {}
    mapping: dict[int, int] = {}
    with path.open() as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            item_id, bin_id = line.split("\t")
            mapping[int(item_id)] = int(bin_id)
    return mapping


def load_accuracy_map(path: Path | None) -> dict[str, str]:
    if path is None:
        return {}
    mapping: dict[str, str] = {}
    with path.open() as handle:
        for line in handle:
            parts = line.strip().split()
            if len(parts) == 2:
                mapping[normalize_path(parts[0]).lower()] = parts[1].lower()
    return mapping


def select_pairs(folder: Path) -> tuple[list[PairSelection], list[dict[str, str]]]:
    stamps = [parse_stamp(path) for path in sorted(folder.glob("*.csv"))]
    by_pid: dict[str, dict[str, list[FileStamp]]] = {}
    for stamp in stamps:
        by_pid.setdefault(stamp.participant_id, {"task": [], "test": []})[stamp.phase].append(stamp)

    selections: list[PairSelection] = []
    audit_rows: list[dict[str, str]] = []

    for participant_id, buckets in sorted(by_pid.items()):
        tasks = sorted(buckets["task"], key=lambda item: item.timestamp)
        tests = sorted(buckets["test"], key=lambda item: item.timestamp)

        if not tasks or not tests:
            selections.append(
                PairSelection(
                    participant_id=participant_id,
                    task_file=tasks[-1].path if tasks else None,
                    test_file=tests[-1].path if tests else None,
                    selection_note="missing_task" if not tasks else "missing_test",
                )
            )
            audit_rows.append(
                {
                    "participant_id": participant_id,
                    "status": "incomplete",
                    "task_candidates": " | ".join(task.path.name for task in tasks),
                    "test_candidates": " | ".join(test.path.name for test in tests),
                    "selected_task": tasks[-1].path.name if tasks else "",
                    "selected_test": tests[-1].path.name if tests else "",
                    "selection_note": "missing_task" if not tasks else "missing_test",
                }
            )
            continue

        candidate_pairs: list[tuple[datetime, float, FileStamp, FileStamp]] = []
        for test in tests:
            preceding_tasks = [task for task in tasks if task.timestamp <= test.timestamp]
            if preceding_tasks:
                chosen_task = preceding_tasks[-1]
                gap = (test.timestamp - chosen_task.timestamp).total_seconds()
                candidate_pairs.append((test.timestamp, gap, chosen_task, test))

        if candidate_pairs:
            _, _, chosen_task, chosen_test = sorted(candidate_pairs, key=lambda item: (item[0], -item[1]))[-1]
            note = "resolved_latest_complete_pair" if len(tasks) > 1 or len(tests) > 1 else "unique_pair"
        else:
            all_pairs: list[tuple[float, FileStamp, FileStamp]] = []
            for task in tasks:
                for test in tests:
                    gap = abs((test.timestamp - task.timestamp).total_seconds())
                    all_pairs.append((gap, task, test))
            _, chosen_task, chosen_test = min(all_pairs, key=lambda item: item[0])
            note = "resolved_nearest_pair_without_order"

        selections.append(
            PairSelection(
                participant_id=participant_id,
                task_file=chosen_task.path,
                test_file=chosen_test.path,
                selection_note=note,
            )
        )
        audit_rows.append(
            {
                "participant_id": participant_id,
                "status": "paired",
                "task_candidates": " | ".join(task.path.name for task in tasks),
                "test_candidates": " | ".join(test.path.name for test in tests),
                "selected_task": chosen_task.path.name,
                "selected_test": chosen_test.path.name,
                "selection_note": note,
            }
        )

    return selections, audit_rows


def normalize_path(path_value: str) -> str:
    return path_value.replace("\\", "/")


def parse_stimulus(path_value: str, condition: str, phase: str) -> dict[str, object]:
    normalized = normalize_path(path_value)
    prefix = normalized.split("/", 1)[0].lower() if "/" in normalized else normalized.lower()
    filename = normalized.split("/")[-1]
    number_match = re.search(r"(\d+)", filename)
    item_number = int(number_match.group(1)) if number_match else math.nan

    if phase == "test":
        if prefix == "foils":
            item_role = "foil"
        elif filename.lower().endswith("b.jpg"):
            item_role = "lure"
        else:
            item_role = "target"
    else:
        item_role = "studied"

    if prefix.startswith("objects"):
        stimulus_class = "Objects"
    elif prefix.startswith("scenes"):
        stimulus_class = "Scenes"
    elif prefix == "foils":
        if "scene" in filename.lower():
            stimulus_class = "Scenes"
        elif condition == "task_only":
            stimulus_class = "Objects"
        elif "object" in filename.lower():
            stimulus_class = "Objects"
        else:
            stimulus_class = "Foils"
    else:
        stimulus_class = "Unknown"

    return {
        "image_path_normalized": normalized,
        "stimulus_class": stimulus_class,
        "item_number": item_number,
        "item_role": item_role,
    }


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def build_condition_frames(condition: str, pair_selection: Iterable[PairSelection]) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    object_bins = load_bin_map(CONDITIONS[condition]["object_bins"])
    scene_bins = load_bin_map(CONDITIONS[condition]["scene_bins"])

    participant_rows: list[dict[str, object]] = []
    task_rows: list[dict[str, object]] = []
    test_rows: list[dict[str, object]] = []

    for selection in pair_selection:
        if selection.task_file is None or selection.test_file is None:
            continue

        participant_uid = f"{condition}_{selection.participant_id}"
        task_data = read_csv_rows(selection.task_file)
        test_data = read_csv_rows(selection.test_file)

        main_task_rows = [
            row for row in task_data if row.get("image_path") and not row["image_path"].startswith("practice_")
        ]
        main_test_rows = [row for row in test_data if row.get("image_path")]

        if condition == "item_only":
            scenes_mapping = load_accuracy_map(CONDITIONS[condition].get("scenes_mapping"))
            correct_count = 0
            total_scored = 0
            for row in main_task_rows:
                img_path = normalize_path(row["image_path"]).lower()
                if img_path in scenes_mapping:
                    key_fast = row.get("key_resp_9.keys") or row.get("trials.key_resp_9.keys")
                    key_slow = row.get("key_resp_8.keys") or row.get("trials.key_resp_8.keys")
                    response_key = key_fast if key_fast not in (None, "", "None") else key_slow
                    if pd.notna(response_key) and response_key not in (None, "", "None"):
                        expected = scenes_mapping[img_path]
                        if str(response_key).lower() == expected:
                            correct_count += 1
                    total_scored += 1
            if total_scored > 0:
                task_accuracy = float(correct_count) / total_scored
            else:
                task_accuracy = math.nan
        else:
            task_accuracy = safe_float(task_data[-1].get("encoding_task_accuracy")) if task_data else math.nan

        participant_rows.append(
            {
                "participant_uid": participant_uid,
                "participant_id": selection.participant_id,
                "condition": condition,
                "condition_label": CONDITION_LABELS[condition],
                "task_file": selection.task_file.name,
                "test_file": selection.test_file.name,
                "pair_selection_note": selection.selection_note,
                "encoding_task_accuracy": task_accuracy,
                "n_encoding_trials": len(main_task_rows),
                "n_test_trials": len(main_test_rows),
            }
        )

        for trial_index, row in enumerate(main_task_rows, start=1):
            stim_info = parse_stimulus(row["image_path"], condition=condition, phase="task")
            rt_fast = safe_float(row.get("key_resp_9.rt") or row.get("trials.key_resp_9.rt"))
            rt_slow = safe_float(row.get("key_resp_8.rt") or row.get("trials.key_resp_8.rt"))
            key_fast = row.get("key_resp_9.keys") or row.get("trials.key_resp_9.keys")
            key_slow = row.get("key_resp_8.keys") or row.get("trials.key_resp_8.keys")
            response_key = key_fast if key_fast not in (None, "", "None") else key_slow
            response_rt = rt_fast if not math.isnan(rt_fast) else (3.0 + rt_slow if not math.isnan(rt_slow) else math.nan)
            within_block_position = ((trial_index - 1) % 7) + 1
            boundary_position = "mid"
            if within_block_position == 1:
                boundary_position = "post"
            elif within_block_position == 7:
                boundary_position = "pre"

            bin_map = object_bins if stim_info["stimulus_class"] == "Objects" else scene_bins
            lure_bin = bin_map.get(int(stim_info["item_number"])) if not math.isnan(stim_info["item_number"]) else math.nan

            task_rows.append(
                {
                    "participant_uid": participant_uid,
                    "participant_id": selection.participant_id,
                    "condition": condition,
                    "condition_label": CONDITION_LABELS[condition],
                    "trial_index": trial_index,
                    "block_index": ((trial_index - 1) // 7) + 1,
                    "within_block_position": within_block_position,
                    "boundary_position": boundary_position,
                    "response_key": response_key if response_key not in (None, "", "None") else pd.NA,
                    "response_rt": response_rt,
                    "responded": pd.notna(response_key) and response_key not in ("", "None"),
                    "encoding_task_accuracy": task_accuracy,
                    "lure_bin": lure_bin,
                    **stim_info,
                }
            )

        for trial_index, row in enumerate(main_test_rows, start=1):
            stim_info = parse_stimulus(row["image_path"], condition=condition, phase="test")
            response_key = row.get("key_resp_3.keys")
            response_label = RESPONSE_MAP.get(response_key, pd.NA)
            boundary_position = row.get("position_of_stimuli", "") or "none"
            boundary_position = boundary_position.lower()
            if boundary_position == "none":
                boundary_position = "foil"

            bin_map = object_bins if stim_info["stimulus_class"] == "Objects" else scene_bins
            lure_bin = bin_map.get(int(stim_info["item_number"])) if not math.isnan(stim_info["item_number"]) else math.nan
            expected_response = EXPECTED_RESPONSE[stim_info["item_role"]]

            test_rows.append(
                {
                    "participant_uid": participant_uid,
                    "participant_id": selection.participant_id,
                    "condition": condition,
                    "condition_label": CONDITION_LABELS[condition],
                    "trial_index": trial_index,
                    "test_boundary_position": boundary_position,
                    "response_key": response_key if response_key not in (None, "", "None") else pd.NA,
                    "response_label": response_label,
                    "response_rt": safe_float(row.get("key_resp_3.rt") or row.get("trials.key_resp_3.rt")),
                    "responded": response_key not in (None, "", "None"),
                    "expected_response": expected_response,
                    "correct": response_label == expected_response,
                    "lure_bin": lure_bin,
                    **stim_info,
                }
            )

    return pd.DataFrame(participant_rows), pd.DataFrame(task_rows), pd.DataFrame(test_rows)


def build_data() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    audit_rows: list[dict[str, str]] = []
    participant_frames: list[pd.DataFrame] = []
    task_frames: list[pd.DataFrame] = []
    test_frames: list[pd.DataFrame] = []

    for condition in CONDITION_ORDER:
        selections, audit = select_pairs(CONDITIONS[condition]["folder"])
        audit_rows.extend({"condition": condition, "condition_label": CONDITION_LABELS[condition], **row} for row in audit)
        paired = [selection for selection in selections if selection.task_file and selection.test_file]
        participant_df, task_df, test_df = build_condition_frames(condition, paired)
        participant_frames.append(participant_df)
        task_frames.append(task_df)
        test_frames.append(test_df)

    participants = pd.concat(participant_frames, ignore_index=True)
    task_trials = pd.concat(task_frames, ignore_index=True)
    test_trials = pd.concat(test_frames, ignore_index=True)
    audit_df = pd.DataFrame(audit_rows)

    participants["condition"] = pd.Categorical(participants["condition"], CONDITION_ORDER, ordered=True)
    task_trials["condition"] = pd.Categorical(task_trials["condition"], CONDITION_ORDER, ordered=True)
    test_trials["condition"] = pd.Categorical(test_trials["condition"], CONDITION_ORDER, ordered=True)

    task_trials["boundary_position"] = pd.Categorical(task_trials["boundary_position"], BOUNDARY_ORDER, ordered=True)
    test_trials["test_boundary_position"] = pd.Categorical(
        test_trials["test_boundary_position"], ["post", "mid", "pre", "foil"], ordered=True
    )
    return participants, task_trials, test_trials, audit_df


def summarize_participants(participants: pd.DataFrame, task_trials: pd.DataFrame, test_trials: pd.DataFrame) -> pd.DataFrame:
    encoding_summary = (
        task_trials.groupby(["participant_uid", "condition", "condition_label", "boundary_position"], observed=True)
        .agg(
            mean_encoding_rt=("response_rt", "mean"),
            encoding_response_rate=("responded", "mean"),
        )
        .reset_index()
    )
    encoding_wide = encoding_summary.pivot(
        index=["participant_uid", "condition", "condition_label"],
        columns="boundary_position",
        values=["mean_encoding_rt", "encoding_response_rate"],
    )
    encoding_wide.columns = [f"{metric}_{boundary}" for metric, boundary in encoding_wide.columns]
    encoding_wide = encoding_wide.reset_index()

    foil_summary = (
        test_trials.loc[test_trials["item_role"] == "foil"]
        .assign(
            old_response=lambda df: df["response_label"].eq("old").astype(float),
            similar_response=lambda df: df["response_label"].eq("similar").astype(float),
            new_response=lambda df: df["response_label"].eq("new").astype(float),
        )
        .groupby(["participant_uid", "condition", "condition_label"], observed=True)
        .agg(
            foil_old_rate=("old_response", "mean"),
            foil_similar_rate=("similar_response", "mean"),
            foil_new_rate=("new_response", "mean"),
            test_response_rate=("responded", "mean"),
            mean_test_rt=("response_rt", "mean"),
        )
        .reset_index()
    )

    target_summary = (
        test_trials.loc[test_trials["item_role"] == "target"]
        .assign(old_response=lambda df: df["response_label"].eq("old").astype(float))
        .groupby(["participant_uid", "condition", "condition_label", "test_boundary_position"], observed=True)
        .agg(target_old_rate=("old_response", "mean"), target_accuracy=("correct", "mean"))
        .reset_index()
    )
    target_wide = target_summary.pivot(
        index=["participant_uid", "condition", "condition_label"],
        columns="test_boundary_position",
        values=["target_old_rate", "target_accuracy"],
    )
    target_wide.columns = [f"{metric}_{boundary}" for metric, boundary in target_wide.columns]
    target_wide = target_wide.reset_index()

    lure_summary = (
        test_trials.loc[test_trials["item_role"] == "lure"]
        .assign(
            similar_response=lambda df: df["response_label"].eq("similar").astype(float),
            reject_response=lambda df: df["response_label"].isin(["similar", "new"]).astype(float),
        )
        .groupby(["participant_uid", "condition", "condition_label", "test_boundary_position"], observed=True)
        .agg(
            lure_similar_rate=("similar_response", "mean"),
            lure_reject_rate=("reject_response", "mean"),
            lure_accuracy=("correct", "mean"),
        )
        .reset_index()
    )
    lure_wide = lure_summary.pivot(
        index=["participant_uid", "condition", "condition_label"],
        columns="test_boundary_position",
        values=["lure_similar_rate", "lure_reject_rate", "lure_accuracy"],
    )
    lure_wide.columns = [f"{metric}_{boundary}" for metric, boundary in lure_wide.columns]
    lure_wide = lure_wide.reset_index()

    participant_level = (
        participants.merge(encoding_wide, on=["participant_uid", "condition", "condition_label"], how="left")
        .merge(foil_summary, on=["participant_uid", "condition", "condition_label"], how="left")
        .merge(target_wide, on=["participant_uid", "condition", "condition_label"], how="left")
        .merge(lure_wide, on=["participant_uid", "condition", "condition_label"], how="left")
    )

    for boundary in BOUNDARY_ORDER:
        participant_level[f"REC_{boundary}"] = (
            participant_level[f"target_old_rate_{boundary}"] - participant_level["foil_old_rate"]
        )
        participant_level[f"LDI_{boundary}"] = (
            participant_level[f"lure_similar_rate_{boundary}"] - participant_level["foil_similar_rate"]
        )
        participant_level[f"ALT_LDI_{boundary}"] = (
            participant_level[f"lure_reject_rate_{boundary}"] - participant_level["foil_old_rate"]
        )

    participant_level["rt_post_cost"] = participant_level["mean_encoding_rt_post"] - participant_level["mean_encoding_rt_mid"]
    participant_level["rt_pre_advantage"] = participant_level["mean_encoding_rt_pre"] - participant_level["mean_encoding_rt_mid"]
    participant_level["REC_post_cost"] = participant_level["REC_post"] - participant_level["REC_mid"]
    participant_level["REC_pre_change"] = participant_level["REC_pre"] - participant_level["REC_mid"]
    participant_level["LDI_pre_gain"] = participant_level["LDI_pre"] - participant_level["LDI_mid"]
    participant_level["LDI_post_change"] = participant_level["LDI_post"] - participant_level["LDI_mid"]
    participant_level["ALT_LDI_pre_gain"] = participant_level["ALT_LDI_pre"] - participant_level["ALT_LDI_mid"]
    return participant_level


def describe_wide(participant_level: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    sample_overview = (
        participant_level.groupby(["condition", "condition_label"], observed=True)
        .agg(
            participants=("participant_uid", "nunique"),
            task_accuracy_n=("encoding_task_accuracy", "count"),
            mean_task_accuracy=("encoding_task_accuracy", "mean"),
            sd_task_accuracy=("encoding_task_accuracy", "std"),
            mean_encoding_response_rate=("encoding_response_rate_mid", "mean"),
            mean_test_response_rate=("test_response_rate", "mean"),
        )
        .reset_index()
    )

    encoding_long = participant_level.melt(
        id_vars=["participant_uid", "condition", "condition_label"],
        value_vars=[f"mean_encoding_rt_{boundary}" for boundary in BOUNDARY_ORDER],
        var_name="metric",
        value_name="mean_encoding_rt",
    )
    encoding_long["boundary_position"] = encoding_long["metric"].str.rsplit("_", n=1).str[-1]
    encoding_descriptives = (
        encoding_long.groupby(["condition", "condition_label", "boundary_position"], observed=True)["mean_encoding_rt"]
        .agg(["mean", "std", "median"])
        .reset_index()
    )

    memory_rows: list[dict[str, object]] = []
    for metric in ("REC", "LDI"):
        for boundary in BOUNDARY_ORDER:
            values = participant_level[["condition", "condition_label", f"{metric}_{boundary}"]].rename(
                columns={f"{metric}_{boundary}": "value"}
            )
            values["metric"] = metric
            values["boundary_position"] = boundary
            memory_rows.append(values)
    memory_long = pd.concat(memory_rows, ignore_index=True)
    memory_descriptives = (
        memory_long.groupby(["condition", "condition_label", "metric", "boundary_position"], observed=True)["value"]
        .agg(["mean", "std", "median"])
        .reset_index()
    )
    return sample_overview, encoding_descriptives, memory_descriptives


def run_within_condition_tests(participant_level: pd.DataFrame) -> pd.DataFrame:
    records: list[dict[str, object]] = []
    paired_records: list[dict[str, object]] = []

    metric_specs = {
        "encoding_rt": {
            "columns": [f"mean_encoding_rt_{boundary}" for boundary in BOUNDARY_ORDER],
            "column_template": "mean_encoding_rt_{boundary}",
        },
        "REC": {
            "columns": [f"REC_{boundary}" for boundary in BOUNDARY_ORDER],
            "column_template": "REC_{boundary}",
        },
        "LDI": {
            "columns": [f"LDI_{boundary}" for boundary in BOUNDARY_ORDER],
            "column_template": "LDI_{boundary}",
        },
        "ALT_LDI": {
            "columns": [f"ALT_LDI_{boundary}" for boundary in BOUNDARY_ORDER],
            "column_template": "ALT_LDI_{boundary}",
        },
    }

    for condition in CONDITION_ORDER:
        subset = participant_level.loc[participant_level["condition"] == condition].copy()
        for metric, spec in metric_specs.items():
            columns = spec["columns"]
            long_df = subset[["participant_uid", *columns]].melt(
                id_vars="participant_uid", var_name="metric_name", value_name="value"
            )
            long_df["boundary_position"] = long_df["metric_name"].str.rsplit("_", n=1).str[-1]
            long_df = long_df.dropna(subset=["value"])
            anova = AnovaRM(long_df, depvar="value", subject="participant_uid", within=["boundary_position"]).fit()
            anova_table = anova.anova_table.reset_index().rename(columns={"index": "effect"})
            effect_row = anova_table.iloc[0]
            records.append(
                {
                    "analysis_family": "within_condition_anova",
                    "condition": condition,
                    "condition_label": CONDITION_LABELS[condition],
                    "metric": metric,
                    "test": "AnovaRM",
                    "effect": effect_row["effect"],
                    "num_df": effect_row["Num DF"],
                    "den_df": effect_row["Den DF"],
                    "f_value": effect_row["F Value"],
                    "p_value": effect_row["Pr > F"],
                }
            )

            pairwise_p = []
            pairwise_results: list[dict[str, object]] = []
            for left, right in combinations(BOUNDARY_ORDER, 2):
                left_values = subset[spec["column_template"].format(boundary=left)].to_numpy(dtype=float)
                right_values = subset[spec["column_template"].format(boundary=right)].to_numpy(dtype=float)
                mask = np.isfinite(left_values) & np.isfinite(right_values)
                t_stat, p_value = stats.ttest_rel(left_values[mask], right_values[mask])
                diff = left_values[mask] - right_values[mask]
                dz = diff.mean() / diff.std(ddof=1) if len(diff) > 1 and diff.std(ddof=1) > 0 else math.nan
                pairwise_p.append(p_value)
                pairwise_results.append(
                    {
                        "analysis_family": "within_condition_pairwise",
                        "condition": condition,
                        "condition_label": CONDITION_LABELS[condition],
                        "metric": metric,
                        "test": "paired_t",
                        "contrast": f"{left} - {right}",
                        "n": int(mask.sum()),
                        "mean_difference": diff.mean(),
                        "t_value": t_stat,
                        "p_value": p_value,
                        "cohens_dz": dz,
                    }
                )
            corrected = multipletests(pairwise_p, method="holm")
            for result, corrected_p, reject in zip(pairwise_results, corrected[1], corrected[0]):
                result["p_value_holm"] = corrected_p
                result["reject_holm"] = bool(reject)
                paired_records.append(result)

    return pd.concat([pd.DataFrame(records), pd.DataFrame(paired_records)], ignore_index=True)


def run_between_condition_tests(participant_level: pd.DataFrame) -> pd.DataFrame:
    records: list[dict[str, object]] = []
    contrast_specs = {
        "rt_post_cost": "post-minus-mid encoding RT",
        "REC_post_cost": "post-minus-mid REC",
        "LDI_pre_gain": "pre-minus-mid LDI",
    }
    for contrast, description in contrast_specs.items():
        groups = [
            participant_level.loc[participant_level["condition"] == condition, contrast].dropna().to_numpy()
            for condition in CONDITION_ORDER
        ]
        f_stat, p_value = stats.f_oneway(*groups)
        records.append(
            {
                "analysis_family": "between_condition_anova",
                "metric": contrast,
                "description": description,
                "test": "one_way_anova",
                "f_value": f_stat,
                "p_value": p_value,
            }
        )

        pairwise_p = []
        pairwise_results: list[dict[str, object]] = []
        for left, right in combinations(CONDITION_ORDER, 2):
            left_values = participant_level.loc[participant_level["condition"] == left, contrast].dropna().to_numpy()
            right_values = participant_level.loc[participant_level["condition"] == right, contrast].dropna().to_numpy()
            t_stat, p_pair = stats.ttest_ind(left_values, right_values, equal_var=False)
            pooled = np.sqrt(((left_values.var(ddof=1) + right_values.var(ddof=1)) / 2))
            d_value = (left_values.mean() - right_values.mean()) / pooled if pooled > 0 else math.nan
            pairwise_p.append(p_pair)
            pairwise_results.append(
                {
                    "analysis_family": "between_condition_pairwise",
                    "metric": contrast,
                    "description": description,
                    "test": "welch_t",
                    "contrast": f"{CONDITION_LABELS[left]} - {CONDITION_LABELS[right]}",
                    "t_value": t_stat,
                    "p_value": p_pair,
                    "cohens_d": d_value,
                }
            )
        corrected = multipletests(pairwise_p, method="holm")
        for result, corrected_p, reject in zip(pairwise_results, corrected[1], corrected[0]):
            result["p_value_holm"] = corrected_p
            result["reject_holm"] = bool(reject)
            records.append(result)
    return pd.DataFrame(records)


def build_response_profile(test_trials: pd.DataFrame) -> pd.DataFrame:
    working = test_trials.copy()
    working["item_label"] = np.where(
        working["item_role"] == "foil",
        "Foil",
        working["item_role"].str.capitalize() + " (" + working["test_boundary_position"].map(BOUNDARY_LABELS) + ")",
    )
    response_profile = (
        working.groupby(["condition", "condition_label", "item_label", "response_label"], observed=True)
        .size()
        .reset_index(name="count")
    )
    totals = response_profile.groupby(["condition", "item_label"], observed=True)["count"].transform("sum")
    response_profile["proportion"] = response_profile["count"] / totals
    return response_profile


def build_lure_bin_summary(test_trials: pd.DataFrame) -> pd.DataFrame:
    lure_trials = test_trials.loc[test_trials["item_role"] == "lure"].copy()
    lure_trials["similar_response"] = lure_trials["response_label"].eq("similar").astype(float)
    lure_bin_summary = (
        lure_trials.groupby(
            ["participant_uid", "condition", "condition_label", "test_boundary_position", "lure_bin"], observed=True
        )["similar_response"]
        .mean()
        .reset_index()
    )
    return lure_bin_summary


def save_tables(
    audit_df: pd.DataFrame,
    participants: pd.DataFrame,
    task_trials: pd.DataFrame,
    test_trials: pd.DataFrame,
    participant_level: pd.DataFrame,
    sample_overview: pd.DataFrame,
    encoding_descriptives: pd.DataFrame,
    memory_descriptives: pd.DataFrame,
    within_tests: pd.DataFrame,
    between_tests: pd.DataFrame,
    response_profile: pd.DataFrame,
    lure_bin_summary: pd.DataFrame,
) -> None:
    audit_df.to_csv(OUTPUT_DIR / "pairing_audit.csv", index=False)
    participants.to_csv(OUTPUT_DIR / "participants.csv", index=False)
    task_trials.to_csv(OUTPUT_DIR / "encoding_trials.csv", index=False)
    test_trials.to_csv(OUTPUT_DIR / "test_trials.csv", index=False)
    participant_level.to_csv(OUTPUT_DIR / "participant_level_metrics.csv", index=False)
    sample_overview.to_csv(TABLE_DIR / "sample_overview.csv", index=False)
    encoding_descriptives.to_csv(TABLE_DIR / "encoding_descriptives.csv", index=False)
    memory_descriptives.to_csv(TABLE_DIR / "memory_descriptives.csv", index=False)
    within_tests.to_csv(TABLE_DIR / "within_condition_tests.csv", index=False)
    between_tests.to_csv(TABLE_DIR / "between_condition_tests.csv", index=False)
    response_profile.to_csv(TABLE_DIR / "response_profile.csv", index=False)
    lure_bin_summary.to_csv(TABLE_DIR / "lure_bin_summary.csv", index=False)


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
            "xtick.labelsize": 11,
            "ytick.labelsize": 11,
            "legend.fontsize": 10,
        }
    )


def facet_title(ax: plt.Axes, condition: str) -> None:
    ax.set_title(CONDITION_LABELS[condition], color=CONDITION_PALETTE[condition], fontweight="bold")


def plot_sample_overview(audit_df: pd.DataFrame, participant_level: pd.DataFrame) -> None:
    sample_counts = (
        participant_level.groupby(["condition", "condition_label"], observed=True)["participant_uid"]
        .nunique()
        .reset_index(name="participants")
    )
    resolution_counts = (
        audit_df.groupby(["condition_label", "selection_note"], observed=True)
        .size()
        .reset_index(name="count")
    )

    fig, axes = plt.subplots(1, 2, figsize=(12.5, 5.5), gridspec_kw={"width_ratios": [1.1, 1.4]})
    sns.barplot(
        data=sample_counts,
        x="condition_label",
        y="participants",
        hue="condition_label",
        dodge=False,
        palette=[CONDITION_PALETTE[condition] for condition in CONDITION_ORDER],
        ax=axes[0],
    )
    axes[0].set_xlabel("")
    axes[0].set_ylabel("Participants with complete task-test pairs")
    axes[0].tick_params(axis="x", rotation=18)
    if axes[0].legend_ is not None:
        axes[0].legend_.remove()

    resolution_pivot = resolution_counts.pivot(index="condition_label", columns="selection_note", values="count").fillna(0)
    resolution_pivot = resolution_pivot.loc[[CONDITION_LABELS[condition] for condition in CONDITION_ORDER]]
    sns.heatmap(
        resolution_pivot,
        annot=True,
        fmt=".0f",
        cmap=sns.light_palette("#355c7d", as_cmap=True),
        cbar=False,
        linewidths=0.6,
        linecolor="white",
        ax=axes[1],
    )
    axes[1].set_xlabel("File pairing status")
    axes[1].set_ylabel("")
    axes[1].set_title("File pairing audit")
    fig.suptitle("Dataset overview", fontsize=18, fontweight="bold", x=0.42)
    fig.savefig(FIG_DIR / "phase1_dataset_overview.png")
    plt.close(fig)


def plot_encoding_rt(participant_level: pd.DataFrame) -> None:
    long_df = participant_level.melt(
        id_vars=["participant_uid", "condition", "condition_label"],
        value_vars=[f"mean_encoding_rt_{boundary}" for boundary in BOUNDARY_ORDER],
        var_name="metric",
        value_name="value",
    )
    long_df["boundary_position"] = long_df["metric"].str.rsplit("_", n=1).str[-1]
    long_df["boundary_label"] = long_df["boundary_position"].map(BOUNDARY_LABELS)

    fig, axes = plt.subplots(1, 3, figsize=(14.5, 4.8), sharey=True)
    for ax, condition in zip(axes, CONDITION_ORDER):
        subset = long_df.loc[long_df["condition"] == condition].copy()
        pivot = subset.pivot(index="participant_uid", columns="boundary_position", values="value")
        for _, row in pivot.iterrows():
            ax.plot(BOUNDARY_ORDER, row[BOUNDARY_ORDER], color="#adb5bd", linewidth=0.8, alpha=0.28, zorder=1)
        sns.pointplot(
            data=subset,
            x="boundary_position",
            y="value",
            order=BOUNDARY_ORDER,
            palette=BOUNDARY_PALETTE,
            errorbar=("ci", 95),
            join=False,
            markers="o",
            scale=1.1,
            err_kws={"linewidth": 1.4},
            ax=ax,
        )
        ax.set_xticklabels([BOUNDARY_LABELS[item] for item in BOUNDARY_ORDER], rotation=18)
        ax.set_xlabel("")
        facet_title(ax, condition)
        ax.grid(axis="y", alpha=0.2)
    axes[0].set_ylabel("Encoding RT (s)")
    axes[1].set_ylabel("")
    axes[2].set_ylabel("")
    fig.suptitle("Encoding responses slowed after event boundaries", fontsize=18, fontweight="bold")
    fig.savefig(FIG_DIR / "phase1_encoding_rt.png")
    plt.close(fig)


def plot_memory_indices(participant_level: pd.DataFrame) -> None:
    frames = []
    for metric in ("REC", "LDI"):
        frame = participant_level.melt(
            id_vars=["participant_uid", "condition", "condition_label"],
            value_vars=[f"{metric}_{boundary}" for boundary in BOUNDARY_ORDER],
            var_name="metric_name",
            value_name="value",
        )
        frame["metric"] = metric
        frame["boundary_position"] = frame["metric_name"].str.rsplit("_", n=1).str[-1]
        frames.append(frame)
    long_df = pd.concat(frames, ignore_index=True)

    fig, axes = plt.subplots(1, 2, figsize=(13.8, 5.2), sharex=True)
    for ax, metric in zip(axes, ["REC", "LDI"]):
        subset = long_df.loc[long_df["metric"] == metric]
        sns.pointplot(
            data=subset,
            x="boundary_position",
            y="value",
            hue="condition",
            order=BOUNDARY_ORDER,
            hue_order=CONDITION_ORDER,
            palette=CONDITION_PALETTE,
            errorbar=("ci", 95),
            dodge=0.18,
            markers=["o", "s", "D"],
            linestyles="-",
            ax=ax,
        )
        ax.set_xticklabels([BOUNDARY_LABELS[item] for item in BOUNDARY_ORDER], rotation=18)
        ax.set_xlabel("")
        ax.grid(axis="y", alpha=0.2)
        ax.set_title("Recognition memory index (REC)" if metric == "REC" else "Lure discrimination index (LDI)")
        if metric == "REC":
            ax.set_ylabel("Bias-corrected score")
        else:
            ax.set_ylabel("")
        if ax.legend_ is not None:
            ax.legend_.remove()
    handles, labels = axes[0].get_legend_handles_labels()
    fig.legend(
        handles,
        [CONDITION_LABELS[label] for label in labels],
        title="Condition",
        loc="lower center",
        bbox_to_anchor=(0.5, 0.01),
        ncol=3,
        frameon=False,
        columnspacing=1.6,
        handletextpad=0.6,
    )
    fig.suptitle("Memory effects depended on both boundary timing and task design", fontsize=18, fontweight="bold")
    fig.tight_layout(rect=(0, 0.10, 1, 0.92))
    fig.savefig(FIG_DIR / "phase1_memory_indices.png")
    plt.close(fig)


def plot_response_profile(response_profile: pd.DataFrame) -> None:
    item_order = [
        "Target (Post-boundary)",
        "Target (Mid-event)",
        "Target (Pre-boundary)",
        "Lure (Post-boundary)",
        "Lure (Mid-event)",
        "Lure (Pre-boundary)",
        "Foil",
    ]
    response_order = ["old", "similar", "new"]
    fig, axes = plt.subplots(1, 3, figsize=(15, 6), sharey=True)
    for ax, condition in zip(axes, CONDITION_ORDER):
        subset = response_profile.loc[response_profile["condition"] == condition]
        pivot = subset.pivot(index="item_label", columns="response_label", values="proportion").reindex(
            index=item_order, columns=response_order
        )
        sns.heatmap(
            pivot,
            annot=True,
            fmt=".2f",
            cmap=sns.blend_palette(["#f7f4ea", CONDITION_PALETTE[condition]], as_cmap=True),
            linewidths=0.6,
            linecolor="white",
            cbar=ax is axes[-1],
            ax=ax,
        )
        facet_title(ax, condition)
        ax.set_xlabel("Response")
        if ax is axes[0]:
            ax.set_ylabel("Test item type")
        else:
            ax.set_ylabel("")
    fig.suptitle("Participants mostly used the expected response categories", fontsize=18, fontweight="bold")
    fig.savefig(FIG_DIR / "phase1_response_profiles.png")
    plt.close(fig)


def plot_lure_bins(lure_bin_summary: pd.DataFrame) -> None:
    fig, axes = plt.subplots(1, 3, figsize=(14.5, 4.8), sharey=True)
    for ax, condition in zip(axes, CONDITION_ORDER):
        subset = lure_bin_summary.loc[lure_bin_summary["condition"] == condition]
        sns.pointplot(
            data=subset,
            x="lure_bin",
            y="similar_response",
            hue="test_boundary_position",
            hue_order=BOUNDARY_ORDER,
            palette=BOUNDARY_PALETTE,
            errorbar=("ci", 95),
            dodge=0.15,
            markers=["o", "s", "D"],
            linestyles="-",
            ax=ax,
        )
        facet_title(ax, condition)
        ax.set_xlabel("Lure bin (1 = most similar, 5 = least similar)")
        ax.set_ylim(0.0, 1.0)
        ax.grid(axis="y", alpha=0.2)
        if ax is axes[0]:
            ax.set_ylabel("P(similar | lure)")
        else:
            ax.set_ylabel("")
    handles, labels = axes[0].get_legend_handles_labels()
    axes[0].legend_.remove()
    axes[1].legend_.remove()
    axes[2].legend(handles, [BOUNDARY_LABELS[label] for label in labels], title="Encoding position", frameon=False)
    fig.suptitle("Lure discrimination improved as lure similarity decreased", fontsize=18, fontweight="bold")
    fig.savefig(FIG_DIR / "phase1_lure_bins.png")
    plt.close(fig)


def build_report_numbers(
    participant_level: pd.DataFrame,
    sample_overview: pd.DataFrame,
    within_tests: pd.DataFrame,
    between_tests: pd.DataFrame,
) -> None:
    lookup = {
        "n_item_only": int(sample_overview.loc[sample_overview["condition"] == "item_only", "participants"].iloc[0]),
        "n_both": int(sample_overview.loc[sample_overview["condition"] == "both", "participants"].iloc[0]),
        "n_task_only": int(sample_overview.loc[sample_overview["condition"] == "task_only", "participants"].iloc[0]),
        "task_acc_item_only": float(sample_overview.loc[sample_overview["condition"] == "item_only", "mean_task_accuracy"].iloc[0]),
        "task_acc_both": float(sample_overview.loc[sample_overview["condition"] == "both", "mean_task_accuracy"].iloc[0]),
        "task_acc_task_only": float(sample_overview.loc[sample_overview["condition"] == "task_only", "mean_task_accuracy"].iloc[0]),
        "rt_post_cost_both": float(participant_level.loc[participant_level["condition"] == "both", "rt_post_cost"].mean()),
        "rec_post_cost_both": float(participant_level.loc[participant_level["condition"] == "both", "REC_post_cost"].mean()),
        "ldi_pre_gain_both": float(participant_level.loc[participant_level["condition"] == "both", "LDI_pre_gain"].mean()),
    }

    for condition, metric in [("both", "encoding_rt"), ("both", "REC"), ("both", "LDI")]:
        row = within_tests.loc[
            (within_tests["analysis_family"] == "within_condition_anova")
            & (within_tests["condition"] == condition)
            & (within_tests["metric"] == metric)
        ].iloc[0]
        lookup[f"{condition}_{metric}_f"] = float(row["f_value"])
        lookup[f"{condition}_{metric}_p"] = float(row["p_value"])

    between_row = between_tests.loc[
        (between_tests["analysis_family"] == "between_condition_anova") & (between_tests["metric"] == "LDI_pre_gain")
    ].iloc[0]
    lookup["between_ldi_f"] = float(between_row["f_value"])
    lookup["between_ldi_p"] = float(between_row["p_value"])

    with (OUTPUT_DIR / "report_numbers.json").open("w") as handle:
        json.dump(lookup, handle, indent=2)


def main() -> None:
    ensure_dirs()
    set_plot_theme()

    participants, task_trials, test_trials, audit_df = build_data()
    participant_level = summarize_participants(participants, task_trials, test_trials)
    sample_overview, encoding_descriptives, memory_descriptives = describe_wide(participant_level)
    within_tests = run_within_condition_tests(participant_level)
    between_tests = run_between_condition_tests(participant_level)
    response_profile = build_response_profile(test_trials)
    lure_bin_summary = build_lure_bin_summary(test_trials)

    save_tables(
        audit_df,
        participants,
        task_trials,
        test_trials,
        participant_level,
        sample_overview,
        encoding_descriptives,
        memory_descriptives,
        within_tests,
        between_tests,
        response_profile,
        lure_bin_summary,
    )
    build_report_numbers(participant_level, sample_overview, within_tests, between_tests)

    plot_sample_overview(audit_df, participant_level)
    plot_encoding_rt(participant_level)
    plot_memory_indices(participant_level)
    plot_response_profile(response_profile)
    plot_lure_bins(lure_bin_summary)

    print("Saved analysis outputs to", OUTPUT_DIR)
    print("Saved report figures to", FIG_DIR)
    print("Saved report tables to", TABLE_DIR)


if __name__ == "__main__":
    main()
