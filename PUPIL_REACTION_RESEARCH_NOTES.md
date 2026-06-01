# AidFlow Pupil Reaction Check: Research And ML Notes

This tool is a field observation aid, not a diagnostic pupillometer. It must reject poor measurements aggressively and allow manual correction before saving.

## Medical and measurement anchors

- Adult pupil diameter is commonly described as about 2-4 mm in bright light and 4-8 mm in the dark. AidFlow should treat absolute millimeter estimates as approximate unless the device has strong distance/scale calibration.
- A useful pupil check needs visible speed and extent of constriction. Too little light may produce little motion; too much light can saturate the image and create afterimages. AidFlow should therefore prefer quality and repeatability over a single forced reading.
- Standard clinical bedside terms such as brisk, sluggish, and non-reactive are subjective. Automated pupillometers usually measure diameter, percent change, latency, constriction velocity, dilation velocity, and model-derived scores. AidFlow V1 records percent constriction, estimated latency, confidence, and quality flags.
- The current capture distance guide, 22-45 cm, is an engineering range for rear-camera focus, torch geometry, and LiDAR stability. It is not a clinical standard. This should be tuned from physical-device data.
- The current reaction labels are intentionally conservative:
  - Brisk: clear capture, no serious quality flags, constriction >= 25%, and no delayed onset.
  - Sluggish: clear capture with constriction >= 8% or delayed onset above about 1.1 s.
  - Not observed: clear capture but no meaningful constriction.
  - Uncertain: low confidence, too few clear frames, no onset, bad focus, glare, poor ROI, or unstable capture.

## Current algorithm

1. Camera setup uses the rear camera and torch through AVFoundation. If the device exposes LiDAR depth through `AVCaptureDepthDataOutput`, the tool computes a median distance near the center of the depth map.
2. Vision face landmarks are used only to find the selected eye ROI. If landmarks are unavailable, the centered guide ROI is used as a fallback.
3. Each frame samples luminance inside the ROI and estimates:
   - brightness
   - horizontal and vertical focus energy
   - glare ratio from saturated white pixels
   - pupil candidate shape and area
   - ROI/eye lock quality
   - pupil center offset
   - occlusion risk from poor roundness, weak area fit, off-center pupil, and glare
4. Classical segmentation uses multiple luminance thresholds based on low percentiles and median intensity. Candidate masks are scored with a logistic-style function using contrast, area, center, roundness, diameter, and density.
5. If a bundled `PupilSegmentation.mlmodelc` is available, Vision/Core ML runs a neural segmentation pass over the ROI. The neural mask is converted to a pupil candidate and competes against the classical candidate by likelihood.
6. Capture waits for a usable live state before enabling the button. During capture:
   - baseline frames are collected before torch onset
   - reaction frames are collected after torch onset
   - blurred, glared, obstructed, unstable, or weak-boundary frames are rejected
   - baseline diameter is the robust median after outlier rejection
   - minimum reaction diameter is the lower percentile after outlier rejection
   - percent constriction is `(baseline - minimum) / baseline`
   - onset latency is the first post-torch sample that drops by at least 4% or 1.5 px
7. Saved results include confidence, quality percentage, quality flags, optional LiDAR distance, optional approximate millimeters, and whether neural segmentation was primary.

## Neural network upgrade path

The app already supports an optional Core ML segmentation model named `PupilSegmentation.mlmodelc`. Until a real model is bundled, it uses the classical computer-vision fallback.

Recommended model target:

- Input: cropped eye ROI, RGB or grayscale, fixed size such as 160x96 or 192x128.
- Output: one-channel pupil probability mask, same aspect ratio as input.
- Architecture: small U-Net, MobileNetV3/DeepLab-style decoder, or ellipse-aware segmentation model.
- Loss: Dice + binary cross entropy, with optional ellipse consistency term.
- Labels: binary pupil mask; optional iris, sclera, eyelid/glasses/glare classes for later versions.
- Deployment: convert to Core ML with flexible or fixed input size, quantized if performance requires it.

Training data should include:

- left and right eyes
- light and dark irises
- glasses and no glasses
- low light, torch glare, off-axis reflection, and eyelid coverage
- motion blur and focus blur
- LiDAR and non-LiDAR devices
- repeated baseline and post-torch frames from the same capture

Developer Mode can collect local ROI PNGs and metadata in Application Support under `AidFlow/PupilTrainingFrames`. These images are sensitive biometric-adjacent data. Do not enable collection in normal field use, and do not export samples without explicit consent.

Dataset tooling now lives in `Tools/PupilDataset`:

```bash
python3 Tools/PupilDataset/build_manifest.py \
  --input /path/to/PupilTrainingFrames \
  --output /path/to/pupil_manifest.csv

python3 Tools/PupilDataset/split_manifest.py \
  --input /path/to/pupil_manifest.csv \
  --output /path/to/pupil_manifest_split.csv
```

The manifest keeps capture phase, torch state, quality scores, LiDAR distance, and blank annotation columns for the later pupil mask path. Split by `capture_id` to avoid putting related baseline/reaction frames in different train/validation/test sets.

## Validation gates before claiming reliability

- Compare manual labels against classical segmentation and neural segmentation.
- Test at multiple distances and compute pixel-to-mm error with a printed calibration target.
- Validate torch timing and actual frame timestamps on physical devices.
- Measure repeatability across at least three captures per eye.
- Validate difficult cases: dark iris, glare, glasses, mascara/eyelashes, eyelid occlusion, non-centered eye, motion, and low light.
- Compare against a known pupillometer or trained clinician observation before any medical-grade claim.

## Sources used

- NCBI Clinical Methods, "The Pupils": https://www.ncbi.nlm.nih.gov/books/NBK381/
- NCBI StatPearls, "Pupillary Light Reflex": https://www.ncbi.nlm.nih.gov/books/NBK537180/
- NCBI StatPearls, "The Effect of Pupil Size on Visual Resolution": https://www.ncbi.nlm.nih.gov/books/NBK603732/
- Understanding NPi and constriction velocity values: https://pmc.ncbi.nlm.nih.gov/articles/PMC5934377/
- Smartphone PuRe score and ambient-light correction: https://pmc.ncbi.nlm.nih.gov/articles/PMC11037402/
- PupilScreen smartphone pupillometry and ML: https://pmc.ncbi.nlm.nih.gov/articles/PMC12671303/
- EllSeg pupil/iris ellipse segmentation: https://arxiv.org/abs/2007.09600
- CondSeg ellipse estimation and conditioned segmentation: https://arxiv.org/abs/2408.17231
- Apple AVFoundation LiDAR depth capture: https://developer.apple.com/documentation/avfoundation/capturing-depth-using-the-lidar-camera
- Apple ARKit sceneDepth: https://developer.apple.com/documentation/arkit/arframe/scenedepth
