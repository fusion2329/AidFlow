# AidFlow Release Notes

## Version 1.1 - 2026-07-04

AidFlow 1.1 is a major workflow and reliability update. This release expands Arrival Mode, improves handover generation, adds stronger privacy defaults, improves local storage safety, and introduces CPR Live Activity support.

### Highlights

- Improved Arrival Mode with clearer one-step guidance, progress display, smoother transitions, and better note entry.
- Added CPR Counter Live Activity support from both Arrival Mode and the Home CPR tool.
- Redesigned the CPR Live Activity layout so lock screen and Dynamic Island views remain readable.
- Added configurable handover/report sections with improved PDF export behavior.
- Added privacy-first patient record handling: identity fields are hidden and removed by default, while Dev Mode keeps the retained development workflow available.
- Strengthened local database persistence with batching, duplicate-write avoidance, corrupted-file quarantine, and load-time normalization.
- Added a first-launch safety notice and clearer Legal & Privacy access.
- Expanded localization coverage for simplified Chinese and Cantonese beta.
- Improved Training Mode presentation with prepared locked scenario cards.
- Added Developer Mode-only pupil reaction research notes and local dataset tooling for future ML segmentation work.

### Arrival Mode

- Added a visual progress bar for the DRSABCD-style flow.
- Added reduced-motion-aware transitions between questions.
- Improved button press feedback and liquid glass card interactions.
- Improved the note field with clearer placeholder and cursor styling.
- Updated CPR Counter launch behavior so the active incident Live Activity shows CPR state.
- Improved map compatibility with iOS 17+ MapKit APIs while retaining iOS 16 fallback support.

### CPR Counter And Live Activities

- Added a shared CPR state model for Live Activities.
- Home CPR Counter now creates a standalone CPR Live Activity.
- Arrival Mode CPR Counter now updates the active incident Live Activity.
- CPR Live Activity shows compression count, cycle count, breath phase, pause state, and elapsed CPR timer.
- CPR Live Activity hides address details during CPR to preserve readable layout.
- Live Activity cleanup now reduces duplicate active activities.

### Handover And Reports

- Added report section toggles for case overview, patient summary, event/injury summary, clinical history, vital signs, location, timeline/actions, responder signature, and privacy/safety notice.
- Improved handover preview layout with one scrollable content area and a fixed Close Case action bar.
- Improved final receipt action layout for narrow screens.
- Improved PDF generation by estimating wrapped content height before drawing sections.
- Reduced repeated PDF/text generation during SwiftUI redraws by caching export artifacts at explicit refresh points.
- Handover exports now exclude patient identity fields by default unless Dev Mode is enabled.

### Privacy And Patient Records

- Patient identity fields are hidden and stripped by default:
  - first name and surname
  - date of birth
  - patient address
  - patient contact detail
  - emergency contact detail
- Medical and care information remains available:
  - age
  - sex
  - allergies
  - medications
  - treatment
  - medical history
  - injuries
  - vital signs
  - notes
  - timeline
  - event details
- Dev Mode can still show the retained identity-field workflow for development and testing.

### Storage And Reliability

- Database saves are now debounced and batched across multi-step mutations.
- Unchanged database snapshots are skipped instead of being rewritten.
- Corrupt database files are quarantined as `incident-database-corrupt-*.json`.
- Loaded data is normalized by clamping Arrival Mode progress, sorting vital signs/timeline records, removing duplicate past incidents, and preventing active incidents from also appearing in past history.
- Vital signs and pupil reaction timeline entries now carry stable source IDs for safer updates and deletes.

### Routine, History, And Records

- Improved active incident recovery/continue behavior.
- Improved delete behavior for current and past records.
- Past record detail supports editable patient history, timeline, handover, and delete actions.
- Planned event application is more consistent when used from patient record workflows.

### UI And Accessibility

- Added reusable card press feedback.
- Added reusable entrance animation with Reduce Motion support.
- Moved Developer Mode screen IDs to the top safe area so they do not cover bottom controls.
- Added reusable empty-state UI.
- Improved several narrow-screen text and action layouts.

### Training Mode

- Replaced the basic placeholder with locked scenario cards.
- Prepared scenario categories:
  - Cardiac arrest
  - Asthma attack
  - Seizure
  - Severe bleeding
  - Anaphylaxis
  - Heat illness

### Pupil Reaction Research And Tooling

- Pupil Reaction Check is hidden from normal users and available only when Developer Mode is enabled.
- Expanded pupil reaction capture metadata for Developer Mode ML frame collection.
- Added capture phase, torch state, quality status, distance, ROI geometry, and model-availability metadata.
- Added `Tools/PupilDataset` with:
  - manifest builder
  - train/validation/test split helper
  - CVAT labels
  - annotation guidelines
- Added research notes covering algorithm limits, ML upgrade path, and validation gates.

### Known Limitations

- AidFlow remains a training, checklist, documentation, and first aid guidance tool, not a diagnostic medical device.
- Training scenarios are still in preparation.
- Live Activities must be tested through the main app on supported iOS versions.
- Data remains local-only; no iCloud or remote sync is enabled.
- Pupil reaction tooling is Developer Mode-only research/development support and should not be treated as clinical-grade measurement.
