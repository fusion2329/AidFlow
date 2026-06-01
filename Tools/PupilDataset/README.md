# Pupil Dataset Tooling

This folder turns AidFlow Developer Mode captures into a dataset that can be labeled and used for pupil segmentation training.

## Capture

In AidFlow:

1. Enable Developer Mode in Settings.
2. Open Home -> Tools -> Pupil Reaction Check.
3. Enable `Collect ML frames`.
4. Capture several left/right eye checks under varied conditions.
5. Export the app container or copy Application Support:

`AidFlow/PupilTrainingFrames`

Each saved sample has:

- `*.png`: cropped eye ROI
- `*.json`: frame metadata, including quality, capture phase, torch state, distance, and ROI geometry

These images are sensitive. Collect only with explicit consent and store them locally unless consent covers export.

## Build a manifest

```bash
python3 Tools/PupilDataset/build_manifest.py \
  --input /path/to/PupilTrainingFrames \
  --output /path/to/pupil_manifest.csv
```

The manifest contains one row per ROI image and keeps blank annotation columns for later mask paths.

## Split the dataset

```bash
python3 Tools/PupilDataset/split_manifest.py \
  --input /path/to/pupil_manifest.csv \
  --output /path/to/pupil_manifest_split.csv
```

The splitter groups by `capture_id` when available, so frames from one capture stay in the same split.

## Labeling

Use CVAT or another mask-capable annotation tool.

Primary label:

- `pupil`: visible pupil aperture mask

Frame-level tags:

- `valid`
- `blurred`
- `glare`
- `occluded`
- `off_center`
- `closed_eye`
- `uncertain_boundary`

Read `annotation_guidelines.md` before labeling. Consistent labels matter more than labeling every frame.

## Training target

V1 model contract:

- input: cropped eye ROI, fixed size such as 192x128
- output: one-channel pupil probability mask
- model name in app bundle: `PupilSegmentation.mlmodelc`

The app will automatically use the bundled Core ML model when present and fall back to classical CV when absent.
