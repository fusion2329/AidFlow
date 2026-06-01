import SwiftUI

struct PatientRecordFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var incidentStore: IncidentStore
    @AppStorage("userProfile.name") private var responderName = ""
    @AppStorage("userProfile.signatureRank") private var responderRank = ""
    @AppStorage("userProfile.signatureDivision") private var responderDivision = ""
    @AppStorage("userProfile.signatureMemberID") private var responderMemberID = ""
    @AppStorage("developerModeEnabled") private var developerModeEnabled = false
    @StateObject private var locationManager = LocationManager()
    @State private var profile = PatientProfile()
    @State private var dateOfBirth = Date()
    @State private var notes = ""
    @State private var capturedLocation: IncidentLocation?
    @State private var patientAddressSearch = ""
    @State private var selectedBodySide: InjuryBodySide = .front
    @State private var selectedInjuryType = InjuryType.pain.rawValue
    @State private var vitalSigns: [VitalSignsRecord] = []
    @State private var editingVitalSigns: VitalSignsRecord?
    @State private var treatmentEvents: [TimelineEvent] = []
    @State private var didApplyInitialEvent = false
    @State private var selectedPlannedEventID: UUID?
    private let plannedEvent: PlannedEvent?
    private let editingIncident: Incident?

    init(plannedEvent: PlannedEvent? = nil, editingIncident: Incident? = nil) {
        self.plannedEvent = plannedEvent
        self.editingIncident = editingIncident
    }

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    patientDetails
                    clinicalDetails
                    treatmentSection
                    vitalSignsSection
                    if developerModeEnabled {
                        emergencyContact
                    }
                    notesBox
                    signatureSection
                    saveButton
                }
                .padding(20)
            }
        }
        .developerScreenID("240001", "PatientRecordFormView")
        .navigationTitle("Patient Record".afLocalized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            if !didApplyInitialEvent, let editingIncident {
                profile = editingIncident.patientProfile
                notes = editingIncident.patientNotes
                capturedLocation = editingIncident.location
                vitalSigns = editingIncident.vitalSigns
                treatmentEvents = []
                didApplyInitialEvent = true
            }
            if !didApplyInitialEvent, let plannedEvent {
                profile.applyPlannedEvent(plannedEvent)
                selectedPlannedEventID = plannedEvent.id
                didApplyInitialEvent = true
            }
            dateOfBirth = RecordDateHelper.date(from: profile.dateOfBirth) ?? Date()
            if patientAddressSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                patientAddressSearch = currentPatientAddressText
            }
        }
        .onChange(of: dateOfBirth) { newValue in
            profile.dateOfBirth = RecordDateHelper.string(from: newValue)
            profile.age = RecordDateHelper.age(from: profile.dateOfBirth)
        }
        .onReceive(locationManager.$snapshot) { snapshot in
            guard let snapshot else { return }
            capturedLocation = snapshot
        }
        .sheet(item: $editingVitalSigns) { record in
            VitalSignsEditorView(record: record) { updatedRecord in
                saveVitalSigns(updatedRecord)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Patient Record Form".afLocalized)
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text((editingIncident == nil ? "Standalone patient information record for non-scene use." : "Edit the saved patient, event, injury, notes, and location record.").afLocalized)
                .font(.subheadline)
                .foregroundStyle(Color.sceneMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .historyCard()
    }

    private var patientDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            recordSectionTitle("Patient Details".afLocalized)

            if developerModeEnabled {
                HStack(spacing: 10) {
                    RecordTextField(title: "First name".afLocalized, text: $profile.firstName)
                    RecordTextField(title: "Surname".afLocalized, text: $profile.surname)
                }

                RecordDateField(title: "Date of Birth".afLocalized, date: $dateOfBirth)
            }

            HStack(spacing: 10) {
                Group {
                    if developerModeEnabled {
                        RecordDisplayField(title: "Age".afLocalized, value: profile.age.isEmpty ? "Not set".afLocalized : profile.age)
                    } else {
                        RecordTextField(title: "Age".afLocalized, text: $profile.age, keyboardType: .numberPad)
                    }
                }
                .frame(maxWidth: 120)

                RecordPickerField(title: "Sex".afLocalized, selection: $profile.sex, options: ["Female", "Male"])
            }

            if developerModeEnabled {
                recordSectionTitle("Patient Address".afLocalized)

                MapAddressField(title: "Search patient address".afLocalized, text: $patientAddressSearch) { resolved in
                    applyPatientAddress(resolved)
                }

                HStack(spacing: 10) {
                    RecordTextField(title: "Unit".afLocalized, text: $profile.patientUnit)
                    RecordTextField(title: "Street".afLocalized, text: $profile.patientStreet)
                }

                HStack(spacing: 10) {
                    RecordTextField(title: "Suburb".afLocalized, text: $profile.patientSuburb)
                    RecordTextField(title: "State".afLocalized, text: $profile.patientState)
                    RecordTextField(title: "Postcode".afLocalized, text: $profile.patientPostcode, keyboardType: .numberPad)
                }

                RecordTextField(title: "Contact detail".afLocalized, text: $profile.patientContactDetail, keyboardType: .phonePad)
            }
        }
        .historyCard()
    }

    private var clinicalDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            recordSectionTitle("Clinical Information".afLocalized)

            RecordSuggestedTokenField(
                title: "Allergies".afLocalized,
                emptyMessage: "No allergies added.".afLocalized,
                placeholder: "Type allergen, then press return".afLocalized,
                text: $profile.allergies,
                database: RecordAllergenDatabase.shared.names
            )
            RecordSuggestedTokenField(
                title: "Medications".afLocalized,
                emptyMessage: "No medications added.".afLocalized,
                placeholder: "Type medication, then press return".afLocalized,
                text: $profile.medications,
                database: RecordMedicationDatabase.shared.names
            )
            RecordSuggestedTokenField(
                title: "Medical history".afLocalized,
                emptyMessage: "No medical history added.".afLocalized,
                placeholder: "Type condition, then press return".afLocalized,
                text: $profile.medicalHistory,
                database: RecordMedicalHistoryDatabase.shared.conditions
            )

            recordSectionTitle("Event / Injury".afLocalized)

            plannedEventPanel
            RecordTextField(title: "Event name".afLocalized, text: $profile.eventName)
            MapAddressField(title: "Event location".afLocalized, text: $profile.eventLocation)
            RecordTextField(title: "Event time".afLocalized, text: $profile.eventStartTime)
            locationCapturePanel
            RecordTextEditorField(title: "Event History".afLocalized, text: $profile.eventHistory)
            InjuryBodyMapField(
                selectedSide: $selectedBodySide,
                selectedType: $selectedInjuryType,
                injury: $profile.injury,
                bodyPart: $profile.injuryBodyPart
            )
        }
        .historyCard()
    }

    private var treatmentSection: some View {
        RecordTreatmentTimelineEditor(
            treatmentText: $profile.treatment,
            events: displayedTreatmentEvents,
            suggestions: RecordTreatmentDatabase.shared.names
        ) { treatment, note in
            addTreatmentEvent(treatment, note: note)
        }
        .historyCard()
    }

    private var displayedTreatmentEvents: [TimelineEvent] {
        let existing = editingIncident?.timeline.filter { $0.category == .treatment } ?? []
        return (existing + treatmentEvents).sorted { $0.timestamp > $1.timestamp }
    }

    private var plannedEventPanel: some View {
        let upcomingEvents = incidentStore.upcomingPlannedEvents()
        let selectedEvent = selectedPlannedEvent(in: upcomingEvents)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Planned event".afLocalized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)

            if upcomingEvents.isEmpty, selectedEvent == nil {
                Text("No upcoming planned events.".afLocalized)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .liquidGlass(tint: Color.sceneAccent, opacity: 0.07)
            } else {
                Menu {
                    ForEach(upcomingEvents) { event in
                        Button {
                            applyPlannedEvent(event)
                        } label: {
                            Text(event.name.isEmpty ? "Untitled event".afLocalized : event.name)
                        }
                    }
                } label: {
                    HStack {
                        Label(plannedEventMenuTitle(for: selectedEvent), systemImage: "calendar.badge.checkmark")
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SceneSecondaryButtonStyle())
            }
        }
    }

    private var locationCapturePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location capture".afLocalized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)

            Button {
                locationManager.requestLocation()
            } label: {
                Label((capturedLocation == nil ? "Capture location" : "Update location").afLocalized, systemImage: "location.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SceneSecondaryButtonStyle())

            if let capturedLocation {
                VStack(alignment: .leading, spacing: 5) {
                    Text(AppStrings.text("Coordinates: %@", capturedLocation.coordinateText))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.sceneAccent)
                    Text(AppStrings.text("Address: %@", capturedLocation.address))
                        .font(.caption)
                        .foregroundStyle(Color.sceneMuted)
                    if let nearby = capturedLocation.nearbyStreet, !nearby.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(AppStrings.text("Nearby street: %@", nearby))
                            .font(.caption)
                            .foregroundStyle(Color.sceneMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
            }
        }
    }

    private var emergencyContact: some View {
        VStack(alignment: .leading, spacing: 10) {
            recordSectionTitle("Emergency Contact Detail".afLocalized)

            HStack(spacing: 10) {
                RecordTextField(title: "Name".afLocalized, text: $profile.emergencyContactDetailName)
                RecordTextField(title: "Contact detail".afLocalized, text: $profile.emergencyContactDetail, keyboardType: .phonePad)
            }
        }
        .historyCard()
    }

    private var vitalSignsSection: some View {
        VitalSignsSectionView(
            records: vitalSigns,
            onAdd: {
                editingVitalSigns = VitalSignsRecord()
            },
            onEdit: { record in
                editingVitalSigns = record
            },
            onDelete: { record in
                vitalSigns.removeAll { $0.id == record.id }
            }
        )
    }

    private var notesBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            recordSectionTitle("Notes".afLocalized)
            RecordTextEditorField(title: "Notes".afLocalized, text: $notes, hidesTitle: true)
        }
        .historyCard()
    }

    private var signatureSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: signatureBinding) {
                VStack(alignment: .leading, spacing: 3) {
                    recordSectionTitle("Signature".afLocalized)
                    Text((hasStoredSignature ? "Use saved St John member signature" : "Set member signature in Profile first").afLocalized)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.sceneMuted)
                }
            }
            .toggleStyle(.switch)
            .tint(Color.sceneAccent)
            .disabled(!hasStoredSignature)

            if profile.includeResponderSignature {
                responderSignatureCard(
                    name: profile.responderSignatureName,
                    rank: profile.responderSignatureRank,
                    division: profile.responderSignatureDivision,
                    memberID: profile.responderSignatureMemberID
                )
            }
        }
        .historyCard()
    }

    private var signatureBinding: Binding<Bool> {
        Binding(
            get: { profile.includeResponderSignature },
            set: { newValue in
                profile.includeResponderSignature = newValue && hasStoredSignature
                if profile.includeResponderSignature {
                    applyResponderSignature()
                } else {
                    profile.responderSignatureName = ""
                    profile.responderSignatureRank = ""
                    profile.responderSignatureDivision = ""
                    profile.responderSignatureMemberID = ""
                }
            }
        )
    }

    private var saveButton: some View {
        Button {
            saveRecord()
        } label: {
            Label((editingIncident == nil ? "Save Patient Record" : "Save Changes").afLocalized, systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(ScenePrimaryButtonStyle())
    }

    private func saveRecord() {
        var profileToSave = profile
        profileToSave.fullName = [profileToSave.firstName, profileToSave.surname]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if developerModeEnabled {
            profileToSave.age = RecordDateHelper.age(from: profileToSave.dateOfBirth)
        } else {
            profileToSave.removeIdentityDetails()
        }
        if profileToSave.includeResponderSignature {
            applyResponderSignature(to: &profileToSave)
        }

        if var editingIncident {
            editingIncident.patientProfile = profileToSave
            editingIncident.patientNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            editingIncident.location = capturedLocation
            editingIncident.vitalSigns = vitalSigns.sorted { $0.recordedAt < $1.recordedAt }
            editingIncident.timeline.append(contentsOf: treatmentEvents)
            editingIncident.timeline.sort { $0.timestamp < $1.timestamp }
            incidentStore.updateIncident(editingIncident)
        } else {
            incidentStore.savePatientRecord(
                profile: profileToSave,
                notes: notes,
                location: capturedLocation,
                vitalSigns: vitalSigns,
                treatmentEvents: treatmentEvents
            )
        }
        dismiss()
    }

    private func addTreatmentEvent(_ treatment: String, note: String) {
        let cleanTreatment = treatment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTreatment.isEmpty else { return }

        if !profile.treatmentTokens.recordContainsCaseInsensitive(cleanTreatment) {
            var updated = profile.treatmentTokens
            updated.append(cleanTreatment)
            profile.treatment = updated.joined(separator: ", ")
        }

        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        treatmentEvents.append(
            TimelineEvent(
                title: "Treatment given",
                detail: cleanNote.isEmpty ? cleanTreatment : "\(cleanTreatment)\nNote: \(cleanNote)",
                category: .treatment
            )
        )
        treatmentEvents.sort { $0.timestamp < $1.timestamp }
    }

    private func saveVitalSigns(_ record: VitalSignsRecord) {
        if let index = vitalSigns.firstIndex(where: { $0.id == record.id }) {
            vitalSigns[index] = record
        } else {
            vitalSigns.append(record)
        }
        vitalSigns.sort { $0.recordedAt < $1.recordedAt }
        editingVitalSigns = nil
    }

    private func applyResponderSignature() {
        guard hasStoredSignature else {
            profile.includeResponderSignature = false
            return
        }
        profile.responderSignatureName = responderName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.responderSignatureRank = responderRank.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.responderSignatureDivision = responderDivision.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.responderSignatureMemberID = responderMemberID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func applyResponderSignature(to profile: inout PatientProfile) {
        guard hasStoredSignature else {
            profile.includeResponderSignature = false
            return
        }
        profile.responderSignatureName = responderName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.responderSignatureRank = responderRank.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.responderSignatureDivision = responderDivision.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.responderSignatureMemberID = responderMemberID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func applyPlannedEvent(_ event: PlannedEvent) {
        profile.applyPlannedEvent(event)
        selectedPlannedEventID = event.id
    }

    private func selectedPlannedEvent(in upcomingEvents: [PlannedEvent]) -> PlannedEvent? {
        if let selectedPlannedEventID,
           let selected = upcomingEvents.first(where: { $0.id == selectedPlannedEventID }) ?? plannedEvent {
            return selected
        }
        return nil
    }

    private func plannedEventMenuTitle(for event: PlannedEvent?) -> String {
        guard let event else {
            return "Apply planned event".afLocalized
        }
        let name = event.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Untitled event".afLocalized : name
    }

    private var currentPatientAddressText: String {
        [
            profile.patientUnit,
            profile.patientStreet,
            profile.patientSuburb,
            profile.patientState,
            profile.patientPostcode
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }

    private func applyPatientAddress(_ resolved: ResolvedMapAddress) {
        if !resolved.streetLine.isEmpty {
            profile.patientStreet = resolved.streetLine
        }
        if !resolved.suburb.isEmpty {
            profile.patientSuburb = resolved.suburb
        }
        if !resolved.state.isEmpty {
            profile.patientState = resolved.state
        }
        if !resolved.postcode.isEmpty {
            profile.patientPostcode = resolved.postcode
        }
    }

    private var hasStoredSignature: Bool {
        hasResponderSignatureContent(
            name: responderName,
            rank: responderRank,
            division: responderDivision,
            memberID: responderMemberID
        )
    }

    private func recordSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.sceneAccent)
            .textCase(.uppercase)
    }
}

private struct RecordTextField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)

            TextField("", text: $text)
                .textFieldStyle(.plain)
                .keyboardType(keyboardType)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
        }
    }
}

private struct RecordTextEditorField: View {
    let title: String
    @Binding var text: String
    var hidesTitle = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if !hidesTitle {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)
            }

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
                .frame(minHeight: 86)
                .padding(10)
                .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
        }
    }
}

private struct RecordDisplayField: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
        }
    }
}

private struct RecordDateField: View {
    let title: String
    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)

            DatePicker("", selection: $date, in: ...Date(), displayedComponents: [.date])
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Color.sceneAccent)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
        }
    }
}

struct VitalSignsSectionView: View {
    let records: [VitalSignsRecord]
    let onAdd: () -> Void
    var onGCSCapture: (() -> Void)? = nil
    let onEdit: (VitalSignsRecord) -> Void
    let onDelete: (VitalSignsRecord) -> Void

    private var sortedRecords: [VitalSignsRecord] {
        records.sorted { $0.recordedAt > $1.recordedAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Vital Signs".afLocalized)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.sceneAccent)
                    .textCase(.uppercase)

                Spacer()

                Button {
                    onAdd()
                } label: {
                    Label("Add Vitals".afLocalized, systemImage: "plus.circle.fill")
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.sceneAccent)
            }

            if let onGCSCapture {
                Button {
                    onGCSCapture()
                } label: {
                    Label("Record GCS".afLocalized, systemImage: "brain.head.profile")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SceneSecondaryButtonStyle())
            }

            if sortedRecords.isEmpty {
                Text("No vital signs recorded.".afLocalized)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .liquidGlass(tint: Color.sceneAccent, opacity: 0.06)
            } else {
                VStack(spacing: 8) {
                    ForEach(sortedRecords) { record in
                        VitalSignsRow(record: record) {
                            onEdit(record)
                        } onDelete: {
                            onDelete(record)
                        }
                    }
                }
            }
        }
        .historyCard()
    }
}

private struct VitalSignsRow: View {
    let record: VitalSignsRecord
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button {
            onEdit()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(DateFormatter.sceneDateTime.string(from: record.recordedAt))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)

                    if record.summaryParts.isEmpty {
                        Text("No values recorded.".afLocalized)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.sceneMuted)
                    } else {
                        Text(record.summaryParts.joined(separator: "  "))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(Color.sceneMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.sceneDanger)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete vital signs".afLocalized)
            }
            .padding(12)
            .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
        }
        .buttonStyle(.plain)
    }
}

struct VitalSignsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var record: VitalSignsRecord
    let onSave: (VitalSignsRecord) -> Void

    private let avpuOptions = ["", "Alert", "Voice", "Pain", "Unresponsive"]

    init(record: VitalSignsRecord, onSave: @escaping (VitalSignsRecord) -> Void) {
        _record = State(initialValue: record)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LiquidGlassBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        DatePicker("Recorded time".afLocalized, selection: $record.recordedAt, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .tint(Color.sceneAccent)
                            .foregroundStyle(.white)
                            .padding(14)
                            .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)

                        vitalsGrid
                        notesField
                        saveButton
                    }
                    .padding(20)
                }
            }
            .developerScreenID("240002", "VitalSignsEditorView")
            .navigationTitle("Vital Signs".afLocalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel".afLocalized) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var vitalsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Measurements".afLocalized)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.sceneAccent)
                .textCase(.uppercase)

            HStack(spacing: 10) {
                RecordTextField(title: "Heart rate".afLocalized, text: $record.heartRate, keyboardType: .numberPad)
                RecordTextField(title: "Respiratory rate".afLocalized, text: $record.respiratoryRate, keyboardType: .numberPad)
            }

            HStack(spacing: 10) {
                RecordTextField(title: "SpO2".afLocalized, text: $record.oxygenSaturation, keyboardType: .numberPad)
                RecordTextField(title: "Temperature".afLocalized, text: $record.temperature, keyboardType: .decimalPad)
            }

            HStack(spacing: 10) {
                RecordTextField(title: "Systolic BP".afLocalized, text: $record.systolicBP, keyboardType: .numberPad)
                RecordTextField(title: "Diastolic BP".afLocalized, text: $record.diastolicBP, keyboardType: .numberPad)
            }

            HStack(spacing: 10) {
                RecordTextField(title: "Pain score".afLocalized, text: $record.painScore, keyboardType: .numberPad)
                RecordTextField(title: "GCS score".afLocalized, text: $record.gcsScore, keyboardType: .numberPad)
            }

            RecordPickerField(title: "AVPU".afLocalized, selection: $record.avpu, options: avpuOptions)
        }
        .historyCard()
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes".afLocalized)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.sceneAccent)
                .textCase(.uppercase)

            RecordTextEditorField(title: "Vital signs notes".afLocalized, text: $record.notes, hidesTitle: true)
        }
        .historyCard()
    }

    private var saveButton: some View {
        Button {
            onSave(cleanedRecord)
            dismiss()
        } label: {
            Label("Save Vitals".afLocalized, systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(ScenePrimaryButtonStyle())
    }

    private var cleanedRecord: VitalSignsRecord {
        var cleaned = record
        cleaned.heartRate = cleaned.heartRate.trimmedField
        cleaned.respiratoryRate = cleaned.respiratoryRate.trimmedField
        cleaned.oxygenSaturation = cleaned.oxygenSaturation.trimmedField
        cleaned.systolicBP = cleaned.systolicBP.trimmedField
        cleaned.diastolicBP = cleaned.diastolicBP.trimmedField
        cleaned.temperature = cleaned.temperature.trimmedField
        cleaned.painScore = cleaned.painScore.trimmedField
        cleaned.avpu = cleaned.avpu.trimmedField
        cleaned.gcsScore = cleaned.gcsScore.trimmedField
        cleaned.notes = cleaned.notes.trimmedField
        return cleaned
    }
}

private struct RecordPickerField: View {
    let title: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)

            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option.isEmpty ? "Not recorded".afLocalized : AppStrings.display(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
        }
    }
}

struct InjuryBodyMapField: View {
    @Binding var selectedSide: InjuryBodySide
    @Binding var selectedType: String
    @Binding var injury: String
    @Binding var bodyPart: String
    @State private var currentSelectedPart = ""
    @State private var otherInjuryType = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Injury".afLocalized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)

            Picker("Body side".afLocalized, selection: $selectedSide) {
                ForEach(InjuryBodySide.allCases) { side in
                    Text(AppStrings.display(side.rawValue)).tag(side)
                }
            }
            .pickerStyle(.segmented)

            InjuryBodyDiagram(side: selectedSide, selectedPart: currentSelectedPart) { part in
                currentSelectedPart = part.name
            }
            .frame(height: 410)

            RecordPickerField(
                title: "Injury type".afLocalized,
                selection: $selectedType,
                options: InjuryType.allCases.map(\.rawValue)
            )

            if selectedType == InjuryType.other.rawValue {
                RecordTextField(title: "Other injury type".afLocalized, text: $otherInjuryType)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button {
                addInjuryRecord()
            } label: {
                Label("Add injury".afLocalized, systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SceneSecondaryButtonStyle())
            .disabled(!canAddInjury)

            VStack(alignment: .leading, spacing: 8) {
                Text(currentSelectedPart.isEmpty ? "Tap a body region on the diagram.".afLocalized : AppStrings.text("Selected body part: %@", AppStrings.display(currentSelectedPart)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(currentSelectedPart.isEmpty ? Color.sceneMuted : Color.sceneAccent)

                Text("Selected injuries".afLocalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)

                if injuryRecords.isEmpty {
                    Text("No injuries added.".afLocalized)
                        .font(.footnote)
                        .foregroundStyle(Color.sceneMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .liquidGlass(tint: Color.sceneAccent, opacity: 0.06)
                } else {
                    VStack(spacing: 8) {
                        ForEach(injuryRecords) { record in
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(AppStrings.display(record.part))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                    Text(AppStrings.display(record.type))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Color.sceneAccent)
                                }

                                Spacer()

                                Button {
                                    removeInjuryRecord(record)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.headline)
                                        .foregroundStyle(Color.sceneMuted)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
                        }
                    }
                }
            }
        }
    }

    private var injuryRecords: [InjuryRecord] {
        InjuryRecord.decode(from: injury)
    }

    private var resolvedInjuryType: String {
        let cleanType = selectedType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanType == InjuryType.other.rawValue else { return cleanType }

        let cleanOther = otherInjuryType.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanOther.isEmpty ? "" : "\(InjuryType.other.rawValue): \(cleanOther)"
    }

    private var canAddInjury: Bool {
        !currentSelectedPart.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !resolvedInjuryType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addInjuryRecord() {
        let cleanPart = currentSelectedPart.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanType = resolvedInjuryType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPart.isEmpty, !cleanType.isEmpty else { return }

        var records = injuryRecords
        let newRecord = InjuryRecord(part: cleanPart, type: cleanType)
        guard !records.contains(newRecord) else { return }

        records.append(newRecord)
        updateInjuryStorage(with: records)
    }

    private func removeInjuryRecord(_ record: InjuryRecord) {
        updateInjuryStorage(with: injuryRecords.filter { $0 != record })
    }

    private func updateInjuryStorage(with records: [InjuryRecord]) {
        injury = InjuryRecord.encode(records)
        bodyPart = records
            .map(\.part)
            .reduce(into: [String]()) { result, part in
                if !result.recordContainsCaseInsensitive(part) {
                    result.append(part)
                }
            }
            .joined(separator: ", ")
    }
}

struct InjuryRecord: Identifiable, Equatable {
    let part: String
    let type: String

    var id: String {
        "\(part.casefoldedKey)|\(type.casefoldedKey)"
    }

    static func decode(from text: String) -> [InjuryRecord] {
        text.split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { item in
                let pieces = item.components(separatedBy: " - ")
                if pieces.count >= 2 {
                    return InjuryRecord(part: pieces[0], type: pieces.dropFirst().joined(separator: " - "))
                }
                return InjuryRecord(part: "Unspecified", type: item)
            }
    }

    static func encode(_ records: [InjuryRecord]) -> String {
        records
            .map { "\($0.part) - \($0.type)" }
            .joined(separator: "; ")
    }
}

struct InjuryBodyDiagram: View {
    let side: InjuryBodySide
    let selectedPart: String
    let onSelect: (InjuryBodyPart) -> Void

    private var parts: [InjuryBodyPart] {
        side.parts
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.07),
                                Color.sceneAccent.opacity(0.05),
                                Color.white.opacity(0.035)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }

                HumanBodySilhouette()
                    .fill(Color.white.opacity(0.055))
                    .overlay {
                        HumanBodySilhouette()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.sceneAccent.opacity(0.72),
                                        Color.white.opacity(0.34),
                                        Color.sceneAccent.opacity(0.28)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 2
                            )
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)

                ForEach(parts) { part in
                    Button {
                        onSelect(part)
                    } label: {
                        ZStack {
                            HumanBodyRegionShape(kind: part.shape)
                                .fill(selectedPart == part.name ? Color.sceneAccent.opacity(0.92) : Color.white.opacity(0.045))
                                .overlay {
                                    HumanBodyRegionShape(kind: part.shape)
                                        .stroke(
                                            selectedPart == part.name ? Color.white.opacity(0.95) : Color.white.opacity(0.20),
                                            lineWidth: selectedPart == part.name ? 2.4 : 1.05
                                        )
                                }

                            Text(AppStrings.display(part.shortName))
                                .font(.system(size: part.labelSize, weight: .bold))
                                .foregroundStyle(selectedPart == part.name ? .black : .white.opacity(0.78))
                                .minimumScaleFactor(0.50)
                                .lineLimit(1)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 2)
                                .background(
                                    selectedPart == part.name ? Color.white.opacity(0.22) : Color.clear,
                                    in: Capsule()
                                )
                                .position(part.labelPoint(in: proxy.size))
                        }
                        .contentShape(HumanBodyRegionShape(kind: part.shape))
                        .shadow(color: selectedPart == part.name ? Color.sceneAccent.opacity(0.38) : .clear, radius: 12)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .overlay {
                            if selectedPart == part.name {
                                HumanBodyRegionShape(kind: part.shape)
                                    .stroke(
                                        Color.sceneAccent.opacity(0.85),
                                        lineWidth: 5
                                    )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                VStack {
                    Spacer()
                    Text(AppStrings.display(side.rawValue).uppercased())
                        .font(.caption2.monospaced().weight(.bold))
                        .foregroundStyle(Color.sceneMuted.opacity(0.76))
                        .padding(.bottom, 10)
                }
            }
        }
    }
}

enum InjuryBodySide: String, CaseIterable, Identifiable {
    case front = "Front"
    case back = "Back"

    var id: String { rawValue }

    var parts: [InjuryBodyPart] {
        switch self {
        case .front:
            return Self.frontParts
        case .back:
            return Self.backParts
        }
    }

    private static let frontParts = [
        InjuryBodyPart(name: "Head / Face", shortName: "Head", shape: .head),
        InjuryBodyPart(name: "Neck", shortName: "Neck", shape: .neck, labelSize: 8),
        InjuryBodyPart(name: "Chest", shortName: "Chest", shape: .chest),
        InjuryBodyPart(name: "Abdomen", shortName: "Abdo", shape: .abdomen),
        InjuryBodyPart(name: "Pelvis / Groin", shortName: "Pelvis", shape: .pelvis, labelSize: 8),
        InjuryBodyPart(name: "Left Upper Arm", shortName: "L Upper", shape: .leftUpperArm, labelSize: 7, labelOffset: CGSize(width: -8, height: -8)),
        InjuryBodyPart(name: "Right Upper Arm", shortName: "R Upper", shape: .rightUpperArm, labelSize: 7, labelOffset: CGSize(width: 8, height: -8)),
        InjuryBodyPart(name: "Left Forearm", shortName: "L Fore", shape: .leftForearm, labelSize: 7, labelOffset: CGSize(width: -12, height: 5)),
        InjuryBodyPart(name: "Right Forearm", shortName: "R Fore", shape: .rightForearm, labelSize: 7, labelOffset: CGSize(width: 12, height: 5)),
        InjuryBodyPart(name: "Left Hand", shortName: "L Hand", shape: .leftHand, labelSize: 7, labelOffset: CGSize(width: -16, height: 12)),
        InjuryBodyPart(name: "Right Hand", shortName: "R Hand", shape: .rightHand, labelSize: 7, labelOffset: CGSize(width: 16, height: 12)),
        InjuryBodyPart(name: "Left Thigh", shortName: "L Thigh", shape: .leftThigh, labelSize: 7, labelOffset: CGSize(width: -7, height: -4)),
        InjuryBodyPart(name: "Right Thigh", shortName: "R Thigh", shape: .rightThigh, labelSize: 7, labelOffset: CGSize(width: 7, height: -4)),
        InjuryBodyPart(name: "Left Lower Leg", shortName: "L Leg", shape: .leftLowerLeg, labelSize: 7, labelOffset: CGSize(width: -8, height: 6)),
        InjuryBodyPart(name: "Right Lower Leg", shortName: "R Leg", shape: .rightLowerLeg, labelSize: 7, labelOffset: CGSize(width: 8, height: 6)),
        InjuryBodyPart(name: "Left Foot", shortName: "L Foot", shape: .leftFoot, labelSize: 7, labelOffset: CGSize(width: -16, height: 18)),
        InjuryBodyPart(name: "Right Foot", shortName: "R Foot", shape: .rightFoot, labelSize: 7, labelOffset: CGSize(width: 16, height: 18))
    ]

    private static let backParts = [
        InjuryBodyPart(name: "Back of Head", shortName: "Head", shape: .head),
        InjuryBodyPart(name: "Neck / Cervical spine", shortName: "Neck", shape: .neck, labelSize: 8),
        InjuryBodyPart(name: "Upper Back", shortName: "Upper", shape: .chest),
        InjuryBodyPart(name: "Lower Back", shortName: "Lower", shape: .abdomen),
        InjuryBodyPart(name: "Buttocks / Pelvis", shortName: "Pelvis", shape: .pelvis, labelSize: 8),
        InjuryBodyPart(name: "Left Upper Arm", shortName: "L Upper", shape: .leftUpperArm, labelSize: 7, labelOffset: CGSize(width: -8, height: -8)),
        InjuryBodyPart(name: "Right Upper Arm", shortName: "R Upper", shape: .rightUpperArm, labelSize: 7, labelOffset: CGSize(width: 8, height: -8)),
        InjuryBodyPart(name: "Left Forearm", shortName: "L Fore", shape: .leftForearm, labelSize: 7, labelOffset: CGSize(width: -12, height: 5)),
        InjuryBodyPart(name: "Right Forearm", shortName: "R Fore", shape: .rightForearm, labelSize: 7, labelOffset: CGSize(width: 12, height: 5)),
        InjuryBodyPart(name: "Left Hand", shortName: "L Hand", shape: .leftHand, labelSize: 7, labelOffset: CGSize(width: -16, height: 12)),
        InjuryBodyPart(name: "Right Hand", shortName: "R Hand", shape: .rightHand, labelSize: 7, labelOffset: CGSize(width: 16, height: 12)),
        InjuryBodyPart(name: "Left Thigh", shortName: "L Thigh", shape: .leftThigh, labelSize: 7, labelOffset: CGSize(width: -7, height: -4)),
        InjuryBodyPart(name: "Right Thigh", shortName: "R Thigh", shape: .rightThigh, labelSize: 7, labelOffset: CGSize(width: 7, height: -4)),
        InjuryBodyPart(name: "Left Lower Leg", shortName: "L Leg", shape: .leftLowerLeg, labelSize: 7, labelOffset: CGSize(width: -8, height: 6)),
        InjuryBodyPart(name: "Right Lower Leg", shortName: "R Leg", shape: .rightLowerLeg, labelSize: 7, labelOffset: CGSize(width: 8, height: 6)),
        InjuryBodyPart(name: "Left Foot", shortName: "L Foot", shape: .leftFoot, labelSize: 7, labelOffset: CGSize(width: -16, height: 18)),
        InjuryBodyPart(name: "Right Foot", shortName: "R Foot", shape: .rightFoot, labelSize: 7, labelOffset: CGSize(width: 16, height: 18))
    ]
}

struct HumanBodySilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.addEllipse(in: scaledRect(x: 0.42, y: 0.035, width: 0.16, height: 0.13, in: rect))
        path.addRoundedRect(in: scaledRect(x: 0.455, y: 0.155, width: 0.09, height: 0.06, in: rect), cornerSize: CGSize(width: rect.width * 0.025, height: rect.height * 0.015))

        path.move(to: p(0.36, 0.215, rect))
        path.addCurve(to: p(0.64, 0.215, rect), control1: p(0.42, 0.19, rect), control2: p(0.58, 0.19, rect))
        path.addLine(to: p(0.69, 0.28, rect))
        path.addLine(to: p(0.80, 0.59, rect))
        path.addQuadCurve(to: p(0.72, 0.67, rect), control: p(0.84, 0.65, rect))
        path.addLine(to: p(0.63, 0.42, rect))
        path.addLine(to: p(0.61, 0.62, rect))
        path.addLine(to: p(0.57, 0.94, rect))
        path.addQuadCurve(to: p(0.47, 0.94, rect), control: p(0.52, 0.99, rect))
        path.addLine(to: p(0.50, 0.67, rect))
        path.addLine(to: p(0.43, 0.94, rect))
        path.addQuadCurve(to: p(0.33, 0.94, rect), control: p(0.38, 0.99, rect))
        path.addLine(to: p(0.39, 0.62, rect))
        path.addLine(to: p(0.37, 0.42, rect))
        path.addLine(to: p(0.28, 0.67, rect))
        path.addQuadCurve(to: p(0.20, 0.59, rect), control: p(0.16, 0.65, rect))
        path.addLine(to: p(0.31, 0.28, rect))
        path.closeSubpath()

        path.addRoundedRect(in: scaledRect(x: 0.315, y: 0.94, width: 0.12, height: 0.04, in: rect), cornerSize: CGSize(width: rect.width * 0.04, height: rect.height * 0.02))
        path.addRoundedRect(in: scaledRect(x: 0.565, y: 0.94, width: 0.12, height: 0.04, in: rect), cornerSize: CGSize(width: rect.width * 0.04, height: rect.height * 0.02))

        return path
    }
}

struct HumanBodyRegionShape: Shape {
    enum Kind {
        case head
        case neck
        case chest
        case abdomen
        case pelvis
        case leftUpperArm
        case rightUpperArm
        case leftForearm
        case rightForearm
        case leftHand
        case rightHand
        case leftThigh
        case rightThigh
        case leftLowerLeg
        case rightLowerLeg
        case leftFoot
        case rightFoot
    }

    let kind: Kind

    func path(in rect: CGRect) -> Path {
        switch kind {
        case .head:
            return Path(ellipseIn: scaledRect(x: 0.42, y: 0.035, width: 0.16, height: 0.13, in: rect))
        case .neck:
            return polygon([(0.455, 0.155), (0.545, 0.155), (0.56, 0.215), (0.44, 0.215)], in: rect)
        case .chest:
            return polygon([(0.36, 0.215), (0.64, 0.215), (0.625, 0.385), (0.375, 0.385)], in: rect)
        case .abdomen:
            return polygon([(0.375, 0.385), (0.625, 0.385), (0.60, 0.535), (0.40, 0.535)], in: rect)
        case .pelvis:
            return polygon([(0.40, 0.535), (0.60, 0.535), (0.62, 0.62), (0.54, 0.665), (0.50, 0.64), (0.46, 0.665), (0.38, 0.62)], in: rect)
        case .leftUpperArm:
            return polygon([(0.36, 0.225), (0.31, 0.28), (0.255, 0.445), (0.345, 0.455), (0.385, 0.35)], in: rect)
        case .rightUpperArm:
            return polygon([(0.64, 0.225), (0.615, 0.35), (0.655, 0.455), (0.745, 0.445), (0.69, 0.28)], in: rect)
        case .leftForearm:
            return polygon([(0.255, 0.445), (0.205, 0.59), (0.275, 0.625), (0.345, 0.455)], in: rect)
        case .rightForearm:
            return polygon([(0.745, 0.445), (0.655, 0.455), (0.725, 0.625), (0.795, 0.59)], in: rect)
        case .leftHand:
            return roundedRegion(x: 0.185, y: 0.585, width: 0.095, height: 0.08, in: rect)
        case .rightHand:
            return roundedRegion(x: 0.72, y: 0.585, width: 0.095, height: 0.08, in: rect)
        case .leftThigh:
            return polygon([(0.38, 0.62), (0.50, 0.64), (0.49, 0.785), (0.40, 0.785), (0.35, 0.64)], in: rect)
        case .rightThigh:
            return polygon([(0.50, 0.64), (0.62, 0.62), (0.65, 0.64), (0.60, 0.785), (0.51, 0.785)], in: rect)
        case .leftLowerLeg:
            return polygon([(0.40, 0.785), (0.49, 0.785), (0.465, 0.94), (0.335, 0.94)], in: rect)
        case .rightLowerLeg:
            return polygon([(0.51, 0.785), (0.60, 0.785), (0.665, 0.94), (0.535, 0.94)], in: rect)
        case .leftFoot:
            return roundedRegion(x: 0.315, y: 0.94, width: 0.12, height: 0.045, in: rect)
        case .rightFoot:
            return roundedRegion(x: 0.565, y: 0.94, width: 0.12, height: 0.045, in: rect)
        }
    }

    private func roundedRegion(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, in rect: CGRect) -> Path {
        Path(
            roundedRect: scaledRect(x: x, y: y, width: width, height: height, in: rect),
            cornerRadius: min(rect.width * width, rect.height * height) * 0.38
        )
    }
}

struct InjuryBodyPart: Identifiable {
    let name: String
    let shortName: String
    let shape: HumanBodyRegionShape.Kind
    var labelSize: CGFloat = 9
    var labelOffset: CGSize = .zero

    var id: String { name }

    func labelPoint(in size: CGSize) -> CGPoint {
        let base: (CGFloat, CGFloat)
        switch shape {
        case .head:
            base = (0.50, 0.10)
        case .neck:
            base = (0.50, 0.185)
        case .chest:
            base = (0.50, 0.30)
        case .abdomen:
            base = (0.50, 0.46)
        case .pelvis:
            base = (0.50, 0.59)
        case .leftUpperArm:
            base = (0.315, 0.335)
        case .rightUpperArm:
            base = (0.685, 0.335)
        case .leftForearm:
            base = (0.265, 0.535)
        case .rightForearm:
            base = (0.735, 0.535)
        case .leftHand:
            base = (0.23, 0.63)
        case .rightHand:
            base = (0.77, 0.63)
        case .leftThigh:
            base = (0.43, 0.72)
        case .rightThigh:
            base = (0.57, 0.72)
        case .leftLowerLeg:
            base = (0.42, 0.86)
        case .rightLowerLeg:
            base = (0.58, 0.86)
        case .leftFoot:
            base = (0.375, 0.962)
        case .rightFoot:
            base = (0.625, 0.962)
        }

        return CGPoint(
            x: size.width * base.0 + labelOffset.width,
            y: size.height * base.1 + labelOffset.height
        )
    }
}

func polygon(_ points: [(CGFloat, CGFloat)], in rect: CGRect) -> Path {
    var path = Path()
    guard let first = points.first else { return path }
    path.move(to: p(first.0, first.1, rect))
    for point in points.dropFirst() {
        path.addLine(to: p(point.0, point.1, rect))
    }
    path.closeSubpath()
    return path
}

func p(_ x: CGFloat, _ y: CGFloat, _ rect: CGRect) -> CGPoint {
    CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
}

func scaledRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, in rect: CGRect) -> CGRect {
    CGRect(
        x: rect.minX + rect.width * x,
        y: rect.minY + rect.height * y,
        width: rect.width * width,
        height: rect.height * height
    )
}

enum InjuryType: String, CaseIterable {
    case pain = "Pain"
    case bleeding = "Bleeding"
    case cut = "Cut"
    case bruise = "Bruise"
    case burn = "Burn"
    case swelling = "Swelling"
    case sprain = "Sprain"
    case fracture = "Possible fracture"
    case dislocation = "Possible dislocation"
    case other = "Other"
}

private struct RecordTreatmentTimelineEditor: View {
    @Binding var treatmentText: String
    let events: [TimelineEvent]
    let suggestions: [String]
    let onAdd: (String, String) -> Void

    @State private var query = ""
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Treatment".afLocalized)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.sceneAccent)
                    .textCase(.uppercase)
                Spacer()
                Text("Saved to timeline".afLocalized)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.sceneMuted)
            }

            tokenBlocks

            TextField("Type treatment, then press return".afLocalized, text: $query)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .submitLabel(.done)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
                .onSubmit(addTypedTreatment)

            if !filteredSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filteredSuggestions, id: \.self) { suggestion in
                            Button {
                                addTreatment(suggestion)
                            } label: {
                                Text(suggestion)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.sceneAccent)
                                    .padding(.horizontal, 10)
                                    .frame(height: 30)
                                    .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            TextField("Treatment note".afLocalized, text: $note)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 42)
                .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)

            if !events.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Treatment timeline".afLocalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.sceneMuted)

                    ForEach(events.prefix(4)) { event in
                        treatmentEventRow(event)
                    }
                }
            }
        }
    }

    private var tokenBlocks: some View {
        Group {
            if tokens.isEmpty {
                Text("No treatment added.".afLocalized)
                    .font(.footnote)
                    .foregroundStyle(Color.sceneMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .liquidGlass(tint: Color.sceneAccent, opacity: 0.06)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tokens, id: \.self) { token in
                            HStack(spacing: 6) {
                                Text(token)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.black)
                                    .lineLimit(1)

                                Button {
                                    removeToken(token)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.black.opacity(0.62))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 32)
                            .background(Color.sceneAccent, in: Capsule())
                        }
                    }
                }
            }
        }
    }

    private func treatmentEventRow(_ event: TimelineEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(DateFormatter.sceneTime.string(from: event.timestamp))
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(Color.sceneAccent)
                .frame(width: 46, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(AppStrings.display(event.title))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                if let detail = event.detail, !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(AppStrings.display(detail))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.sceneMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.07)
    }

    private var tokens: [String] {
        treatmentText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var filteredSuggestions: [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return suggestions
            .filter { $0.localizedCaseInsensitiveContains(trimmed) && !tokens.recordContainsCaseInsensitive($0) }
            .prefix(10)
            .map { $0 }
    }

    private func addTypedTreatment() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let exactMatch = suggestions.first { $0.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        addTreatment(exactMatch ?? trimmed)
    }

    private func addTreatment(_ treatment: String) {
        let trimmed = treatment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !tokens.recordContainsCaseInsensitive(trimmed) {
            var updated = tokens
            updated.append(trimmed)
            treatmentText = updated.joined(separator: ", ")
        }
        onAdd(trimmed, note)
        query = ""
        note = ""
    }

    private func removeToken(_ token: String) {
        treatmentText = tokens
            .filter { $0.compare(token, options: [.caseInsensitive, .diacriticInsensitive]) != .orderedSame }
            .joined(separator: ", ")
    }
}

private struct RecordSuggestedTokenField: View {
    let title: String
    let emptyMessage: String
    let placeholder: String
    @Binding var text: String
    let database: [String]
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)

            if tokens.isEmpty {
                Text(emptyMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.sceneMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .liquidGlass(tint: Color.sceneAccent, opacity: 0.06)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tokens, id: \.self) { token in
                            HStack(spacing: 6) {
                                Text(token)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.black)
                                    .lineLimit(1)

                                Button {
                                    removeToken(token)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.black.opacity(0.62))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 32)
                            .background(Color.sceneAccent, in: Capsule())
                        }
                    }
                }
            }

            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .submitLabel(.done)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
                .onSubmit(addTypedToken)

            if !filteredSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filteredSuggestions, id: \.self) { suggestion in
                            Button {
                                addToken(suggestion)
                            } label: {
                                Text(suggestion)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.sceneAccent)
                                    .padding(.horizontal, 10)
                                    .frame(height: 30)
                                    .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var tokens: [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var filteredSuggestions: [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return database
            .filter { $0.localizedCaseInsensitiveContains(trimmed) && !tokens.recordContainsCaseInsensitive($0) }
            .prefix(12)
            .map { $0 }
    }

    private func addTypedToken() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let exactMatch = database.first { $0.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        addToken(exactMatch ?? trimmed)
    }

    private func addToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !tokens.recordContainsCaseInsensitive(trimmed) else {
            query = ""
            return
        }

        var updated = tokens
        updated.append(trimmed)
        text = updated.joined(separator: ", ")
        query = ""
    }

    private func removeToken(_ token: String) {
        text = tokens
            .filter { $0.compare(token, options: [.caseInsensitive, .diacriticInsensitive]) != .orderedSame }
            .joined(separator: ", ")
    }
}

private struct RecordAllergenDatabase {
    static let shared = RecordAllergenDatabase()
    let names: [String]

    private init() {
        guard let url = Bundle.main.url(forResource: "CommonAllergens", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            names = ["Peanuts", "Tree Nuts", "Milk", "Eggs", "Latex"]
            return
        }

        names = decoded
    }
}

private struct RecordMedicationDatabase {
    static let shared = RecordMedicationDatabase()
    let names: [String]

    private init() {
        guard let url = Bundle.main.url(forResource: "MedicationNames", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            names = ["Adrenaline", "Aspirin", "Ibuprofen", "Paracetamol", "Salbutamol"]
            return
        }

        names = decoded
    }
}

private struct RecordMedicalHistoryDatabase {
    static let shared = RecordMedicalHistoryDatabase()
    let conditions: [String]

    private init() {
        guard let url = Bundle.main.url(forResource: "MedicalHistoryConditions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            conditions = ["Asthma", "Diabetes Mellitus", "Epilepsy", "Hypertension"]
            return
        }

        conditions = decoded
    }
}

private struct RecordTreatmentDatabase {
    static let shared = RecordTreatmentDatabase()
    let names = [
        "Reassurance",
        "Rest",
        "Positioned for comfort",
        "Recovery position",
        "Oxygen therapy",
        "CPR",
        "AED attached",
        "Shock delivered",
        "Bleeding control",
        "Direct pressure",
        "Dressing applied",
        "Bandage applied",
        "Cold pack",
        "Splint applied",
        "Wound cleaned",
        "Salbutamol assisted",
        "Adrenaline autoinjector assisted",
        "Glucose given",
        "Oral fluids",
        "Cooling measures",
        "Blanket applied",
        "Monitored vital signs",
        "Ambulance called"
    ]
}

private extension [String] {
    func recordContainsCaseInsensitive(_ value: String) -> Bool {
        contains { $0.compare(value, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }
}

private extension PatientProfile {
    var treatmentTokens: [String] {
        treatment.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private extension String {
    var trimmedField: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    var casefoldedKey: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

private enum RecordDateHelper {
    static func age(from dobText: String) -> String {
        guard let dob = date(from: dobText) else { return "" }
        let components = Calendar.current.dateComponents([.year], from: dob, to: Date())
        guard let years = components.year, years >= 0 else { return "" }
        return "\(years)"
    }

    static func date(from dobText: String) -> Date? {
        let trimmed = dobText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return formatters.compactMap { $0.date(from: trimmed) }.first
    }

    static func string(from date: Date) -> String {
        outputFormatter.string(from: date)
    }

    private static let formatters: [DateFormatter] = ["dd/MM/yyyy", "d/M/yyyy", "yyyy-MM-dd"].map { format in
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_AU")
        return formatter
    }

    private static let outputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.locale = Locale(identifier: "en_AU")
        return formatter
    }()
}
