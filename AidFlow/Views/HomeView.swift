import AVFoundation
import MediaPlayer
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var incidentStore: IncidentStore
    @AppStorage("userProfile.name") private var userName = ""
    @AppStorage("developerModeEnabled") private var developerModeEnabled = false
    @State private var showingActiveIncidentNotice = false
    @State private var didRevealContent = false

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(greetingText),")
                                    .font(.largeTitle.bold())
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.68)

                                if !firstName.isEmpty {
                                    Text(firstName)
                                        .font(.largeTitle.bold())
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.78)
                                }
                            }

                            Text("AidFlow scene guidance, timeline recording, and handover support.".afLocalized)
                                .font(.body)
                                .foregroundStyle(Color.sceneMuted)
                        }

                        Spacer()

                        NavigationLink {
                            ProfileView()
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                Text("Profile".afLocalized)
                                    .font(.subheadline.weight(.bold))
                            }
                            .foregroundStyle(Color.sceneAccent)
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                            .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
                        }
                        .accessibilityLabel("Profile".afLocalized)
                        .buttonStyle(SceneCardButtonStyle())
                    }
                    .sceneEntrance(isVisible: didRevealContent, index: 0)

                    arrivalEntry
                        .sceneEntrance(isVisible: didRevealContent, index: 1)

                    NavigationLink {
                        PatientRecordFormView()
                    } label: {
                        SecondaryActionCard(
                            title: "Patient Record Form".afLocalized,
                            subtitle: "Save patient information without starting Arrival Mode".afLocalized,
                            systemImage: "doc.text.fill"
                        )
                    }
                    .buttonStyle(SceneCardButtonStyle())
                    .sceneEntrance(isVisible: didRevealContent, index: 2)

                    NavigationLink {
                        TrainingView()
                    } label: {
                        SecondaryActionCard(
                            title: "Training Mode".afLocalized,
                            subtitle: "Guided scenario practice is being prepared.".afLocalized,
                            systemImage: "person.wave.2.fill"
                        )
                    }
                    .buttonStyle(SceneCardButtonStyle())
                    .sceneEntrance(isVisible: didRevealContent, index: 3)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tools".afLocalized)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.sceneAccent)
                            .textCase(.uppercase)

                        NavigationLink {
                            CPRCounterView(onCPRStateChange: { state in
                                LiveActivityManager.shared.updateStandaloneCPRState(state)
                            })
                        } label: {
                            SecondaryActionCard(
                                title: "CPR Counter".afLocalized,
                                subtitle: "110/min rhythm with 30 compressions and 2 breaths prompt".afLocalized,
                                systemImage: "waveform.path.ecg"
                            )
                        }
                        .buttonStyle(SceneCardButtonStyle())

                        NavigationLink {
                            GCSCalculatorView()
                        } label: {
                            SecondaryActionCard(
                                title: "GCS Calculator".afLocalized,
                                subtitle: "Eye, verbal, and motor response score".afLocalized,
                                systemImage: "brain.head.profile"
                            )
                        }
                        .buttonStyle(SceneCardButtonStyle())

                        if developerModeEnabled {
                            NavigationLink {
                                PupilReactionCheckView()
                            } label: {
                                SecondaryActionCard(
                                    title: "Pupil Reaction Check".afLocalized,
                                    subtitle: "Developer experimental observation tool".afLocalized,
                                    systemImage: "eye.fill"
                                )
                            }
                            .buttonStyle(SceneCardButtonStyle())
                        }
                    }
                    .sceneEntrance(isVisible: didRevealContent, index: 4)
                }
                .padding(24)
            }
        }
        .developerScreenID("110001", "HomeView")
        .toolbar(.hidden, for: .navigationBar)
        .alert("Active incident in progress".afLocalized, isPresented: $showingActiveIncidentNotice) {
            Button("OK".afLocalized, role: .cancel) {}
        } message: {
            Text("Use the ongoing activity below to continue the current incident, or close the case before starting a new one.".afLocalized)
        }
        .onAppear {
            didRevealContent = true
        }
    }

    private var arrivalEntry: some View {
        VStack(spacing: 10) {
            if incidentStore.currentIncident == nil {
                NavigationLink {
                    ArrivalModeView()
                } label: {
                    PrimaryActionCard(
                        title: "Start Arrival Mode".afLocalized,
                        subtitle: "Begin DRSABCD-style scene guidance".afLocalized,
                        systemImage: "cross.case.fill"
                    )
                }
                .simultaneousGesture(TapGesture().onEnded {
                    if incidentStore.hasLoadedDatabase, incidentStore.currentIncident == nil {
                        incidentStore.startIncident()
                    }
                })
                .buttonStyle(SceneCardButtonStyle())
            } else {
                Button {
                    showingActiveIncidentNotice = true
                } label: {
                    PrimaryActionCard(
                        title: "Start Arrival Mode".afLocalized,
                        subtitle: "An incident is already active. Continue it below.".afLocalized,
                        systemImage: "cross.case.fill"
                    )
                }
                .buttonStyle(SceneCardButtonStyle())
            }

            if let incident = incidentStore.currentIncident {
                Rectangle()
                    .fill(Color.white.opacity(0.16))
                    .frame(height: 1)
                    .padding(.horizontal, 12)

                NavigationLink {
                    ArrivalModeView()
                } label: {
                    ActiveIncidentRow(incident: incident)
                }
                .buttonStyle(SceneCardButtonStyle())
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good Morning".afLocalized
        } else if hour < 18 {
            return "Good Afternoon".afLocalized
        } else {
            return "Good Evening".afLocalized
        }
    }

    private var firstName: String {
        userName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .first
            .map(String.init) ?? ""
    }
}

private struct ActiveIncidentRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let incident: Incident
    @State private var isPulseExpanded = false

    private var currentStepTitle: String {
        guard ArrivalFlow.steps.indices.contains(incident.arrivalStepIndex) else {
            return "Monitoring".afLocalized
        }
        return AppStrings.display(ArrivalFlow.steps[incident.arrivalStepIndex].title)
    }

    private var locationText: String {
        guard let location = incident.location else {
            return "Location not recorded".afLocalized
        }
        let address = location.address.trimmingCharacters(in: .whitespacesAndNewlines)
        return address.isEmpty ? location.coordinateText : address
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.sceneDanger.opacity(isPulseExpanded ? 0.08 : 0.22))
                    .scaleEffect(isPulseExpanded && !reduceMotion ? 1.18 : 1)
                Circle()
                    .fill(Color.sceneDanger)
                    .frame(width: 10, height: 10)
            }
            .frame(width: 38, height: 38)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 1.35).repeatForever(autoreverses: true),
                value: isPulseExpanded
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Ongoing activity".afLocalized)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(incident.startedAt, style: .timer)
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(Color.sceneAccent)
                        .lineLimit(1)
                }

                Text(AppStrings.text("Current step: %@", currentStepTitle))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)
                    .lineLimit(1)

                Text(locationText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted.opacity(0.86))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.sceneAccent)
        }
        .padding(14)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.09)
        .onAppear {
            isPulseExpanded = true
        }
    }
}

struct CPRCounterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var soundPlayer = CPRSoundPlayer()
    @State private var isRunning = false
    @State private var compressionCount = 0
    @State private var cycleCount = 0
    @State private var isBreathPhase = false
    @State private var breathSecondsRemaining = 5
    @State private var cprStartedAt: Date?
    let onPatientRecovered: (() -> Void)?
    let onCPRStateChange: ((AidFlowLiveActivityAttributes.CPRState?) -> Void)?

    private let compressionTimer = Timer.publish(every: 60.0 / 110.0, on: .main, in: .common).autoconnect()
    private let breathTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(
        onPatientRecovered: (() -> Void)? = nil,
        onCPRStateChange: ((AidFlowLiveActivityAttributes.CPRState?) -> Void)? = nil
    ) {
        self.onPatientRecovered = onPatientRecovered
        self.onCPRStateChange = onCPRStateChange
    }

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            VStack(spacing: 18) {
                header
                counterPanel
                controls
                if onPatientRecovered != nil {
                    recoveredButton
                }
                guidance
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .developerScreenID("120001", "CPRCounterView")
        .navigationTitle("CPR Counter".afLocalized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onReceive(compressionTimer) { _ in
            compressionTick()
        }
        .onReceive(breathTimer) { _ in
            breathTick()
        }
        .onAppear {
            soundPlayer.prepare()
        }
        .onDisappear {
            soundPlayer.stop()
            onCPRStateChange?(nil)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text((isBreathPhase ? "Give 2 breaths" : "Chest compressions").afLocalized)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.74)

            Text((isBreathPhase ? "Resume compressions when the prompt finishes." : "Follow the beep rhythm. Let the chest recoil fully.").afLocalized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var counterPanel: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 20)

                Circle()
                    .trim(from: 0, to: isBreathPhase ? 1 : CGFloat(compressionCount) / 30)
                    .stroke(
                        isBreathPhase ? Color.sceneDanger : Color.sceneAccent,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: compressionCount)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isBreathPhase)

                VStack(spacing: 4) {
                    Text(isBreathPhase ? "\(breathSecondsRemaining)" : "\(compressionCount)")
                        .font(.system(size: 82, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    Text((isBreathPhase ? "seconds" : "of 30").afLocalized)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(isBreathPhase ? Color.sceneDanger : Color.sceneAccent)
                }
            }
            .frame(width: 250, height: 250)

            HStack(spacing: 10) {
                metric(title: "Rate".afLocalized, value: "110/min")
                metric(title: "Cycles".afLocalized, value: "\(cycleCount)")
                metric(title: "Breaths".afLocalized, value: "2")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .liquidGlass(tint: isBreathPhase ? Color.sceneDanger : Color.sceneAccent, opacity: 0.12)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                isRunning.toggle()
                if isRunning {
                    if cprStartedAt == nil {
                        cprStartedAt = Date()
                    }
                    soundPlayer.activateMaximumAudibility()
                    playBeat(strong: true)
                }
                publishCPRState()
            } label: {
                Label((isRunning ? "Pause" : "Start").afLocalized, systemImage: isRunning ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ScenePrimaryButtonStyle())

            Button {
                reset()
            } label: {
                Label("Reset".afLocalized, systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SceneSecondaryButtonStyle())
        }
    }

    private var recoveredButton: some View {
        Button {
            isRunning = false
            soundPlayer.stop()
            onCPRStateChange?(nil)
            if let onPatientRecovered {
                onPatientRecovered()
            } else {
                dismiss()
            }
        } label: {
            Label("Patient awake / breathing".afLocalized, systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SceneSecondaryButtonStyle())
    }

    private var guidance: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Training aid only".afLocalized, systemImage: "exclamationmark.triangle.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.sceneWarning)

            Text("Use this as a rhythm counter during training. In a real emergency, call 000, follow DRSABCD, use an AED when available, and follow local protocols.".afLocalized)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .liquidGlass(tint: Color.sceneWarning, opacity: 0.08)
    }

    private func metric(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.monospacedDigit().weight(.bold))
                .foregroundStyle(.white)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.07)
    }

    private func compressionTick() {
        guard isRunning, !isBreathPhase else { return }
        compressionCount += 1
        playBeat(strong: compressionCount == 1 || compressionCount == 30)

        if compressionCount >= 30 {
            isBreathPhase = true
            breathSecondsRemaining = 5
            playBreathPrompt()
        }
        publishCPRState()
    }

    private func breathTick() {
        guard isRunning, isBreathPhase else { return }
        breathSecondsRemaining -= 1

        if breathSecondsRemaining <= 0 {
            cycleCount += 1
            compressionCount = 0
            breathSecondsRemaining = 5
            isBreathPhase = false
            playBeat(strong: true)
        }
        publishCPRState()
    }

    private func reset() {
        isRunning = false
        compressionCount = 0
        cycleCount = 0
        isBreathPhase = false
        breathSecondsRemaining = 5
        cprStartedAt = nil
        onCPRStateChange?(nil)
    }

    private func playBeat(strong: Bool = false) {
        soundPlayer.playBeat(strong: strong)
        UIImpactFeedbackGenerator(style: strong ? .heavy : .light).impactOccurred()
    }

    private func playBreathPrompt() {
        soundPlayer.playBreathPrompt()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private func publishCPRState() {
        let startedAt = cprStartedAt ?? Date()
        cprStartedAt = startedAt
        onCPRStateChange?(
            AidFlowLiveActivityAttributes.CPRState(
                isRunning: isRunning,
                compressionCount: compressionCount,
                cycleCount: cycleCount,
                isBreathPhase: isBreathPhase,
                breathSecondsRemaining: breathSecondsRemaining,
                startedAt: startedAt,
                updatedAt: Date()
            )
        )
    }
}

private final class CPRSoundPlayer: ObservableObject {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private var pendingBreathPrompt: DispatchWorkItem?
    private var isEngineConfigured = false
    private var isPrepared = false

    func prepare() {
        guard !isPrepared else { return }

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        if !isEngineConfigured {
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            engine.mainMixerNode.outputVolume = 1.0
            player.volume = 1.0
            isEngineConfigured = true
        }

        try? engine.start()
        isPrepared = true
    }

    func activateMaximumAudibility() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        SystemVolumeController.setMaximumVolume()
        #endif
        engine.mainMixerNode.outputVolume = 1.0
        player.volume = 1.0
    }

    func playBeat(strong: Bool) {
        playTone(
            frequency: strong ? 1_050 : 820,
            duration: strong ? 0.105 : 0.075,
            volume: strong ? 0.95 : 0.82
        )
    }

    func playBreathPrompt() {
        pendingBreathPrompt?.cancel()
        playTone(frequency: 620, duration: 0.16, volume: 0.95)

        let workItem = DispatchWorkItem { [weak self] in
            self?.playTone(frequency: 460, duration: 0.18, volume: 0.95)
        }
        pendingBreathPrompt = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    func stop() {
        pendingBreathPrompt?.cancel()
        pendingBreathPrompt = nil
        player.stop()
        engine.stop()
        isPrepared = false
    }

    private func playTone(frequency: Double, duration: Double, volume: Float) {
        prepare()

        if !engine.isRunning {
            try? engine.start()
        }

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }

        buffer.frameLength = frameCount
        guard let channel = buffer.floatChannelData?[0] else { return }

        for frame in 0..<Int(frameCount) {
            let position = Double(frame) / sampleRate
            let envelope = fadeEnvelope(frame: frame, totalFrames: Int(frameCount))
            let phase = 2.0 * Double.pi * frequency * position
            let wave = Float(sin(phase))
            channel[frame] = wave * volume * envelope
        }

        player.scheduleBuffer(buffer, at: nil)
        if !player.isPlaying {
            player.play()
        }
    }

    private func fadeEnvelope(frame: Int, totalFrames: Int) -> Float {
        let fadeFrames = max(1, Int(sampleRate * 0.008))
        if frame < fadeFrames {
            return Float(frame) / Float(fadeFrames)
        }

        let framesFromEnd = totalFrames - frame
        if framesFromEnd < fadeFrames {
            return Float(max(framesFromEnd, 0)) / Float(fadeFrames)
        }

        return 1
    }
}

#if os(iOS)
private enum SystemVolumeController {
    private static let volumeView = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))

    static func setMaximumVolume() {
        DispatchQueue.main.async {
            attachVolumeViewIfNeeded()
            volumeView.layoutIfNeeded()
            guard let slider = volumeView.subviews.compactMap({ $0 as? UISlider }).first else { return }
            slider.setValue(1.0, animated: false)
            slider.sendActions(for: .valueChanged)
            slider.sendActions(for: .touchUpInside)
        }
    }

    private static func attachVolumeViewIfNeeded() {
        guard volumeView.superview == nil else { return }
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        let activeKeyWindow = windowScenes
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        let fallbackKeyWindow = windowScenes
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        let keyWindow = activeKeyWindow ?? fallbackKeyWindow

        keyWindow?.addSubview(volumeView)
    }
}
#endif

struct GCSCalculatorView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: GCSStep = .eye
    @State private var previousStep: GCSStep = .eye
    @State private var eye: GCSOption?
    @State private var verbal: GCSOption?
    @State private var motor: GCSOption?

    private var totalScore: Int {
        (eye?.score ?? 0) + (verbal?.score ?? 0) + (motor?.score ?? 0)
    }

    private var severity: (title: String, color: Color) {
        guard step == .result else {
            return ("In progress".afLocalized, Color.sceneAccent)
        }

        switch totalScore {
        case 13...15:
            return ("Mild / Alert range".afLocalized, Color.sceneSafe)
        case 9...12:
            return ("Moderate impairment".afLocalized, Color.sceneWarning)
        default:
            return ("Severe impairment".afLocalized, Color.sceneDanger)
        }
    }

    private var isMovingForward: Bool {
        step.rawValue >= previousStep.rawValue
    }

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            VStack(alignment: .leading, spacing: 10) {
                header
                progressHeader

                ZStack {
                    currentStepView
                        .id(step)
                        .transition(reduceMotion ? .opacity : stepTransition)
                }
                .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88), value: step)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .developerScreenID("120002", "GCSCalculatorView")
        .navigationTitle("GCS Calculator".afLocalized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Glasgow Coma Scale".afLocalized)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("Answer one response at a time.".afLocalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer()

            Text(severity.title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(severity.color)
                .lineLimit(1)
                .minimumScaleFactor(0.66)
                .padding(.horizontal, 8)
                .frame(height: 26)
                .liquidGlass(tint: severity.color, opacity: 0.10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    goBack()
                } label: {
                    Label("Go Back".afLocalized, systemImage: "chevron.left")
                        .font(.subheadline.weight(.bold))
                }
                .buttonStyle(SceneCardButtonStyle())
                .foregroundStyle(step == .eye ? Color.sceneMuted.opacity(0.45) : Color.sceneAccent)
                .disabled(step == .eye)

                Spacer()

                Text(step.progressTitle)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(Color.sceneMuted)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.sceneAccent, severity.color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * step.progress)
                }
            }
            .frame(height: 8)

            HStack(spacing: 8) {
                miniScore(label: "E", value: eye?.score, targetStep: .eye)
                miniScore(label: "V", value: verbal?.score, targetStep: .verbal)
                miniScore(label: "M", value: motor?.score, targetStep: .motor)
                miniScore(
                    label: "Total".afLocalized,
                    value: isComplete ? totalScore : nil,
                    targetStep: .result,
                    isEnabled: isComplete
                )
            }
        }
        .padding(10)
        .liquidGlass(tint: severity.color, opacity: 0.09)
    }

    private var isComplete: Bool {
        eye != nil && verbal != nil && motor != nil
    }

    private func miniScore(label: String, value: Int?, targetStep: GCSStep, isEnabled: Bool = true) -> some View {
        Button {
            jump(to: targetStep)
        } label: {
            VStack(spacing: 4) {
                Text(value.map(String.init) ?? "-")
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .foregroundStyle(isEnabled ? .white : Color.sceneMuted)
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(step == targetStep ? Color.sceneAccent : Color.sceneMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .liquidGlass(
                tint: step == targetStep ? Color.sceneAccent : Color.sceneAccent.opacity(0.65),
                opacity: step == targetStep ? 0.16 : 0.07
            )
        }
        .buttonStyle(SceneCardButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(AppStrings.text("Jump to %@", label))
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch step {
        case .eye:
            GCSStepQuestionView(
                step: .eye,
                options: GCSOption.eye,
                selection: eye,
                onSelect: { option in
                    eye = option
                    goForward(to: .verbal)
                }
            )
        case .verbal:
            GCSStepQuestionView(
                step: .verbal,
                options: GCSOption.verbal,
                selection: verbal,
                onSelect: { option in
                    verbal = option
                    goForward(to: .motor)
                }
            )
        case .motor:
            GCSStepQuestionView(
                step: .motor,
                options: GCSOption.motor,
                selection: motor,
                onSelect: { option in
                    motor = option
                    goForward(to: .result)
                }
            )
        case .result:
            GCSResultCard(
                totalScore: totalScore,
                eye: eye,
                verbal: verbal,
                motor: motor,
                severity: severity,
                onRestart: restart
            )
        }
    }

    private var stepTransition: AnyTransition {
        let insertionEdge: Edge = isMovingForward ? .trailing : .leading
        let removalEdge: Edge = isMovingForward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }

    private func goForward(to newStep: GCSStep) {
        previousStep = step
        animateStepChange {
            step = newStep
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func goBack() {
        let newStep: GCSStep
        switch step {
        case .eye:
            return
        case .verbal:
            newStep = .eye
        case .motor:
            newStep = .verbal
        case .result:
            newStep = .motor
        }

        previousStep = step
        animateStepChange {
            step = newStep
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func jump(to newStep: GCSStep) {
        guard newStep != step else { return }
        guard newStep != .result || isComplete else { return }

        previousStep = step
        animateStepChange {
            step = newStep
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func restart() {
        eye = nil
        verbal = nil
        motor = nil
        previousStep = step
        animateStepChange {
            step = .eye
        }
    }

    private func animateStepChange(_ updates: @escaping () -> Void) {
        if reduceMotion {
            updates()
        } else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.88), updates)
        }
    }
}

private enum GCSStep: Int, CaseIterable {
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

    var code: String {
        switch self {
        case .eye:
            return "E"
        case .verbal:
            return "V"
        case .motor:
            return "M"
        case .result:
            return "GCS"
        }
    }

    var progressTitle: String {
        switch self {
        case .eye:
            return "Step 1 of 4".afLocalized
        case .verbal:
            return "Step 2 of 4".afLocalized
        case .motor:
            return "Step 3 of 4".afLocalized
        case .result:
            return "Result".afLocalized
        }
    }

    var progress: CGFloat {
        switch self {
        case .eye:
            return 0.25
        case .verbal:
            return 0.50
        case .motor:
            return 0.75
        case .result:
            return 1.0
        }
    }
}

private struct GCSStepQuestionView: View {
    let step: GCSStep
    let options: [GCSOption]
    let selection: GCSOption?
    let onSelect: (GCSOption) -> Void
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(step.code)
                    .font(.headline.monospaced().weight(.bold))
                    .foregroundStyle(.black)
                    .frame(width: 32, height: 30)
                    .background(Color.sceneAccent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)

                    Text(step.prompt)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.sceneMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(options) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("\(option.score)")
                                .font(.headline.monospacedDigit().weight(.bold))
                                .foregroundStyle(selection == option ? .black : .white)
                                .frame(width: 30, height: 30)
                                .background {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(selection == option ? Color.sceneAccent : Color.white.opacity(0.09))
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title.afLocalized)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)

                                Text(option.detail.afLocalized)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.sceneMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.70)
                            }

                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
                        .padding(10)
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .liquidGlass(tint: selection == option ? Color.sceneAccent : Color.sceneAccent.opacity(0.5), opacity: selection == option ? 0.16 : 0.06)
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: selection == option ? "checkmark.circle.fill" : "circle")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(selection == option ? Color.sceneAccent : Color.sceneMuted)
                                .padding(8)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.09)
    }
}

private struct GCSResultCard: View {
    let totalScore: Int
    let eye: GCSOption?
    let verbal: GCSOption?
    let motor: GCSOption?
    let severity: (title: String, color: Color)
    let onRestart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Final GCS".afLocalized)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text(severity.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(severity.color)
                }

                Spacer()

                Text("\(totalScore)")
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            VStack(spacing: 6) {
                resultLine(label: "Eye Opening".afLocalized, code: "E", option: eye)
                resultLine(label: "Verbal Response".afLocalized, code: "V", option: verbal)
                resultLine(label: "Motor Response".afLocalized, code: "M", option: motor)
            }

            Text(AppStrings.text("Record as: GCS %@ = E%@ V%@ M%@", "\(totalScore)", "\(eye?.score ?? 0)", "\(verbal?.score ?? 0)", "\(motor?.score ?? 0)"))
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .liquidGlass(tint: severity.color, opacity: 0.12)

            Button {
                onRestart()
            } label: {
                Label("Start Again".afLocalized, systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SceneSecondaryButtonStyle())
        }
        .padding(12)
        .liquidGlass(tint: severity.color, opacity: 0.13)
    }

    private func resultLine(label: String, code: String, option: GCSOption?) -> some View {
        HStack(spacing: 12) {
            Text("\(code)\(option?.score ?? 0)")
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(.black)
                .frame(width: 42, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.sceneAccent)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Text(option.map { "\($0.title.afLocalized) - \($0.detail.afLocalized)" } ?? "Not recorded".afLocalized)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.07)
    }
}

private struct GCSOption: Identifiable, Hashable {
    let id: String
    let score: Int
    let title: String
    let detail: String

    static let eye = [
        GCSOption(id: "eye-4", score: 4, title: "Spontaneous", detail: "Eyes open without being asked"),
        GCSOption(id: "eye-3", score: 3, title: "To speech", detail: "Opens eyes when spoken to"),
        GCSOption(id: "eye-2", score: 2, title: "To pain", detail: "Opens eyes only to painful stimulus"),
        GCSOption(id: "eye-1", score: 1, title: "No eye opening", detail: "No eye response observed")
    ]

    static let verbal = [
        GCSOption(id: "verbal-5", score: 5, title: "Orientated", detail: "Knows person, place, time, and situation"),
        GCSOption(id: "verbal-4", score: 4, title: "Confused", detail: "Talks but is disorientated"),
        GCSOption(id: "verbal-3", score: 3, title: "Inappropriate words", detail: "Random or unsuitable words"),
        GCSOption(id: "verbal-2", score: 2, title: "Sounds only", detail: "Moans or makes sounds, no words"),
        GCSOption(id: "verbal-1", score: 1, title: "No verbal response", detail: "No voice response observed")
    ]

    static let motor = [
        GCSOption(id: "motor-6", score: 6, title: "Obeys commands", detail: "Performs simple requested movement"),
        GCSOption(id: "motor-5", score: 5, title: "Localises pain", detail: "Moves hand toward painful stimulus"),
        GCSOption(id: "motor-4", score: 4, title: "Withdraws from pain", detail: "Pulls away from painful stimulus"),
        GCSOption(id: "motor-3", score: 3, title: "Abnormal flexion", detail: "Flexes arms abnormally to pain"),
        GCSOption(id: "motor-2", score: 2, title: "Abnormal extension", detail: "Extends arms abnormally to pain"),
        GCSOption(id: "motor-1", score: 1, title: "No motor response", detail: "No movement response observed")
    ]
}

private struct PrimaryActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        ActionCard(title: title, subtitle: subtitle, systemImage: systemImage, prominence: .primary)
    }
}

private struct SecondaryActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        ActionCard(title: title, subtitle: subtitle, systemImage: systemImage, prominence: .secondary)
    }
}

private struct ActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let prominence: ActionCardProminence

    var body: some View {
        HStack(alignment: .center, spacing: prominence.spacing) {
            icon

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(prominence.titleFont)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(subtitle)
                    .font(prominence.subtitleFont)
                    .foregroundStyle(Color.sceneMuted)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(prominence.chevronFont)
                .foregroundStyle(Color.sceneMuted)
                .frame(width: 14, alignment: .center)
        }
        .padding(prominence.padding)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .liquidGlass(tint: Color.sceneAccent, opacity: prominence.glassOpacity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var icon: some View {
        switch prominence {
        case .primary:
            Image(systemName: systemImage)
                .font(.title2.bold())
                .foregroundStyle(.black)
                .frame(width: 48, height: 48)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.sceneAccent, Color.sceneSafe],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.45), lineWidth: 1)
                }
        case .secondary:
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(Color.sceneAccent)
                .frame(width: 38, height: 38)
                .background(Color.sceneAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private enum ActionCardProminence {
    case primary
    case secondary

    var titleFont: Font {
        switch self {
        case .primary:
            return .title3.bold()
        case .secondary:
            return .headline
        }
    }

    var subtitleFont: Font {
        switch self {
        case .primary:
            return .subheadline
        case .secondary:
            return .caption
        }
    }

    var chevronFont: Font {
        switch self {
        case .primary:
            return .subheadline.bold()
        case .secondary:
            return .caption.bold()
        }
    }

    var spacing: CGFloat {
        switch self {
        case .primary:
            return 16
        case .secondary:
            return 14
        }
    }

    var padding: CGFloat {
        switch self {
        case .primary:
            return 18
        case .secondary:
            return 16
        }
    }

    var glassOpacity: Double {
        switch self {
        case .primary:
            return 0.18
        case .secondary:
            return 0.10
        }
    }
}
