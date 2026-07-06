# AidFlow

AidFlow is a SwiftUI iOS app for first aid scene guidance, patient record keeping, timeline logging, and structured handover generation.

The app is designed as a training and first aid workflow assistant. It is not a medical diagnosis tool and does not replace local emergency procedures or professional clinical judgement.

Current release version: `1.1` / build `2`.

Release notes are maintained in [`RELEASE_NOTES.md`](RELEASE_NOTES.md).

Experimental Android Lite scaffold: [`android/`](android/README.md).

Collaboration workflow and pull request expectations are documented in [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Current Status

AidFlow has moved beyond the first MVP. The current build includes:

- Three main tabs: Home, Routine, and Settings.
- Arrival Mode for step-by-step scene guidance.
- Patient History and Timeline editing during an active incident.
- Patient Record Form for non-scene patient documentation.
- Privacy-first patient records: patient identity fields are hidden and stripped by default, with Dev Mode access retained for development.
- Routine planning for upcoming events.
- CPR Counter and GCS Calculator tools.
- Pupil Reaction Check is kept behind Developer Mode as an experimental observation/research tool.
- Shared reduced-motion-aware UI motion, card entrance animation, and press feedback.
- Training Mode preview with polished locked scenario cards and stable SwiftUI identity.
- Stable SwiftUI list/map identities for repeated scene, map, and body-map elements to reduce unnecessary diff churn.
- iOS forward-compatibility cleanup for MapKit surfaces and foreground scene window attachment.
- Location capture with coordinates, address, nearby street, and in-app map preview.
- Structured handover/report generation with document sharing.
- Local persistence using a coalesced JSON database with load-time recovery safeguards.
- Live Activity support for active Arrival Mode incidents.
- CPR Counter state in Live Activities when CPR is started from Arrival Mode or from the Home tool.

## Core User Flows

### Home

Home shows a time-based greeting using the saved profile first name and provides quick entry to:

- Arrival Mode
- Patient Record Form
- Training Mode preview
- CPR Counter
- GCS Calculator

### Arrival Mode

Arrival Mode guides a first aider through a simplified DRSABCD-style flow:

1. Scene safety
2. Response
3. Airway
4. Breathing
5. Emergency escalation
6. Ongoing monitoring / handover preparation

Current Arrival Mode features:

- One prompt at a time.
- Step progress bar with smooth reduced-motion-aware transitions.
- Large Yes / No / Unsure response buttons.
- Previous-step navigation.
- Elapsed incident timer.
- Per-step notes.
- High-contrast note input placeholder and cursor styling for glass panels.
- Red 000 call confirmation.
- Unsafe-scene alert with Call 000 and Scene is safe now actions.
- Location card with address and coordinates.
- In-app map sheet.
- History button for Patient History and Timeline.
- Live Activity update while an incident is active.
- Compact Live Activity CPR display when the Arrival Mode CPR Counter is running, including compression count, cycle count, breath phase, pause state, and a stable CPR elapsed timer.

When CPR Counter is opened from Home, it creates a standalone CPR Live Activity. When CPR Counter is opened from Arrival Mode, it updates the active incident Live Activity.

### Patient History

Patient History is editable from Arrival Mode and includes:

- Age.
- Sex.
- Allergies as token blocks with local suggestions.
- Medications as token blocks with local suggestions.
- Treatment as token blocks with common first aid treatment suggestions.
- Medical history as token blocks with local suggestions.
- Event name, event location, event time, and event history.
- Injury body map with front/back body selection.
- Multiple injury records per body part.
- Notes.
- Optional St John member signature.
- Vital signs section, including GCS score fields.

By default, patient identity fields are not shown or saved. Dev Mode re-enables the retained identity fields for development and testing:

- First name and surname.
- Date of birth.
- Patient address with map address search.
- Patient contact detail.
- Emergency contact detail.

### Timeline

Timeline supports:

- Automatic entries from Arrival Mode.
- Manual event creation.
- Event time editing.
- Event category selection.
- Notes/details for each event.

Timeline categories include Arrival, Safety, Assessment, Escalation, Treatment, and Observation.

### Training

Training Mode currently shows a prepared scenario library for:

- Cardiac arrest
- Asthma attack
- Seizure
- Severe bleeding
- Anaphylaxis
- Heat illness

Scenario cards use stable identifiers, reduced-motion-aware entrance animation, and locked "Preparing" status until full guided simulations are implemented.

### Handover And Reports

AidFlow generates a clear handover report from:

- Patient summary.
- Event and injury summary.
- Clinical history.
- Treatment.
- Location.
- Timeline and actions.
- Case closure details.
- Optional responder signature.

The report can be shared as a text document through the iOS share sheet, including AirDrop.

By default, handover text and PDF exports exclude patient identity fields. Dev Mode includes the full retained patient identity fields for development and testing.

Current Handover layout safeguards:

- The editor uses one scrollable content area with a fixed, opaque Close Case action bar, so report options and preview content do not sit underneath the primary action.
- Report section toggles support multiline localized labels and keep switch controls aligned on narrow screens.
- The final report receipt adapts its PDF, Edit, and Done actions between horizontal and stacked layouts when needed.
- PDF export estimates section heights from actual wrapped content before drawing, reducing footer overlap and page-break risk for long localized values or notes.
- Handover share artifacts are generated on explicit cache refresh points, not from SwiftUI `body` computed properties, avoiding repeated PDF/text file writes during redraws.
- Developer screen IDs are placed in the top safe area instead of over bottom controls.

### Routine

Routine combines planned events and past records.

Current Routine features:

- Upcoming event list.
- Past incident and patient record list.
- Planned event creation and editing.
- Event name, location, time, notes, and optional image.
- Location search and map preview.
- Travel time calculation and navigation.
- Calendar event sync when creating or deleting planned events.
- Left-swipe delete.
- Multi-select delete/share for past records.
- Recover/Continue action for incidents.
- Detail view with editable patient history, timeline, handover, and delete action.

### Settings And Profile

Settings includes:

- User profile.
- Uploadable avatar.
- First name and surname.
- Member since.
- Responder level.
- Role.
- Personal contact.
- St John member signature section with rank, division, and member ID.
- Travel mode preference.
- Language preference.
- Developer Mode screen IDs.
- Acknowledgement of Country.
- Disclaimer.
- Privacy Policy.
- Copyright.
- Version.

## Developer Screen IDs

Developer Mode can show six-digit screen IDs to make feedback easier.

Screen IDs now use branch-style numbering:

- `1xxxxx` - Home and tools
- `2xxxxx` - Active incident, patient history, timeline, and handover
- `3xxxxx` - Routine, planned events, past records, and incident detail
- `4xxxxx` - Profile and Settings
- `5xxxxx` - Training

Current IDs:

- `110001` - HomeView
- `120001` - CPRCounterView
- `120002` - GCSCalculatorView
- `210001` - ArrivalModeView
- `220001` - IncidentHistoryView.Patient
- `220002` - IncidentHistoryView.Timeline
- `220003` - TimelineView
- `230001` - HandoverView.Editor
- `230002` - HandoverView.FinalReport
- `240001` - PatientRecordFormView
- `240002` - VitalSignsEditorView
- `310001` - PastIncidentsView / Routine
- `310002` - IncidentHistoryDetailView
- `320001` - PlannedEventDetailView
- `320002` - PlannedEventEditorView
- `410001` - ProfileView
- `420001` - SettingsView
- `510001` - TrainingView

## Data And Storage

AidFlow currently stores app data locally on device.

Default patient record saving removes patient identity fields including name, date of birth, patient address, patient contact, and emergency contact. Medical information such as age, sex, allergies, medications, treatment, medical history, injuries, vital signs, notes, event details, timeline, and handover content remains available. Dev Mode keeps the identity-field code path available for development.

- Incident database: Application Support / `AidFlow/incident-database.json`
- Medication suggestions: `AidFlow/Resources/MedicationNames.json`
- Medical history suggestions: `AidFlow/Resources/MedicalHistoryConditions.json`
- Allergen suggestions: `AidFlow/Resources/CommonAllergens.json`

Current persistence safeguards:

- Database saves are debounced, batched for multi-step mutations, and skipped when the current snapshot matches the last queued write.
- Database decode failures quarantine the unreadable JSON file as `incident-database-corrupt-*.json` instead of repeatedly retrying the broken file on every launch.
- Loaded incident data is normalized by clamping Arrival Mode progress, sorting vital signs and timeline entries, removing duplicate past incidents, and keeping an active incident out of past history.
- Vital-sign and pupil-check timeline events carry a stable source record ID for future updates/deletes, with fallback matching retained for older saved records.
- Live Activities are refreshed after vital-sign updates/deletes and stale active activities are ended when a new incident replaces an existing one.

iCloud and remote sync are intentionally not enabled in the current build.

## Maintenance Notes

- Always update this README after completing feature, behavior, UI, animation, privacy, storage, or build-related code changes.

## iOS Forward Compatibility

Current local verification is limited by the installed Xcode SDKs: this machine currently provides iOS 26.5 / iOS Simulator 26.5 SDKs, not an iOS 27 SDK.

The current compatibility pass keeps the app target on its existing iOS 16.6 deployment floor while preparing likely future-sensitive areas:

- Map previews now use the modern `Map(initialPosition:)` + `Marker` path on iOS 17 and later, with `Map(coordinateRegion:)` fallback retained for iOS 16.6.
- The incident map keeps iOS 17+ map controls while retaining the iOS 16 fallback path.
- System volume view attachment now prefers the foreground-active key window scene and falls back to any key window, which is safer for multi-window and future scene lifecycle behavior.

## Xcode Project

Open `AidFlow.xcodeproj` in Xcode and run the `AidFlow` scheme.

Do not run the `AidFlowLiveActivities` extension scheme directly. It is embedded in the main app and is used by ActivityKit.

## Build And Verification Commands

Common verification commands used during development:

```sh
xcodebuild -project AidFlow.xcodeproj -scheme AidFlow -destination generic/platform=iOS -derivedDataPath /private/tmp/AidFlowDerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project AidFlow.xcodeproj -scheme AidFlow -destination generic/platform=iOS analyze
xcodebuild -project AidFlow.xcodeproj -scheme AidFlow -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -showsdks
```

Latest local verification also installed and launched the simulator build on iPhone 17, with screenshots captured at:

- `/private/tmp/aidflow-training-polish-home.png`
- `/private/tmp/aidflow-training-polish-page.png`
- `/private/tmp/aidflow-handover-editor-fixed.png`
- `/private/tmp/aidflow-handover-receipt-fixed.png`

Latest backend/storage verification:

```sh
xcodebuild -project AidFlow.xcodeproj -scheme AidFlow -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /private/tmp/AidFlowDerivedData build
```

Latest 1.1 release verification:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project AidFlow.xcodeproj -scheme AidFlow -destination generic/platform=iOS -derivedDataPath /private/tmp/AidFlowDerivedData build
```

Result: `BUILD SUCCEEDED` using Xcode 27.0 beta.

## Current Limitations

- Training Mode scenario content is still in preparation.
- Live Activities require supported iOS versions and must be tested through the main app.
- CPR Counter Live Activity updates depend on the main app being able to publish ActivityKit state updates.
- Handover export supports shareable text and PDF outputs.
- Pupil Reaction Check is Developer Mode only and is not intended for normal user release or clinical decision-making.
- Data is local-only; no cloud sync is enabled.
- This app is for training and workflow support, not diagnosis.

## Near-Term Work

- Build real Training Mode scenarios.
- Improve handover export formatting.
- Add richer treatment and assessment templates.
- Refine Live Activity behavior on physical devices.
- Continue improving Routine event planning and incident recovery.
