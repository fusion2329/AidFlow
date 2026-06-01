import SwiftUI
import MapKit

private enum EmergencyGuidanceSource {
    case guided
    case manual
}

struct ArrivalModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var incidentStore: IncidentStore
    @StateObject private var locationManager = LocationManager()
    @State private var stepIndex = 0
    @State private var stepNote = ""
    @State private var didRecordLocation = false
    @State private var showingTimeline = false
    @State private var historyInitialSection: HistorySection = .patient
    @State private var showingHandover = false
    @State private var showingUnsafeSceneAlert = false
    @State private var emergencyGuidanceMode = false
    @State private var emergencyGuidanceSource = EmergencyGuidanceSource.guided
    @State private var showingLocationMap = false
    @State private var showingStepHelp = false
    @State private var showingQuickCare = false
    @State private var showingCPRCounter = false
    @State private var lastMonitoringCheck = Date()

    private var currentStep: ArrivalStep? {
        guard ArrivalFlow.steps.indices.contains(stepIndex) else { return nil }
        return ArrivalFlow.steps[stepIndex]
    }

    private var displayedStepNumber: Int {
        min(max(stepIndex + 1, 1), ArrivalFlow.steps.count)
    }

    private var stepProgress: Double {
        guard !ArrivalFlow.steps.isEmpty else { return 1 }
        return Double(displayedStepNumber) / Double(ArrivalFlow.steps.count)
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            VStack(spacing: 12) {
                header

                mainChecklistContent

                if !emergencyGuidanceMode {
                    actionBar
                    locationStatusPanel
                }
            }
            .padding(16)
        }
        .developerScreenID("210001", "ArrivalModeView")
        .navigationTitle("Arrival Mode".afLocalized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    historyInitialSection = .patient
                    showingTimeline = true
                } label: {
                    HStack(spacing: 6) {
                        Text("History".afLocalized)
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .accessibilityLabel("Open history".afLocalized)
            }
        }
        .sheet(isPresented: $showingTimeline) {
            IncidentHistoryView(initialSection: historyInitialSection)
        }
        .sheet(isPresented: $showingHandover) {
            HandoverView {
                showingHandover = false
                dismiss()
            }
        }
        .sheet(isPresented: $showingLocationMap) {
            if let location = incidentStore.currentIncident?.location {
                IncidentMapView(location: location)
            }
        }
        .sheet(isPresented: $showingStepHelp) {
            if let currentStep {
                ArrivalStepHelpSheet(step: currentStep)
                    .presentationDetents([.height(stepHelpSheetHeight(for: currentStep))])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingQuickCare) {
            QuickCareSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingCPRCounter) {
            NavigationStack {
                CPRCounterView(
                    onPatientRecovered: {
                        LiveActivityManager.shared.updateCPRState(nil, for: incidentStore.currentIncident)
                        incidentStore.record(
                            title: "Patient awake or breathing during CPR",
                            detail: "CPR counter stopped. Move to recovery position if appropriate and monitor breathing.",
                            category: .assessment
                        )
                        showingCPRCounter = false
                        jumpToMonitoring()
                    },
                    onCPRStateChange: { state in
                        LiveActivityManager.shared.updateCPRState(state, for: incidentStore.currentIncident)
                    }
                )
            }
        }
        .alert("Unsafe scene".afLocalized, isPresented: $showingUnsafeSceneAlert) {
            Button("Call 000".afLocalized, role: .destructive) {
                showEmergencyGuidance(title: "000 call prompted from unsafe scene")
            }

            Button("Scene is safe now".afLocalized) {
                advanceToNextStep()
            }
        } message: {
            Text("Do not approach. Stay back, move away or keep a safe distance, warn others, and call 000 if emergency services are needed.".afLocalized)
        }
        .onReceive(locationManager.$snapshot) { snapshot in
            guard let snapshot, !didRecordLocation else { return }
            didRecordLocation = true
            incidentStore.updateLocation(snapshot)
        }
        .onChange(of: incidentStore.hasLoadedDatabase) { _ in
            prepareIncidentIfNeeded()
        }
        .onAppear {
            prepareIncidentIfNeeded()
            locationManager.requestLocation()
        }
    }

    private var mainChecklistContent: some View {
        VStack(spacing: 10) {
            if emergencyGuidanceMode {
                inlineEmergencyGuidance
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            } else if let step = currentStep {
                stepPanel(step)
                    .id("panel-\(step.id)")
                    .transition(reduceMotion ? .opacity : stepTransition)

                if step.id == "monitoring" {
                    monitoringActionGrid
                        .id("monitoring-\(step.id)")
                        .transition(reduceMotion ? .opacity : stepTransition)
                } else {
                    responseButtons(for: step)
                        .id("responses-\(step.id)")
                        .transition(reduceMotion ? .opacity : stepTransition)
                }
            } else {
                completedPanel
                    .transition(reduceMotion ? .opacity : stepTransition)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86), value: emergencyGuidanceMode)
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88), value: stepIndex)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                stepCounterBadge

                Spacer(minLength: 12)

                elapsedTimerBadge
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Live Incident".afLocalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.sceneAccent)
                Text("One step at a time".afLocalized)
                    .font(.headline.bold())
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            stepProgressBar
        }
    }

    private var stepProgressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.10))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.sceneAccent, Color.sceneSafe],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, proxy.size.width * CGFloat(stepProgress)))
            }
        }
        .frame(height: 6)
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.90), value: stepProgress)
        .accessibilityLabel("Arrival mode progress".afLocalized)
    }

    private func stepHelpSheetHeight(for step: ArrivalStep) -> CGFloat {
        let itemHeight = CGFloat(step.helpItems.count) * 74
        let warningHeight: CGFloat = (step.warningText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? 58 : 0
        let baseHeight: CGFloat = 126
        return min(max(baseHeight + itemHeight + warningHeight, 310), 470)
    }

    @ViewBuilder
    private var elapsedTimerBadge: some View {
        if let startedAt = incidentStore.currentIncident?.startedAt {
            VStack(alignment: .trailing, spacing: 2) {
                Text("Elapsed".afLocalized)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.sceneMuted)
                    .textCase(.uppercase)
                Text(startedAt, style: .timer)
                    .font(.headline.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .liquidGlass(tint: Color.sceneAccent, opacity: 0.12)
        }
    }

    private var stepCounterBadge: some View {
        HStack(spacing: 8) {
            Button {
                goBackOneStep()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.bold))
                    .frame(width: 28, height: 28)
            }
            .disabled(stepIndex == 0)
            .foregroundStyle(stepIndex == 0 ? Color.sceneMuted.opacity(0.45) : .white)
            .accessibilityLabel("Previous question".afLocalized)

            Text("\(displayedStepNumber)/\(ArrivalFlow.steps.count)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)

            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 1, height: 20)

            Button {
                showingQuickCare = true
            } label: {
                Image(systemName: "bolt.heart.fill")
                    .font(.headline.weight(.bold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(SceneCardButtonStyle())
            .foregroundStyle(Color.sceneWarning)
            .accessibilityLabel("Open quick care".afLocalized)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.12)
    }

    @ViewBuilder
    private func stepPanel(_ step: ArrivalStep) -> some View {
        if step.id == "monitoring" {
            monitoringStepPanel(step)
        } else {
            standardStepPanel(step)
        }
    }

    private func monitoringStepPanel(_ step: ArrivalStep) -> some View {
        Text(AppStrings.display(step.prompt))
            .font(.system(size: 27, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .frame(height: 62)
            .liquidGlass(tint: Color.sceneAccent, opacity: 0.12)
    }

    private func standardStepPanel(_ step: ArrivalStep) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text(AppStrings.display(step.title).uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.sceneMuted)

                Spacer(minLength: 8)

                Button {
                    showingStepHelp = true
                } label: {
                    Label("How to do".afLocalized, systemImage: "questionmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.11), in: Capsule())
                }
                .buttonStyle(SceneCardButtonStyle())
                .foregroundStyle(Color.sceneAccent)
                .accessibilityLabel("How to do this step".afLocalized)
            }

            Text(AppStrings.display(step.prompt))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.60)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Text(AppStrings.display(step.actionPrompt))
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)

            if step.id == "send-help" {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.heart.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.sceneWarning)
                    Text("Ask for AED if available.".afLocalized)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.sceneWarning)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .liquidGlass(tint: Color.sceneWarning, opacity: 0.10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.14)
    }

    private var stepNotePanel: some View {
        TextField(
            "",
            text: $stepNote,
            prompt: Text("Note".afLocalized).foregroundColor(Color.sceneMuted)
        )
            .textFieldStyle(.plain)
            .foregroundStyle(.white)
            .tint(Color.sceneAccent)
            .lineLimit(1)
            .submitLabel(.done)
            .padding(.horizontal, 12)
            .frame(height: 48)
            .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
    }

    private func responseButtons(for step: ArrivalStep) -> some View {
        VStack(spacing: 8) {
            SceneResponseButton(title: AppStrings.display(step.yesLabel), color: .sceneSafe) {
                answer(step.yesEvent, category: step.category, action: step.yesAction)
            }

            SceneResponseButton(title: AppStrings.display(step.noLabel), color: .sceneDanger) {
                answer(step.noEvent, category: step.category, action: step.noAction)
            }

            if !step.unsureLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                SceneResponseButton(title: AppStrings.display(step.unsureLabel), color: .sceneWarning) {
                    answer(step.unsureEvent, category: step.category, action: step.unsureAction)
                }
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                showManualEmergencyGuidance()
            } label: {
                Label("000", systemImage: "phone.fill")
            }
            .font(.headline.bold())
            .foregroundStyle(.white)
            .frame(width: 72, height: 48)
            .background(Color.sceneDanger, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.25), lineWidth: 1)
            }
            .buttonStyle(SceneCardButtonStyle())

            stepNotePanel
                .frame(maxWidth: .infinity)
        }
    }

    private var inlineEmergencyGuidance: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if emergencyGuidanceSource == .guided {
                    emergencyHeader
                }
                enlargedEmergencyLocation
                emergencyScriptPanel
                emergencyActionButtons
            }
            .padding(.bottom, 4)
        }
    }

    private var emergencyHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "phone.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.sceneDanger, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Send for help now".afLocalized)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)

                    Text("Call 000 or ask someone nearby. Put the phone on speaker.".afLocalized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.sceneMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .liquidGlass(tint: Color.sceneDanger, opacity: 0.18)
    }

    private var enlargedEmergencyLocation: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Location to read out".afLocalized, systemImage: "location.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.sceneWarning)
                .textCase(.uppercase)

            if let location = incidentStore.currentIncident?.location {
                Text(location.address)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(location.coordinateText)
                    .font(.headline.monospacedDigit().weight(.bold))
                    .foregroundStyle(Color.sceneAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)

                Text(AppStrings.text("Nearest street: %@", nearbyStreetText(for: location)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Location is still being captured. Tell 000 your visible address, venue name, nearest street, gate, landmark, or access point.".afLocalized)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .liquidGlass(tint: Color.sceneWarning, opacity: 0.14)
    }

    private var emergencyScriptPanel: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label("Say this first".afLocalized, systemImage: "quote.bubble.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.sceneAccent)
                .textCase(.uppercase)

            EmergencyScriptLine(number: "1", text: "I need an ambulance.".afLocalized)
            EmergencyScriptLine(number: "2", text: emergencyLocationScript)
            EmergencyScriptLine(number: "3", text: emergencyPatientScript)
            EmergencyScriptLine(number: "4", text: "I am following first aid instructions and can stay on the line.".afLocalized)

            Divider()
                .overlay(Color.white.opacity(0.12))

            VStack(alignment: .leading, spacing: 7) {
                emergencyBullet("Whether the patient is awake and breathing normally.".afLocalized)
                emergencyBullet("Any major bleeding, chest pain, seizure, allergy, or other urgent concern.".afLocalized)
                emergencyBullet("How many patients there are and any scene dangers.".afLocalized)
            }
        }
        .padding(14)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
    }

    private var emergencyActionButtons: some View {
        VStack(spacing: 10) {
            Button {
                openEmergencyDialer()
            } label: {
                Label("Call 000".afLocalized, systemImage: "phone.fill")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ScenePrimaryButtonStyle())

            Button {
                confirmEmergencyCalled()
            } label: {
                Label("Already called".afLocalized, systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SceneSecondaryButtonStyle())
        }
    }

    private var emergencyLocationScript: String {
        if let location = incidentStore.currentIncident?.location {
            return AppStrings.text("My location is %@. The coordinates are %@.", location.address, location.coordinateText)
        }
        return "I will describe my location clearly: address, venue, nearest street, landmark, and access point.".afLocalized
    }

    private var emergencyPatientScript: String {
        let name = emergencyPatientName
        if name.isEmpty {
            return "The patient needs urgent first aid. I will tell you their condition now.".afLocalized
        }
        return AppStrings.text("The patient's name is %@. They need urgent first aid.", name)
    }

    private var emergencyPatientName: String {
        guard let profile = incidentStore.currentIncident?.patientProfile else { return "" }
        let name = [profile.firstName, profile.surname]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines) : name
    }

    private func emergencyBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.sceneAccent)
                .padding(.top, 2)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var locationStatusPanel: some View {
        Button {
            presentLocationMap()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text("Location".afLocalized)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.sceneAccent)
                    .textCase(.uppercase)

                if let location = incidentStore.currentIncident?.location {
                    Text(AppStrings.text("Address: %@", location.address))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text(AppStrings.text("Coordinates: %@", location.coordinateText))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Color.sceneAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(AppStrings.text("Nearest street: %@", nearbyStreetText(for: location)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.sceneMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                } else {
                    Text(locationManager.statusText)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Tap to capture current coordinates and address.".afLocalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.sceneMuted)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .padding(12)
            .liquidGlass(tint: Color.sceneAccent, opacity: 0.12)
        }
        .buttonStyle(SceneCardButtonStyle())
    }

    private var completedPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Checklist complete".afLocalized)
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("Keep monitoring, update the timeline, and prepare handover.".afLocalized)
                .font(.body)
                .foregroundStyle(Color.sceneMuted)

            Button {
                showingHandover = true
            } label: {
                Label("Prepare Handover".afLocalized, systemImage: "doc.text.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ScenePrimaryButtonStyle())

            Button {
                historyInitialSection = .timeline
                showingTimeline = true
            } label: {
                Label("Open Timeline".afLocalized, systemImage: "list.bullet.clipboard.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SceneSecondaryButtonStyle())
        }
        .padding(20)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.14)
    }

    private var monitoringActionGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonitoringQuickButton(title: "Condition changed - recheck DRSABCD", icon: "arrow.clockwise.circle.fill", tint: .sceneWarning, height: 74) {
                recordConditionChangedAndRestartDRSABCD()
            }

            HStack(spacing: 10) {
                MonitoringQuickButton(title: "Handover", icon: "doc.text.fill", tint: .sceneAccent, height: 82) {
                    incidentStore.record(title: "Handover preparation started", category: .observation)
                    showingHandover = true
                }

                MonitoringQuickButton(title: "Timeline", icon: "list.bullet.clipboard.fill", tint: .sceneAccent, height: 82) {
                    historyInitialSection = .timeline
                    showingTimeline = true
                }
            }
        }
        .padding(12)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.09)
    }

    private func answer(_ eventTitle: String, category: TimelineCategory, action: ArrivalAction?) {
        if currentStep?.id == "scene-safe", eventTitle == currentStep?.noEvent {
            recordAnswer(eventTitle, category: category, action: action)
            showingUnsafeSceneAlert = true
            return
        }

        recordAnswer(eventTitle, category: category, action: action)
        handleActionAfterAnswer(action)
    }

    private func goBackOneStep() {
        guard stepIndex > 0 else { return }
        stepNote = ""
        animateStepChange {
            stepIndex -= 1
        }
        incidentStore.updateArrivalStepIndex(stepIndex)
        syncEmergencyGuidanceWithCurrentStep()
    }

    private func advanceToNextStep() {
        animateStepChange {
            stepIndex = min(stepIndex + 1, ArrivalFlow.steps.count)
        }
        incidentStore.updateArrivalStepIndex(stepIndex)
        syncEmergencyGuidanceWithCurrentStep()
    }

    private func recordAnswer(_ eventTitle: String, category: TimelineCategory, action: ArrivalAction?) {
        let note = stepNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let action = actionText(for: action)
        let detail: String?

        if note.isEmpty {
            detail = action
        } else if let action, !action.isEmpty {
            detail = "\(action)\nNote: \(note)"
        } else {
            detail = "Note: \(note)"
        }

        incidentStore.record(title: eventTitle, detail: detail, category: category)
        stepNote = ""
    }

    private func actionText(for action: ArrivalAction?) -> String? {
        switch action {
        case .callEmergency:
            return "Escalate immediately and call 000 if not already done.".afLocalized
        case .sendForHelp:
            return "Send for help before continuing assessment.".afLocalized
        case .startCPR:
            return "Start CPR and request AED if trained and safe.".afLocalized
        case .recoveryPosition:
            return "Place in recovery position if appropriate and monitor breathing.".afLocalized
        case .getAED:
            return "Attach AED when available and follow prompts.".afLocalized
        case .checkAirway:
            return "Continue assessment with airway and breathing checks.".afLocalized
        case .checkBreathing:
            return "Open airway and check breathing again.".afLocalized
        case .monitor:
            return "Condition changed. Recheck DRSABCD from scene safety.".afLocalized
        case .openCPRCounter:
            return "Use the CPR counter to keep compression rhythm.".afLocalized
        case .prepareHandover:
            return "Prepare a concise handover report.".afLocalized
        case .openTimeline:
            return "Open the timeline and record changes.".afLocalized
        case .continueFlow, .none:
            return nil
        }
    }

    private func handleActionAfterAnswer(_ action: ArrivalAction?) {
        switch action {
        case .callEmergency:
            showEmergencyGuidance(source: .guided)
        case .sendForHelp:
            incidentStore.record(title: "000 call prompted", category: .escalation)
            jumpToStep(id: "send-help")
        case .startCPR:
            jumpToStep(id: "cpr")
        case .openCPRCounter:
            showingCPRCounter = true
        case .prepareHandover:
            showingHandover = true
        case .openTimeline:
            historyInitialSection = .timeline
            showingTimeline = true
        case .recoveryPosition:
            jumpToMonitoring()
        case .checkAirway:
            jumpToStep(id: "airway")
        case .checkBreathing:
            jumpToStep(id: "breathing")
        case .monitor:
            lastMonitoringCheck = Date()
            jumpToStep(id: "scene-safe")
        default:
            advanceToNextStep()
        }
    }

    private func showEmergencyGuidance(title: String = "000 call prompted", source: EmergencyGuidanceSource = .guided) {
        incidentStore.record(title: title, category: .escalation)
        setEmergencyGuidanceMode(true, source: source)
    }

    private func showManualEmergencyGuidance() {
        showEmergencyGuidance(source: .manual)
    }

    private func openEmergencyDialer() {
        incidentStore.record(title: "000 call opened", category: .escalation)
        if let url = URL(string: "tel://000") {
            openURL(url)
        }
    }

    private func confirmEmergencyCalled() {
        let shouldContinueAssessment = emergencyGuidanceSource == .guided && currentStep?.id == "send-help"
        incidentStore.record(title: "000 call confirmed", category: .escalation)
        setEmergencyGuidanceMode(false)
        if shouldContinueAssessment {
            jumpToStep(id: "airway")
        }
    }

    private func jumpToMonitoring() {
        jumpToStep(id: "monitoring")
    }

    private func jumpToStep(id: String) {
        guard let targetIndex = ArrivalFlow.steps.firstIndex(where: { $0.id == id }) else { return }
        animateStepChange {
            stepIndex = targetIndex
        }
        incidentStore.updateArrivalStepIndex(stepIndex)
        syncEmergencyGuidanceWithCurrentStep()
    }

    private func syncEmergencyGuidanceWithCurrentStep() {
        setEmergencyGuidanceMode(currentStep?.id == "send-help", source: .guided)
    }

    private func setEmergencyGuidanceMode(_ enabled: Bool, source: EmergencyGuidanceSource? = nil) {
        if let source {
            emergencyGuidanceSource = source
        }
        guard emergencyGuidanceMode != enabled else { return }
        animateEmergencyGuidanceChange {
            emergencyGuidanceMode = enabled
        }
    }

    private func animateStepChange(_ updates: @escaping () -> Void) {
        if reduceMotion {
            updates()
        } else {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.88), updates)
        }
    }

    private func animateEmergencyGuidanceChange(_ updates: @escaping () -> Void) {
        if reduceMotion {
            updates()
        } else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86), updates)
        }
    }

    private func recordConditionChangedAndRestartDRSABCD() {
        lastMonitoringCheck = Date()
        incidentStore.record(
            title: "Condition changed",
            detail: "Condition changed during monitoring. Recheck DRSABCD from scene safety.",
            category: .observation
        )
        jumpToStep(id: "scene-safe")
    }

    private func presentLocationMap() {
        guard let location = incidentStore.currentIncident?.location else {
            didRecordLocation = false
            locationManager.requestLocation()
            return
        }

        incidentStore.record(
            title: "Location map opened",
            detail: "\(location.coordinateText)\n\(location.address)",
            category: .observation
        )
        showingLocationMap = true
    }

    private func updateLiveActivity() {
        guard let incident = incidentStore.currentIncident else { return }
        LiveActivityManager.shared.startOrUpdate(for: incident)
    }

    private func prepareIncidentIfNeeded() {
        guard incidentStore.hasLoadedDatabase else { return }

        if incidentStore.currentIncident == nil {
            incidentStore.startIncident()
            didRecordLocation = false
            locationManager.requestLocation()
        }

        let storedStepIndex = incidentStore.currentIncident?.arrivalStepIndex ?? 0
        stepIndex = boundedStepIndex(storedStepIndex)
        if stepIndex != storedStepIndex {
            incidentStore.updateArrivalStepIndex(stepIndex)
        }
        syncEmergencyGuidanceWithCurrentStep()
        updateLiveActivity()
    }

    private func boundedStepIndex(_ index: Int) -> Int {
        min(max(index, 0), ArrivalFlow.steps.count)
    }
}

private struct EmergencyScriptLine: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(.black)
                .frame(width: 24, height: 24)
                .background(Color.sceneAccent, in: Circle())

            Text(text)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ArrivalStepHelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    let step: ArrivalStep

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    helpHeader

                    VStack(spacing: 10) {
                        ForEach(step.helpItems) { item in
                            ArrivalHelpItemCard(item: item)
                        }
                    }

                    if let warning = step.warningText, !warning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ArrivalWarningCard(text: warning)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
        }
    }

    private var helpHeader: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 6) {
                Text(AppStrings.display(step.helpTitle))
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(AppStrings.display(step.helpSubtitle))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.sceneMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(SceneCardButtonStyle())
            .foregroundStyle(.white)
            .accessibilityLabel("Close".afLocalized)
        }
    }
}

private struct ArrivalHelpItemCard: View {
    let item: ArrivalHelpItem

    var body: some View {
        HStack(spacing: 14) {
            ResponseCheckIllustration(systemImage: item.icon, tint: .sceneAccent)

            VStack(alignment: .leading, spacing: 5) {
                Text(AppStrings.display(item.title))
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Text(AppStrings.display(item.detail))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.sceneMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.12)
    }
}

private struct ArrivalWarningCard: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(Color.sceneDanger)
                .frame(width: 34, height: 34)

            Text(AppStrings.display(text))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .liquidGlass(tint: Color.sceneDanger, opacity: 0.13)
    }
}

private struct QuickCareSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let cards: [QuickCareCard] = [
        QuickCareCard(
            title: "Severe bleeding",
            icon: "drop.fill",
            tint: .sceneDanger,
            steps: ["Apply firm direct pressure.", "Add dressing or bandage.", "Call 000 if severe or not controlled."]
        ),
        QuickCareCard(
            title: "Anaphylaxis",
            icon: "allergens.fill",
            tint: .sceneWarning,
            steps: ["Help use adrenaline autoinjector if available.", "Call 000.", "Lay flat or sit if breathing is difficult."]
        ),
        QuickCareCard(
            title: "Asthma",
            icon: "lungs.fill",
            tint: .sceneAccent,
            steps: ["Sit upright.", "Help use reliever inhaler/spacer if available.", "Call 000 for severe symptoms or no improvement."]
        ),
        QuickCareCard(
            title: "Seizure",
            icon: "waveform.path.ecg",
            tint: .sceneSafe,
            steps: ["Protect from injury.", "Do not restrain.", "After seizure, check breathing and recovery position."]
        ),
        QuickCareCard(
            title: "Burns",
            icon: "flame.fill",
            tint: .sceneWarning,
            steps: ["Cool with running water.", "Remove jewellery or tight items if safe.", "Cover loosely."]
        ),
        QuickCareCard(
            title: "Heat illness",
            icon: "thermometer.sun.fill",
            tint: .sceneDanger,
            steps: ["Move to a cool place.", "Cool actively.", "Call 000 if collapsed or confused."]
        )
    ]

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ZStack(alignment: .topTrailing) {
                        VStack(spacing: 6) {
                            Text("Quick care".afLocalized)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)

                            Text("Fast reminders for common first aid problems.".afLocalized)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.sceneMuted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.headline.weight(.bold))
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(SceneCardButtonStyle())
                        .foregroundStyle(.white)
                        .accessibilityLabel("Close".afLocalized)
                    }

                    ForEach(cards) { card in
                        QuickCareCardView(card: card)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct QuickCareCard: Identifiable {
    let title: String
    let icon: String
    let tint: Color
    let steps: [String]

    var id: String { title }
}

private struct QuickCareCardView: View {
    let card: QuickCareCard

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ResponseCheckIllustration(systemImage: card.icon, tint: card.tint)

            VStack(alignment: .leading, spacing: 8) {
                Text(AppStrings.display(card.title))
                    .font(.headline.bold())
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(card.steps, id: \.self) { step in
                        HStack(alignment: .top, spacing: 7) {
                            Circle()
                                .fill(card.tint)
                                .frame(width: 5, height: 5)
                                .padding(.top, 7)

                            Text(AppStrings.display(step))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.sceneMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .liquidGlass(tint: card.tint, opacity: 0.11)
    }
}

private struct ResponseCheckIllustration: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(tint.opacity(0.18))
            .frame(width: 62, height: 62)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(.white)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: tint.opacity(0.14), radius: 12, x: 0, y: 6)
    }
}

private struct IncidentMapView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var region: MKCoordinateRegion
    let location: IncidentLocation

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }

    init(location: IncidentLocation) {
        self.location = location
        let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        _region = State(
            initialValue: MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
            )
        )
    }

    var body: some View {
        NavigationStack {
            mapContent
            .safeAreaInset(edge: .bottom) {
                locationSummary
            }
            .navigationTitle("Location".afLocalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done".afLocalized) {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var mapContent: some View {
        if #available(iOS 17.0, *) {
            Map(initialPosition: .region(region)) {
                Marker("Location".afLocalized, systemImage: "location.fill", coordinate: coordinate)
                    .tint(Color.sceneDanger)
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
        } else {
            Map(
                coordinateRegion: $region,
                annotationItems: [IncidentMapAnnotation(coordinate: coordinate)]
            ) { annotation in
                MapMarker(coordinate: annotation.coordinate, tint: Color.sceneDanger)
            }
        }
    }

    private var locationSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppStrings.text("Address: %@", location.address))
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(3)

            Text(AppStrings.text("Coordinates: %@", location.coordinateText))
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)

            Text(AppStrings.text("Nearby street: %@", nearbyStreetText(for: location)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial)
    }
}

private struct IncidentMapAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        id = "\(coordinate.latitude),\(coordinate.longitude)"
    }
}

private func nearbyStreetText(for location: IncidentLocation) -> String {
    let nearbyStreet = location.nearbyStreet?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return nearbyStreet.isEmpty ? "Not available".afLocalized : nearbyStreet
}

private struct MonitoringQuickButton: View {
    let title: String
    let icon: String
    let tint: Color
    var height: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(AppStrings.display(title))
                    .font(labelFont)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            } icon: {
                Image(systemName: icon)
                    .font(iconFont)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .padding(.horizontal, 8)
            .liquidGlass(tint: tint, opacity: 0.13)
        }
        .buttonStyle(.plain)
    }

    private var labelFont: Font {
        if height >= 70 {
            return .headline.weight(.bold)
        }
        if height >= 54 {
            return .subheadline.weight(.bold)
        }
        return .caption.weight(.bold)
    }

    private var iconFont: Font {
        height >= 70 ? .title3.weight(.bold) : .caption.weight(.bold)
    }
}

private struct SceneResponseButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    color.opacity(0.98),
                                    color.opacity(0.72)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.42), lineWidth: 1)
                }
                .shadow(color: color.opacity(0.18), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(SceneCardButtonStyle())
    }
}
