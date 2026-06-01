# Pupil Annotation Guidelines

## Goal

Create consistent pupil masks for segmentation training. The model should learn the pupil aperture, not the full iris.

## Primary mask

Label exactly one class:

- `pupil`

Mask the dark pupil opening. Do not include iris, eyelid, sclera, eyelashes, glasses frame, or reflection outside the pupil.

## Difficult cases

- Small catchlight inside the pupil: label the full estimated pupil boundary and include the catchlight inside the mask.
- Large reflection hiding the boundary: mark the frame `uncertain_boundary`; label only if the boundary is still defensible.
- Eyelid cuts across pupil: mark `occluded`; label only the visible pupil if the complete boundary cannot be inferred.
- Motion blur or focus blur: mark `blurred`; skip mask if the edge is not clear.
- Closed or nearly closed eye: mark `closed_eye`; do not label a pupil mask.
- Off-center ROI but visible pupil: mark `off_center`; label the pupil if visible.
- Glasses glare: mark `glare`; label only if the pupil edge remains clear.

## Quality tags

Use these frame-level tags:

- `valid`: clear enough for segmentation training
- `blurred`: focus or motion blur
- `glare`: specular reflection disrupts the pupil/iris boundary
- `occluded`: eyelid, lashes, hair, or glasses obscure the pupil
- `off_center`: pupil is near the ROI edge
- `closed_eye`: eye is closed or pupil is not visible
- `uncertain_boundary`: annotator cannot confidently trace the pupil boundary

## Train/validation policy

Keep all frames from the same `capture_id` in one split. Do not let baseline frames from a capture enter training while reaction frames from the same capture enter validation or test.

## Rejection policy

Do not force a label. Bad frames are valuable for quality/rejection models, but poor masks will damage the segmentation model.
