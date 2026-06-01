#!/usr/bin/env python3
"""Build a CSV manifest from AidFlow pupil training frame JSON files."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any


COLUMNS = [
    "image_file",
    "image_path",
    "image_exists",
    "metadata_file",
    "schema_version",
    "recorded_at",
    "capture_id",
    "capture_mode",
    "capture_phase",
    "elapsed_seconds",
    "torch_is_on",
    "eye",
    "distance_centimeters",
    "frame_width",
    "frame_height",
    "roi_x",
    "roi_y",
    "roi_width",
    "roi_height",
    "brightness",
    "pupil_diameter_pixels",
    "segmentation_quality",
    "eye_detection_quality",
    "sharpness_quality",
    "glare_ratio",
    "occlusion_risk",
    "measurement_quality",
    "center_offset",
    "used_neural_segmentation",
    "neural_model_available",
    "accepted_for_training",
    "quality_bucket",
    "recommended_task",
    "annotation_status",
    "pupil_mask_path",
    "quality_tags",
    "exclude_reason",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="PupilTrainingFrames folder")
    parser.add_argument("--output", required=True, type=Path, help="Output CSV manifest path")
    parser.add_argument(
        "--relative-to",
        type=Path,
        default=None,
        help="Write image/metadata paths relative to this directory",
    )
    return parser.parse_args()


def value(data: dict[str, Any], key: str, default: Any = "") -> Any:
    result = data.get(key, default)
    return default if result is None else result


def bool_text(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if value in ("true", "false"):
        return value
    return ""


def number(data: dict[str, Any], key: str) -> str:
    result = data.get(key)
    if isinstance(result, (int, float)):
        return f"{float(result):.6g}"
    return ""


def path_text(path: Path, relative_to: Path | None) -> str:
    if relative_to is None:
        return str(path)
    try:
        return str(path.relative_to(relative_to))
    except ValueError:
        return str(path)


def quality_bucket(data: dict[str, Any]) -> str:
    accepted = data.get("acceptedForTraining")
    quality = data.get("measurementQuality")
    if accepted is False:
        return "reject"
    if not isinstance(quality, (int, float)):
        return "unknown"
    if quality >= 0.66:
        return "high"
    if quality >= 0.38:
        return "medium"
    return "low"


def recommended_task(data: dict[str, Any], image_exists: bool) -> str:
    if not image_exists:
        return "missing_image"
    if data.get("acceptedForTraining") is False:
        return "quality_review"
    phase = data.get("capturePhase", "")
    if phase in ("baseline", "reaction", "livePreview"):
        return "segmentation"
    return "review"


def row_for(json_path: Path, input_root: Path, relative_to: Path | None) -> dict[str, str]:
    with json_path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError("metadata JSON root is not an object")

    image_file = str(value(data, "imageFile"))
    image_path = json_path.parent / image_file if image_file else json_path.with_suffix(".png")
    image_exists = image_path.exists()

    row = {
        "image_file": image_file,
        "image_path": path_text(image_path, relative_to),
        "image_exists": "true" if image_exists else "false",
        "metadata_file": path_text(json_path, relative_to),
        "schema_version": str(value(data, "schemaVersion", 1)),
        "recorded_at": str(value(data, "recordedAt")),
        "capture_id": str(value(data, "captureID")),
        "capture_mode": str(value(data, "captureMode")),
        "capture_phase": str(value(data, "capturePhase", "unknown")),
        "elapsed_seconds": number(data, "elapsedSeconds"),
        "torch_is_on": bool_text(data.get("torchIsOn")),
        "eye": str(value(data, "eye")),
        "distance_centimeters": number(data, "distanceCentimeters"),
        "frame_width": str(value(data, "frameWidth")),
        "frame_height": str(value(data, "frameHeight")),
        "roi_x": number(data, "roiX"),
        "roi_y": number(data, "roiY"),
        "roi_width": number(data, "roiWidth"),
        "roi_height": number(data, "roiHeight"),
        "brightness": number(data, "brightness"),
        "pupil_diameter_pixels": number(data, "pupilDiameterPixels"),
        "segmentation_quality": number(data, "segmentationQuality"),
        "eye_detection_quality": number(data, "eyeDetectionQuality"),
        "sharpness_quality": number(data, "sharpnessQuality"),
        "glare_ratio": number(data, "glareRatio"),
        "occlusion_risk": number(data, "occlusionRisk"),
        "measurement_quality": number(data, "measurementQuality"),
        "center_offset": number(data, "centerOffset"),
        "used_neural_segmentation": bool_text(data.get("usedNeuralSegmentation")),
        "neural_model_available": bool_text(data.get("neuralModelAvailable")),
        "accepted_for_training": bool_text(data.get("acceptedForTraining")),
        "quality_bucket": quality_bucket(data),
        "recommended_task": recommended_task(data, image_exists),
        "annotation_status": "",
        "pupil_mask_path": "",
        "quality_tags": "",
        "exclude_reason": "",
    }
    return row


def main() -> None:
    args = parse_args()
    input_root = args.input.expanduser().resolve()
    output_path = args.output.expanduser().resolve()
    relative_to = args.relative_to.expanduser().resolve() if args.relative_to else None

    json_files = sorted(input_root.rglob("*.json"))
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with output_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=COLUMNS)
        writer.writeheader()
        written = 0
        skipped = 0
        for json_path in json_files:
            try:
                writer.writerow(row_for(json_path, input_root, relative_to))
                written += 1
            except (OSError, ValueError, json.JSONDecodeError) as error:
                skipped += 1
                print(f"Skipping {json_path}: {error}")

    print(f"Wrote {output_path}: rows={written} scanned={len(json_files)} skipped={skipped}.")


if __name__ == "__main__":
    main()
