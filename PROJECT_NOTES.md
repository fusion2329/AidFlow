# AidFlow Project Notes

AidFlow is an iOS SwiftUI app for first aid scene guidance, timeline recording, patient history, location capture, and structured handover generation.

## Product Direction

- Product name: AidFlow.
- Positioning: training and guidance platform, not a formal medical diagnosis tool.
- Core use case: help first aiders stay calm after arriving at a scene by following simple steps, recording key events, and producing a clear handover.
- Primary users: St John cadets and members, school first aid teams, sports club first aiders, teachers, event volunteers, and first aid trainees.
- UI tone: calm, dark, cockpit-checklist style, large controls, low text density, liquid glass visual style.

## Current Development Rules

- UI text should be English unless explicitly requested otherwise.
- Do not add iCloud, CloudKit, Sign in with Apple, push notifications, or other Apple Developer account-only features for now.
- Use local device storage only.
- Every new screen must include a Developer Mode 6-digit screen ID.
- Use branch-style screen IDs, not global sequential IDs:
  - `1xxxxx` Home and tools
  - `2xxxxx` active incident, patient history, timeline, and handover
  - `3xxxxx` Routine, planned events, past records, and incident detail
  - `4xxxxx` Profile and Settings
  - `5xxxxx` Training
- Developer Mode is controlled from Settings.
- Pupil Reaction Check is Developer Mode only and should remain hidden from normal users until it is validated beyond experimental/research use.
- Keep Settings concise; legal copy lives behind the Legal & Privacy entry.
- Prefer practical, stable SwiftUI patterns over complex architecture for now.

## Developer Screen IDs

- `110001` - `HomeView`
- `120001` - `CPRCounterView`
- `120002` - `GCSCalculatorView`
- `210001` - `ArrivalModeView`
- `220001` - `IncidentHistoryView.Patient`
- `220002` - `IncidentHistoryView.Timeline`
- `220003` - `TimelineView`
- `230001` - `HandoverView.Editor`
- `230002` - `HandoverView.FinalReport`
- `240001` - `PatientRecordFormView`
- `240002` - `VitalSignsEditorView`
- `310001` - `PastIncidentsView`
- `310002` - `IncidentHistoryDetailView`
- `320001` - `PlannedEventDetailView`
- `320002` - `PlannedEventEditorView`
- `410001` - `ProfileView`
- `420001` - `SettingsView`
- `420002` - `LegalPrivacyView`
- `420003` - `FirstLaunchSafetyDisclaimerView`
- `510001` - `TrainingView`

## Current Features

- Main navigation uses three independent tabs: Home, History, Settings.
- Home screen has a title-case time-based greeting using the saved profile first name, plus Profile, Arrival Mode, Patient Record Form, and Training Mode placeholder. History is accessed from the main History tab.
- Profile screen has uploadable avatar, first name/surname editing, large name, member since, responder level, role, and personal contact.
- Settings screen has language preference, Developer Mode, Acknowledgement of Country, a Legal & Privacy entry, and version.
- Arrival Mode has step-by-step scene workflow, notes, a red 000 button, large tappable location card, in-app map sheet, 000 confirmation, unsafe scene alert, and history access.
- Incident History with separate Patient and Timeline tabs.
- Patient History fields include first name, surname, DOB with calculated age, sex, patient address, patient contact detail, token/block allergies with local database suggestions, token/block medications with local database suggestions, token/block medical history with local database suggestions, event name, event history, injury, injury body part, emergency contact detail, and notes.
- Patient Record Form is a standalone non-scene form that saves directly into History as a `Patient Record`.
- Patient Record Form supports event name, event location capture, and a front/back segmented body map for selecting injury body part plus injury type.
- Timeline records key events and supports adding notes with selected time and event type.
- Handover generator outputs IMIST-AMBO-style text and supports sharing as a text document.
- Close Case flow records patient departure and generates a receipt-style final report with Share, Edit, and Done.
- Past Incidents list supports multi-select delete and share from the top toolbar.

## Role Options

- Role: `Responder`, `Community Member`
- Responder level: `First Aider`, `First Responder`, `EMT`, `Health Care Professional`

## Persistence

- Data is stored locally in Application Support as `AidFlow/incident-database.json`.
- No iCloud or remote sync is currently used.
- Bundled suggestion databases are stored in `AidFlow/Resources/MedicationNames.json`, `AidFlow/Resources/MedicalHistoryConditions.json`, and `AidFlow/Resources/CommonAllergens.json`.

## Verification Commands

Typecheck:

```sh
swiftc -typecheck -target arm64-apple-ios17.0 -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk -module-cache-path .build/ModuleCache AidFlow/AidFlowApp.swift AidFlow/Models/IncidentModels.swift AidFlow/Models/IncidentStore.swift AidFlow/Models/ArrivalFlow.swift AidFlow/Models/LocationManager.swift AidFlow/Views/MainTabView.swift AidFlow/Views/HomeView.swift AidFlow/Views/SettingsView.swift AidFlow/Views/ArrivalModeView.swift AidFlow/Views/TimelineView.swift AidFlow/Views/IncidentHistoryView.swift AidFlow/Views/PatientRecordFormView.swift AidFlow/Views/HandoverView.swift AidFlow/Views/TrainingView.swift AidFlow/Views/PastIncidentsView.swift AidFlow/Views/SceneStyles.swift
```

Xcode build:

```sh
xcodebuild -project AidFlow.xcodeproj -scheme AidFlow -destination 'id=49747AD2-3FD6-414F-AF3E-B4E2F49017B9' -derivedDataPath /private/tmp/AidFlowDerivedData build
```

## Next Possible Work

- Improve Training Mode with scenario simulation.
- Add richer patient assessment fields.
- Improve final report export format.
- Add better incident editing from Past Incidents.
- Add more screen IDs as new pages are created.
