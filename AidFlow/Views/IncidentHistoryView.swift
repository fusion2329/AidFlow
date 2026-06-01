import SwiftUI

struct IncidentHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: HistorySection = .patient

    init(initialSection: HistorySection = .patient) {
        _selectedSection = State(initialValue: initialSection)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LiquidGlassBackground()

                VStack(spacing: 14) {
                    Picker("History section".afLocalized, selection: $selectedSection) {
                        ForEach(HistorySection.allCases) { section in
                            Text(AppStrings.display(section.rawValue)).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch selectedSection {
                    case .patient:
                        PatientHistoryView()
                    case .timeline:
                        TimelineViewContent()
                    }
                }
                .padding(20)
            }
            .developerScreenID(
                selectedSection == .patient ? "220001" : "220002",
                "IncidentHistoryView.\(selectedSection.rawValue)"
            )
            .navigationTitle("History".afLocalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done".afLocalized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

enum HistorySection: String, CaseIterable, Identifiable {
    case patient = "Patient"
    case timeline = "Timeline"

    var id: String { rawValue }
}

private struct PatientHistoryView: View {
    @EnvironmentObject private var incidentStore: IncidentStore
    @AppStorage("userProfile.name") private var responderName = ""
    @AppStorage("userProfile.signatureRank") private var responderRank = ""
    @AppStorage("userProfile.signatureDivision") private var responderDivision = ""
    @AppStorage("userProfile.signatureMemberID") private var responderMemberID = ""
    @AppStorage("developerModeEnabled") private var developerModeEnabled = false
    @State private var profile = PatientProfile()
    @State private var patientNotes = ""
    @State private var patientAddressSearch = ""
    @State private var dateOfBirth = Date()
    @State private var selectedBodySide: InjuryBodySide = .front
    @State private var selectedInjuryType = InjuryType.pain.rawValue
    @State private var vitalSigns: [VitalSignsRecord] = []
    @State private var editingVitalSigns: VitalSignsRecord?
    @State private var showingGCSCapture = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                patientIdentity
                sampleHistory
                treatmentSection
                vitalSignsSection
                notesBox
            }
            .padding(.vertical, 4)
        }
        .onAppear {
            profile = incidentStore.currentIncident?.patientProfile ?? PatientProfile()
            if profile.emergencyContactPhone.isEmpty, !profile.emergencyContact.isEmpty {
                profile.emergencyContactPhone = profile.emergencyContact
            }
            dateOfBirth = PatientAgeCalculator.date(from: profile.dateOfBirth) ?? Date()
            patientNotes = incidentStore.currentIncident?.patientNotes ?? ""
            vitalSigns = incidentStore.currentIncident?.vitalSigns ?? []
            if patientAddressSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                patientAddressSearch = currentPatientAddressText
            }
        }
        .onChange(of: dateOfBirth) { newValue in
            profile.dateOfBirth = PatientAgeCalculator.string(from: newValue)
        }
        .onChange(of: profile) { _ in saveProfile() }
        .onChange(of: patientNotes) { newValue in
            incidentStore.updatePatientNotes(newValue)
        }
        .sheet(item: $editingVitalSigns) { record in
            VitalSignsEditorView(record: record) { updatedRecord in
                saveVitalSigns(updatedRecord)
            }
        }
        .navigationDestination(isPresented: $showingGCSCapture) {
            HistoryGCSCaptureView { record in
                saveVitalSigns(record)
            }
        }
    }

    private var patientIdentity: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Patient Details".afLocalized)

            if developerModeEnabled {
                HStack(spacing: 10) {
                    PatientHistoryField(title: "First name".afLocalized, text: $profile.firstName)
                    PatientHistoryField(title: "Surname".afLocalized, text: $profile.surname)
                }

                PatientDateField(title: "Date of Birth".afLocalized, date: $dateOfBirth)
            }

            HStack(spacing: 10) {
                Group {
                    if developerModeEnabled {
                        PatientAgeBadge(age: calculatedAge)
                    } else {
                        PatientHistoryField(title: "Age".afLocalized, text: $profile.age, keyboardType: .numberPad)
                    }
                }
                .frame(maxWidth: 120)

                PatientHistoryPickerField(title: "Sex".afLocalized, selection: $profile.sex) {
                    ForEach(PatientSexOption.allCases) { option in
                        Text(AppStrings.display(option.rawValue)).tag(option.rawValue)
                    }
                }
            }

            if developerModeEnabled {
                sectionTitle("Patient Address".afLocalized)

                MapAddressField(title: "Search patient address".afLocalized, text: $patientAddressSearch) { resolved in
                    applyPatientAddress(resolved)
                }

                HStack(spacing: 10) {
                    PatientHistoryField(title: "Unit".afLocalized, text: $profile.patientUnit)
                    PatientHistoryField(title: "Street".afLocalized, text: $profile.patientStreet)
                }

                HStack(spacing: 10) {
                    PatientHistoryField(title: "Suburb".afLocalized, text: $profile.patientSuburb)
                    PatientHistoryField(title: "State".afLocalized, text: $profile.patientState)
                    PatientHistoryField(title: "Postcode".afLocalized, text: $profile.patientPostcode, keyboardType: .numberPad)
                }

                PatientHistoryField(title: "Contact detail".afLocalized, text: $profile.patientContactDetail, keyboardType: .phonePad)
            }
        }
        .historyCard()
    }

    private var sampleHistory: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Medical History".afLocalized)

            SuggestedTokenField(
                title: "Allergies".afLocalized,
                emptyMessage: "No allergies added.".afLocalized,
                placeholder: "Type allergen, then press return".afLocalized,
                text: $profile.allergies,
                database: AllergenDatabase.shared.names
            )
            SuggestedTokenField(
                title: "Medications".afLocalized,
                emptyMessage: "No medications added.".afLocalized,
                placeholder: "Type medication, then press return".afLocalized,
                text: $profile.medications,
                database: MedicationDatabase.shared.names
            )
            SuggestedTokenField(
                title: "Medical history".afLocalized,
                emptyMessage: "No medical history added.".afLocalized,
                placeholder: "Type condition, then press return".afLocalized,
                text: $profile.medicalHistory,
                database: MedicalHistoryDatabase.shared.conditions
            )

            sectionTitle("Event / Injury".afLocalized)

            plannedEventPanel
            PatientHistoryField(title: "Event name".afLocalized, text: $profile.eventName)
            MapAddressField(title: "Event location".afLocalized, text: $profile.eventLocation)
            PatientHistoryField(title: "Event time".afLocalized, text: $profile.eventStartTime)
            PatientHistoryField(title: "Event History".afLocalized, text: $profile.eventHistory)
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
        TreatmentTimelineEditor(
            treatmentText: $profile.treatment,
            events: treatmentTimelineEvents,
            suggestions: TreatmentDatabase.shared.names
        ) { treatment, note in
            addTreatmentToTimeline(treatment, note: note)
        }
        .historyCard()
    }

    private var treatmentTimelineEvents: [TimelineEvent] {
        incidentStore.currentIncident?.timeline
            .filter { $0.category == .treatment }
            .sorted { $0.timestamp > $1.timestamp } ?? []
    }

    private var plannedEventPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Planned event".afLocalized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)

            if availablePlannedEvents.isEmpty {
                Text("No upcoming planned events.".afLocalized)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .liquidGlass(tint: Color.sceneAccent, opacity: 0.07)
            } else {
                Menu {
                    ForEach(availablePlannedEvents) { event in
                        Button {
                            profile.applyPlannedEvent(event)
                            incidentStore.applyPlannedEventToCurrentIncident(event)
                        } label: {
                            HStack {
                                Text(plannedEventTitle(event))
                                if selectedPlannedEvent?.id == event.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Label(
                            selectedPlannedEvent.map(plannedEventTitle) ?? "Apply planned event".afLocalized,
                            systemImage: selectedPlannedEvent == nil ? "calendar.badge.plus" : "calendar.badge.checkmark"
                        )
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SceneSecondaryButtonStyle())
            }
        }
    }

    private var availablePlannedEvents: [PlannedEvent] {
        incidentStore.plannedEvents.sorted { left, right in
            if left.isUpcoming != right.isUpcoming {
                return left.isUpcoming && !right.isUpcoming
            }
            return left.isUpcoming ? left.startsAt < right.startsAt : left.startsAt > right.startsAt
        }
    }

    private var selectedPlannedEvent: PlannedEvent? {
        availablePlannedEvents.first { event in
            let template = event.profileTemplate
            return matchesPlannedEventField(profile.eventName, template.eventName)
                && matchesPlannedEventField(profile.eventLocation, template.eventLocation)
                && matchesPlannedEventField(profile.eventStartTime, template.eventStartTime)
        } ?? availablePlannedEvents.first { event in
            let template = event.profileTemplate
            return !profile.eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && matchesPlannedEventField(profile.eventName, template.eventName)
        }
    }

    private func plannedEventTitle(_ event: PlannedEvent) -> String {
        event.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled event".afLocalized : event.name
    }

    private func matchesPlannedEventField(_ left: String, _ right: String) -> Bool {
        left.trimmingCharacters(in: .whitespacesAndNewlines)
            .compare(right.trimmingCharacters(in: .whitespacesAndNewlines), options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    private var notesBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            if developerModeEnabled {
                sectionTitle("Emergency Contact Detail".afLocalized)

                HStack(spacing: 10) {
                    PatientHistoryField(title: "Name".afLocalized, text: $profile.emergencyContactDetailName)
                    PatientHistoryField(title: "Contact detail".afLocalized, text: $profile.emergencyContactDetail, keyboardType: .phonePad)
                }
            }

            sectionTitle("Notes".afLocalized)

            TextEditor(text: $patientNotes)
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
                .frame(minHeight: 110)
                .padding(10)
                .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)

            Divider()
                .overlay(Color.white.opacity(0.12))

            Toggle(isOn: signatureBinding) {
                VStack(alignment: .leading, spacing: 3) {
                    sectionTitle("Signature".afLocalized)
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

    private var vitalSignsSection: some View {
        VitalSignsSectionView(
            records: vitalSigns,
            onAdd: {
                editingVitalSigns = VitalSignsRecord()
            },
            onGCSCapture: {
                showingGCSCapture = true
            },
            onEdit: { record in
                editingVitalSigns = record
            },
            onDelete: { record in
                vitalSigns.removeAll { $0.id == record.id }
                incidentStore.deleteVitalSigns(id: record.id)
            }
        )
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
                saveProfile()
            }
        )
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.sceneAccent)
            .textCase(.uppercase)
    }

    private func saveProfile() {
        var profileToSave = profile
        profileToSave.fullName = [profileToSave.firstName, profileToSave.surname]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if developerModeEnabled {
            profileToSave.age = calculatedAge
        } else {
            profileToSave.removeIdentityDetails()
        }
        incidentStore.updatePatientProfile(profileToSave)
    }

    private func addTreatmentToTimeline(_ treatment: String, note: String) {
        let cleanTreatment = treatment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTreatment.isEmpty else { return }

        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = cleanNote.isEmpty ? cleanTreatment : "\(cleanTreatment)\nNote: \(cleanNote)"
        incidentStore.addTimelineEvent(
            title: "Treatment given",
            detail: detail,
            category: .treatment,
            timestamp: Date()
        )
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

    private func saveVitalSigns(_ record: VitalSignsRecord) {
        if let index = vitalSigns.firstIndex(where: { $0.id == record.id }) {
            vitalSigns[index] = record
            incidentStore.updateVitalSigns(record)
        } else {
            vitalSigns.append(record)
            incidentStore.addVitalSigns(record)
        }
        vitalSigns.sort { $0.recordedAt < $1.recordedAt }
        editingVitalSigns = nil
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

    private var calculatedAge: String {
        PatientAgeCalculator.age(from: profile.dateOfBirth)
    }
}

private struct HistoryGCSCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step: HistoryGCSStep = .eye
    @State private var eye: HistoryGCSOption?
    @State private var verbal: HistoryGCSOption?
    @State private var motor: HistoryGCSOption?
    let onSave: (VitalSignsRecord) -> Void

    private var totalScore: Int {
        (eye?.score ?? 0) + (verbal?.score ?? 0) + (motor?.score ?? 0)
    }

    private var isComplete: Bool {
        eye != nil && verbal != nil && motor != nil
    }

    private var currentOptions: [HistoryGCSOption] {
        switch step {
        case .eye:
            return HistoryGCSOption.eye
        case .verbal:
            return HistoryGCSOption.verbal
        case .motor:
            return HistoryGCSOption.motor
        case .result:
            return []
        }
    }

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            VStack(alignment: .leading, spacing: 14) {
                header
                progressCard

                if step == .result {
                    resultCard
                } else {
                    questionCard
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .developerScreenID("100019", "HistoryGCSCaptureView")
        .navigationTitle("Record GCS".afLocalized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Glasgow Coma Scale".afLocalized)
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Complete the score here to save it directly into this incident's vital signs.".afLocalized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .historyCard()
    }

    private var progressCard: some View {
        HStack(spacing: 8) {
            scoreChip("E", value: eye?.score)
            scoreChip("V", value: verbal?.score)
            scoreChip("M", value: motor?.score)
            scoreChip("Total".afLocalized, value: isComplete ? totalScore : nil)
        }
        .padding(10)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.09)
    }

    private func scoreChip(_ label: String, value: Int?) -> some View {
        VStack(spacing: 4) {
            Text(value.map(String.init) ?? "-")
                .font(.headline.monospacedDigit().weight(.bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.sceneMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.07)
    }

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(step.title)
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text(step.progressTitle)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(Color.sceneMuted)
            }

            Text(step.prompt)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)

            ForEach(currentOptions) { option in
                Button {
                    select(option)
                } label: {
                    HStack(spacing: 12) {
                        Text("\(option.score)")
                            .font(.headline.monospacedDigit().weight(.bold))
                            .foregroundStyle(.black)
                            .frame(width: 34, height: 34)
                            .background(Color.sceneAccent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(option.title.afLocalized)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                            Text(option.detail.afLocalized)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.sceneMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: selectedOption == option ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedOption == option ? Color.sceneAccent : Color.sceneMuted)
                    }
                    .padding(10)
                    .liquidGlass(tint: selectedOption == option ? Color.sceneAccent : Color.sceneAccent.opacity(0.6), opacity: selectedOption == option ? 0.15 : 0.07)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Button {
                    goBack()
                } label: {
                    Label("Go Back".afLocalized, systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SceneSecondaryButtonStyle())
                .disabled(step == .eye)

                Button {
                    goNext()
                } label: {
                    Label("Continue".afLocalized, systemImage: "chevron.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ScenePrimaryButtonStyle())
                .disabled(selectedOption == nil)
            }
        }
        .historyCard()
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Final GCS".afLocalized)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text(resultSummary)
                        .font(.subheadline.monospacedDigit().weight(.bold))
                        .foregroundStyle(Color.sceneAccent)
                }

                Spacer()

                Text("\(totalScore)")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }

            Text("This will create a new vital signs entry for the current incident.".afLocalized)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)

            Button {
                saveResult()
            } label: {
                Label("Save GCS to Vitals".afLocalized, systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ScenePrimaryButtonStyle())

            Button {
                restart()
            } label: {
                Label("Start Again".afLocalized, systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SceneSecondaryButtonStyle())
        }
        .historyCard()
    }

    private var selectedOption: HistoryGCSOption? {
        switch step {
        case .eye:
            return eye
        case .verbal:
            return verbal
        case .motor:
            return motor
        case .result:
            return nil
        }
    }

    private var resultSummary: String {
        AppStrings.text("GCS %@ = E%@ V%@ M%@", "\(totalScore)", "\(eye?.score ?? 0)", "\(verbal?.score ?? 0)", "\(motor?.score ?? 0)")
    }

    private func select(_ option: HistoryGCSOption) {
        switch step {
        case .eye:
            eye = option
        case .verbal:
            verbal = option
        case .motor:
            motor = option
        case .result:
            break
        }
    }

    private func goNext() {
        switch step {
        case .eye:
            step = .verbal
        case .verbal:
            step = .motor
        case .motor:
            step = .result
        case .result:
            break
        }
    }

    private func goBack() {
        switch step {
        case .eye:
            break
        case .verbal:
            step = .eye
        case .motor:
            step = .verbal
        case .result:
            step = .motor
        }
    }

    private func restart() {
        eye = nil
        verbal = nil
        motor = nil
        step = .eye
    }

    private func saveResult() {
        let record = VitalSignsRecord(gcsScore: "\(totalScore)", notes: resultSummary)
        onSave(record)
        dismiss()
    }
}

private enum HistoryGCSStep {
    case eye
    case verbal
    case motor
    case result

    var title: String {
        switch self {
        case .eye:
            return "Eye Opening".afLocalized
        case .verbal:
            return "Verbal Response".afLocalized
        case .motor:
            return "Motor Response".afLocalized
        case .result:
            return "GCS Result".afLocalized
        }
    }

    var prompt: String {
        switch self {
        case .eye:
            return "What is the best eye response observed?".afLocalized
        case .verbal:
            return "What is the best verbal response observed?".afLocalized
        case .motor:
            return "What is the best motor response observed?".afLocalized
        case .result:
            return "Calculated score".afLocalized
        }
    }

    var progressTitle: String {
        switch self {
        case .eye:
            return "Step 1 of 3".afLocalized
        case .verbal:
            return "Step 2 of 3".afLocalized
        case .motor:
            return "Step 3 of 3".afLocalized
        case .result:
            return "Result".afLocalized
        }
    }
}

private struct HistoryGCSOption: Identifiable, Hashable {
    let id: String
    let score: Int
    let title: String
    let detail: String

    static let eye = [
        HistoryGCSOption(id: "eye-4", score: 4, title: "Spontaneous", detail: "Eyes open without being asked"),
        HistoryGCSOption(id: "eye-3", score: 3, title: "To speech", detail: "Opens eyes when spoken to"),
        HistoryGCSOption(id: "eye-2", score: 2, title: "To pain", detail: "Opens eyes only to painful stimulus"),
        HistoryGCSOption(id: "eye-1", score: 1, title: "No eye opening", detail: "No eye response observed")
    ]

    static let verbal = [
        HistoryGCSOption(id: "verbal-5", score: 5, title: "Orientated", detail: "Knows person, place, time, and situation"),
        HistoryGCSOption(id: "verbal-4", score: 4, title: "Confused", detail: "Talks but is disorientated"),
        HistoryGCSOption(id: "verbal-3", score: 3, title: "Inappropriate words", detail: "Random or unsuitable words"),
        HistoryGCSOption(id: "verbal-2", score: 2, title: "Sounds only", detail: "Moans or makes sounds, no words"),
        HistoryGCSOption(id: "verbal-1", score: 1, title: "No verbal response", detail: "No voice response observed")
    ]

    static let motor = [
        HistoryGCSOption(id: "motor-6", score: 6, title: "Obeys commands", detail: "Performs simple requested movement"),
        HistoryGCSOption(id: "motor-5", score: 5, title: "Localises pain", detail: "Moves hand toward painful stimulus"),
        HistoryGCSOption(id: "motor-4", score: 4, title: "Withdraws from pain", detail: "Pulls away from painful stimulus"),
        HistoryGCSOption(id: "motor-3", score: 3, title: "Abnormal flexion", detail: "Flexes arms abnormally to pain"),
        HistoryGCSOption(id: "motor-2", score: 2, title: "Abnormal extension", detail: "Extends arms abnormally to pain"),
        HistoryGCSOption(id: "motor-1", score: 1, title: "No motor response", detail: "No movement response observed")
    ]
}

private struct PatientHistoryField: View {
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

private struct PatientAgeBadge: View {
    let age: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Age".afLocalized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)

            Text(age.isEmpty ? "Not set".afLocalized : age)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
        }
    }
}

private struct PatientDateField: View {
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

private struct TreatmentTimelineEditor: View {
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
                Text("Timeline linked".afLocalized)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.sceneMuted)
            }

            tokenBlocks

            VStack(alignment: .leading, spacing: 8) {
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
            }

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
            .filter { $0.localizedCaseInsensitiveContains(trimmed) && !tokens.containsCaseInsensitive($0) }
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
        if !tokens.containsCaseInsensitive(trimmed) {
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

private struct SuggestedTokenField: View {
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

            tokenBlocks

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

    private var tokenBlocks: some View {
        Group {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
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
            .filter { $0.localizedCaseInsensitiveContains(trimmed) && !tokens.containsCaseInsensitive($0) }
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
        guard !trimmed.isEmpty, !tokens.containsCaseInsensitive(trimmed) else {
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

private struct MedicationDatabase {
    static let shared = MedicationDatabase()
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

private struct AllergenDatabase {
    static let shared = AllergenDatabase()
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

private struct MedicalHistoryDatabase {
    static let shared = MedicalHistoryDatabase()
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

private struct TreatmentDatabase {
    static let shared = TreatmentDatabase()
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
    func containsCaseInsensitive(_ value: String) -> Bool {
        contains { $0.compare(value, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }
}

private enum PatientAgeCalculator {
    static func age(from dobText: String) -> String {
        let trimmed = dobText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        guard let dob = date(from: trimmed) else { return "" }
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

private enum PatientSexOption: String, CaseIterable, Identifiable {
    case female = "Female"
    case male = "Male"

    var id: String { rawValue }
}

private struct PatientHistoryPickerField<Content: View>: View {
    let title: String
    @Binding var selection: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)

            Picker(title, selection: $selection) {
                content()
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
        }
    }
}

extension View {
    func historyCard() -> some View {
        padding(14)
            .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
    }
}
