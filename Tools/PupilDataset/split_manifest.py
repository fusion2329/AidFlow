#!/usr/bin/env python3
"""Create train/val/test splits for a pupil manifest."""

from __future__ import annotations

import argparse
import csv
import random
from collections import defaultdict
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="Input manifest CSV")
    parser.add_argument("--output", required=True, type=Path, help="Output manifest CSV with split column")
    parser.add_argument("--group-column", default="capture_id", help="Column used to prevent leakage")
    parser.add_argument("--train", default=0.70, type=float, help="Train ratio")
    parser.add_argument("--val", default=0.15, type=float, help="Validation ratio")
    parser.add_argument("--test", default=0.15, type=float, help="Test ratio")
    parser.add_argument("--seed", default=42, type=int, help="Deterministic random seed")
    return parser.parse_args()


def choose_split(index: int, total: int, train_ratio: float, val_ratio: float) -> str:
    fraction = index / max(total, 1)
    if fraction < train_ratio:
        return "train"
    if fraction < train_ratio + val_ratio:
        return "val"
    return "test"


def main() -> None:
    args = parse_args()
    ratio_sum = args.train + args.val + args.test
    if abs(ratio_sum - 1.0) > 0.0001:
        raise SystemExit(f"Ratios must sum to 1.0, got {ratio_sum}")

    input_path = args.input.expanduser().resolve()
    output_path = args.output.expanduser().resolve()
    with input_path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        fieldnames = list(reader.fieldnames or [])

    groups: dict[str, list[int]] = defaultdict(list)
    for index, row in enumerate(rows):
        group_value = row.get(args.group_column) or row.get("image_file") or str(index)
        groups[group_value].append(index)

    group_keys = sorted(groups)
    random.Random(args.seed).shuffle(group_keys)
    split_by_group = {
        key: choose_split(i, len(group_keys), args.train, args.val)
        for i, key in enumerate(group_keys)
    }

    for key, indexes in groups.items():
        split = split_by_group[key]
        for index in indexes:
            rows[index]["split"] = split

    if "split" not in fieldnames:
        fieldnames.append("split")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    counts = {"train": 0, "val": 0, "test": 0}
    for row in rows:
        counts[row["split"]] += 1
    print(f"Wrote {output_path}: train={counts['train']} val={counts['val']} test={counts['test']}")


if __name__ == "__main__":
    main()
