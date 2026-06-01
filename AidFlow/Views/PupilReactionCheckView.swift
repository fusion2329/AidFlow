import AVFoundation
import CoreML
import CoreImage
import SwiftUI
import Vision

struct PupilReactionCheckView: View {
    @EnvironmentObject private var incidentStore: IncidentStore
    @AppStorage("developerModeEnabled") private var developerModeEnabled = false
    @StateObject private var camera = PupilCameraController()
    @State private var selectedEye: PupilEyeSide = .left
    @State private var leftResult: PupilEyeResult?
    @State private var rightResult: PupilEyeResult?
    @State private var notes = ""
    @State private var selectedSaveTargetID: UUID?
    @State private var showingSavedConfirmation = false
    @State private var collectMLFrames = false
    @State private var showingMLCollectionWarning = false

    private var saveTargets: [PupilSaveTarget] {
        var targets: [PupilSaveTarget] = []
        if let current = incidentStore.currentIncident {
            targets.append(PupilSaveTarget(id: current.id, title: "Active incident", subtitle: DateFormatter.sceneDateTime.string(from: current.startedAt)))
        }
        targets.append(
            contentsOf: incidentStore.pastIncidents.prefix(12).map { incident in
                PupilSaveTarget(
                    id: incident.id,
                    title: incident.patientProfile.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppStrings.display(incident.kind.rawValue) : incident.patientProfile.fullName,
                    subtitle: DateFormatter.sceneDateTime.string(from: incident.startedAt)
                )
            }
        )
        return targets
    }

    private var completedAssessment: PupilAssessment? {
        guard leftResult != nil || rightResult != nil else { return nil }
        return PupilAssessment(
            recordedAt: Date(),
            captureMode: camera.captureMode,
            leftEye: leftResult,
            rightEye: rightResult,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    @ViewBuilder
    var body: some View {
        if developerModeEnabled {
            toolBody
        } else {
            developerModeRequiredView
        }
    }

    private var toolBody: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                cameraPanel
                controlDeck
            }
        }
        .developerScreenID("120003", "PupilReactionCheckView")
        .navigationTitle("Pupil Reaction Check".afLocalized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Pupil check saved".afLocalized, isPresented: $showingSavedConfirmation) {
            Button("OK".afLocalized, role: .cancel) {}
        } message: {
            Text("The pupil observation was saved to the selected record.".afLocalized)
        }
        .alert("Sensitive image collection".afLocalized, isPresented: $showingMLCollectionWarning) {
            Button("Cancel".afLocalized, role: .cancel) {
                collectMLFrames = false
                camera.collectTrainingFrames = false
            }
            Button("Enable".afLocalized, role: .destructive) {
                collectMLFrames = true
                camera.collectTrainingFrames = true
            }
        } message: {
            Text("This stores local eye ROI images and metadata for model training. Use only with explicit consent and do not export samples casually.".afLocalized)
        }
        .onAppear {
            if selectedSaveTargetID == nil {
                selectedSaveTargetID = saveTargets.first?.id
            }
            if developerModeEnabled {
                camera.requestAccessAndStart()
            }
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: saveTargets.map(\.id)) { ids in
            guard let selectedSaveTargetID, ids.contains(selectedSaveTargetID) else {
                self.selectedSaveTargetID = ids.first
                return
            }
        }
        .onChange(of: selectedEye) { newValue in
            camera.setTargetEye(newValue)
        }
        .onChange(of: collectMLFrames) { isEnabled in
            camera.collectTrainingFrames = isEnabled
        }
        .onChange(of: developerModeEnabled) { isEnabled in
            if isEnabled {
                camera.requestAccessAndStart()
            } else {
                collectMLFrames = false
                camera.collectTrainingFrames = false
                camera.stop()
            }
        }
    }

    private var developerModeRequiredView: some View {
        ZStack {
            LiquidGlassBackground()

            VStack(spacing: 16) {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(Color.sceneAccent)
                    .frame(width: 78, height: 78)
                    .liquidGlass(tint: Color.sceneAccent, opacity: 0.14)

                VStack(spacing: 8) {
                    Text("Developer Mode Required".afLocalized)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Pupil Reaction Check is an experimental developer tool and is hidden from normal users.".afLocalized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.sceneMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Turn on Developer Mode in Settings to access it for research and testing.".afLocalized)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)
                    .multilineTextAlignment(.center)
                    .padding(14)
                    .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
            }
            .padding(24)
        }
        .developerScreenID("120003", "PupilReactionCheckView.Locked")
        .navigationTitle("Pupil Reaction Check".afLocalized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            collectMLFrames = false
            camera.collectTrainingFrames = false
            camera.stop()
        }
    }

    private var cameraPanel: some View {
        ZStack {
            PupilCameraPreview(session: camera.session)
                .opacity(camera.permission == .authorized ? 1 : 0)

            LinearGradient(
                colors: [.black.opacity(0.34), .clear, .black.opacity(0.58)],
                startPoint: .top,
                endPoint: .bottom
            )

            alignmentGuide

            VStack(spacing: 0) {
                hudTopBar
                Spacer()
                captureStateCard
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 430)
        .background(Color.black)
    }

    private var alignmentGuide: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width * 0.68, 250)
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .stroke(camera.guideColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [16, 10]))
                    .frame(width: size, height: size * 0.62)

                RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                    .stroke(Color.white.opacity(0.34), lineWidth: 1)
                    .frame(width: size * 0.56, height: size * 0.32)

                Crosshair()
                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
                    .frame(width: size * 0.82, height: size * 0.50)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }

    private var hudTopBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                hudPill(title: camera.captureMode == .lidarAssistedRearTorch ? "LiDAR assisted" : "Camera only", value: camera.distanceText)
                hudPill(title: "Eye".afLocalized, value: camera.eyeDetectionText)
                hudPill(title: "Sharp".afLocalized, value: camera.sharpnessText)
                hudPill(title: "Steady".afLocalized, value: camera.steadinessText)
            }

            HStack(spacing: 8) {
                hudPill(title: "Light".afLocalized, value: camera.brightnessText)
                hudPill(title: "Glare".afLocalized, value: camera.glareText)
                hudPill(title: "AI".afLocalized, value: camera.analysisModeText)
                hudPill(title: "Quality".afLocalized, value: camera.measurementQualityText)
            }

            if camera.permission != .authorized {
                permissionCard
            }
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(permissionTitle, systemImage: "camera.fill")
                .font(.headline.bold())
                .foregroundStyle(.white)
            Text(permissionDetail)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .liquidGlass(tint: Color.sceneDanger, opacity: 0.14)
    }

    private var permissionTitle: String {
        switch camera.permission {
        case .notDetermined:
            return "Camera permission needed".afLocalized
        case .denied:
            return "Camera access denied".afLocalized
        case .authorized:
            return "Camera ready".afLocalized
        }
    }

    private var permissionDetail: String {
        switch camera.permission {
        case .notDetermined:
            return "AidFlow uses the rear camera and torch to support pupil observation.".afLocalized
        case .denied:
            return "Enable camera access in Settings to use the pupil reaction check.".afLocalized
        case .authorized:
            return ""
        }
    }

    private var captureStateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(AppStrings.text("%@ eye", AppStrings.display(selectedEye.rawValue)))
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text(camera.statusText.afLocalized)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.sceneMuted)
                }
                Spacer()
                Text(camera.confidence.rawValue.afLocalized)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(camera.guideColor)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .liquidGlass(tint: camera.guideColor, opacity: 0.14)
            }

            ProgressView(value: camera.captureProgress)
                .tint(camera.guideColor)
        }
        .padding(14)
        .liquidGlass(tint: camera.guideColor, opacity: 0.13)
    }

    private var controlDeck: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                safetyNotice
                developerMLPanel
                eyeSelector
                captureButton
                resultPreview
                savePanel
            }
            .padding(20)
        }
        .background(LiquidGlassBackground())
    }

    private var safetyNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.sceneWarning)
            Text("Observation aid only. Do not delay urgent care, 000, CPR, AED use, evacuation, or clinical escalation.".afLocalized)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .liquidGlass(tint: Color.sceneWarning, opacity: 0.10)
    }

    private var eyeSelector: some View {
        Picker("Eye".afLocalized, selection: $selectedEye) {
            ForEach(PupilEyeSide.allCases) { side in
                Text(AppStrings.display(side.rawValue)).tag(side)
            }
        }
        .pickerStyle(.segmented)
        .disabled(camera.isCapturing)
    }

    @ViewBuilder
    private var developerMLPanel: some View {
        if developerModeEnabled {
            Toggle(isOn: Binding(
                get: { collectMLFrames },
                set: { isEnabled in
                    if isEnabled {
                        showingMLCollectionWarning = true
                    } else {
                        collectMLFrames = false
                        camera.collectTrainingFrames = false
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Collect ML frames".afLocalized)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.sceneAccent)
                        .textCase(.uppercase)
                    Text("Stores local eye ROI images and metadata for later model training. Disabled by default.".afLocalized)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.sceneMuted)
                }
            }
            .toggleStyle(.switch)
            .tint(Color.sceneAccent)
            .padding(12)
            .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
        }
    }

    private var captureButton: some View {
        Button {
            camera.capture(eye: selectedEye) { result in
                if result.side == .left {
                    leftResult = result
                } else {
                    rightResult = result
                }
            }
        } label: {
            Label(camera.isCapturing ? "Measuring..." : "Capture pupil reaction", systemImage: camera.isCapturing ? "waveform.path.ecg" : "camera.aperture")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(ScenePrimaryButtonStyle())
        .disabled(camera.permission != .authorized || camera.isCapturing || !camera.isCaptureReady)
    }

    private var resultPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Result Preview")
            PupilResultEditor(title: "Left eye", result: binding(for: .left))
            PupilResultEditor(title: "Right eye", result: binding(for: .right))
            PupilNotesField(notes: $notes)
        }
        .historyCard()
    }

    private var savePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Save")

            if saveTargets.isEmpty {
                Text("No active or saved patient record is available. Capture results can be reviewed here but not attached yet.".afLocalized)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .liquidGlass(tint: Color.sceneAccent, opacity: 0.07)
            } else {
                Picker("Record".afLocalized, selection: Binding(
                    get: { selectedSaveTargetID ?? saveTargets.first?.id ?? UUID() },
                    set: { selectedSaveTargetID = $0 }
                )) {
                    ForEach(saveTargets) { target in
                        Text("\(target.title) - \(target.subtitle)").tag(target.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)

                Button {
                    saveAssessment()
                } label: {
                    Label("Save to Vitals".afLocalized, systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SceneSecondaryButtonStyle())
                .disabled(completedAssessment == nil || selectedSaveTargetID == nil)
            }
        }
        .historyCard()
    }

    private func binding(for side: PupilEyeSide) -> Binding<PupilEyeResult?> {
        Binding {
            side == .left ? leftResult : rightResult
        } set: { value in
            if side == .left {
                leftResult = value
            } else {
                rightResult = value
            }
        }
    }

    private func saveAssessment() {
        guard let assessment = completedAssessment, let selectedSaveTargetID else { return }
        incidentStore.addPupilAssessment(assessment, to: selectedSaveTargetID)
        showingSavedConfirmation = true
    }

    private func hudPill(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title.afLocalized)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.sceneMuted)
                .lineLimit(1)
            Text(value.afLocalized)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.09)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.afLocalized)
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.sceneAccent)
            .textCase(.uppercase)
    }
}

private struct PupilSaveTarget: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
}

private struct PupilResultEditor: View {
    let title: String
    @Binding var result: PupilEyeResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.afLocalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)
                Spacer()
                if let result {
                    Text(result.confidence.rawValue.afLocalized)
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(confidenceColor(result.confidence))
                }
            }

            if result == nil {
                Text("Not captured.".afLocalized)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.sceneMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .liquidGlass(tint: Color.sceneAccent, opacity: 0.06)
            } else {
                Picker("Reaction".afLocalized, selection: Binding(
                    get: { result?.reactionStatus ?? .uncertain },
                    set: { newValue in result?.reactionStatus = newValue }
                )) {
                    ForEach(PupilReactionStatus.allCases) { status in
                        Text(AppStrings.display(status.rawValue)).tag(status)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 8) {
                    PupilMetricChip(title: "Constriction", value: percentText(result?.constrictionPercent))
                    PupilMetricChip(title: "Latency", value: latencyText(result?.latencySeconds))
                    PupilMetricChip(title: "Quality", value: percentText(result?.measurementQuality.map { $0 * 100 }))
                }

                HStack(spacing: 8) {
                    PupilMetricChip(title: "Distance", value: distanceText(result?.distanceCentimeters))
                    PupilMetricChip(title: "Mode", value: result?.approximateDiameterMillimeters == nil ? "px" : "mm")
                    PupilMetricChip(title: "AI", value: result?.usedNeuralSegmentation == true ? "On" : "CV")
                }

                if let flags = result?.qualityFlags, !flags.isEmpty {
                    Text(flags.map { AppStrings.display($0) }.joined(separator: " | "))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.sceneWarning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func confidenceColor(_ confidence: PupilConfidence) -> Color {
        switch confidence {
        case .high:
            return Color.sceneSafe
        case .medium:
            return Color.sceneWarning
        case .low:
            return Color.sceneDanger
        }
    }

    private func percentText(_ value: Double?) -> String {
        guard let value else { return "-" }
        return "\(Int(value.rounded()))%"
    }

    private func latencyText(_ value: Double?) -> String {
        guard let value else { return "-" }
        return String(format: "%.2fs", value)
    }

    private func distanceText(_ value: Double?) -> String {
        guard let value else { return "-" }
        return "\(Int(value.rounded())) cm"
    }
}

private struct PupilMetricChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title.afLocalized)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.sceneMuted)
                .lineLimit(1)
            Text(value.afLocalized)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .liquidGlass(tint: Color.sceneAccent, opacity: 0.08)
    }
}

private struct PupilNotesField: View {
    @Binding var notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Notes".afLocalized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.sceneMuted)

            TextEditor(text: $notes)
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
                .frame(minHeight: 70)
                .padding(10)
                .liquidGlass(tint: Color.sceneAccent, opacity: 0.10)
        }
    }
}

private struct Crosshair: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

private struct PupilCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else {
            return AVCaptureVideoPreviewLayer()
        }
        return previewLayer
    }
}

private enum PupilCameraPermission {
    case notDetermined
    case denied
    case authorized
}

private final class PupilCameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published var permission: PupilCameraPermission = .notDetermined
    @Published var isCapturing = false
    @Published var captureProgress = 0.0
    @Published var statusText = "Align one eye inside the guide."
    @Published var confidence: PupilConfidence = .low
    @Published var distanceCentimeters: Double?
    @Published var brightness: Double = 0
    @Published var steadiness: Double = 0
    @Published var eyeDetectionQuality: Double = 0
    @Published var segmentationQuality: Double = 0
    @Published var sharpnessQuality: Double = 0
    @Published var glareRatio: Double = 0
    @Published var occlusionRisk: Double = 0
    @Published var measurementQuality: Double = 0
    @Published var neuralSegmentationActive = false
    var collectTrainingFrames = false

    private let sessionQueue = DispatchQueue(label: "com.aidflow.pupil.session")
    private let videoQueue = DispatchQueue(label: "com.aidflow.pupil.video")
    private let depthQueue = DispatchQueue(label: "com.aidflow.pupil.depth")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let depthOutput = AVCaptureDepthDataOutput()
    private let mlSegmenter = PupilMLSegmenter()
    private let trainingFrameRecorder = PupilTrainingFrameRecorder()
    private var captureDevice: AVCaptureDevice?
    private var lastFrameSignature: Double?
    private var lastFrameTime = Date()
    private var baselineSamples: [PupilFrameSample] = []
    private var reactionSamples: [PupilFrameSample] = []
    private var targetEye: PupilEyeSide = .left
    private var captureEye: PupilEyeSide = .left
    private var frameCounter = 0
    private var cachedEyeROI: DetectedEyeROI?
    private var captureStartedAt: Date?
    private var resultHandler: ((PupilEyeResult) -> Void)?
    private var activeCaptureID: UUID?
    private var captureInProgress = false
    private var lastHUDUpdate = Date.distantPast
    private var latestConfidence: PupilConfidence = .low
    private var latestDistanceCentimeters: Double?
    private var hasDepthOutput = false
    private let acceptableDistanceRange = 22.0...45.0
    private let baselineCaptureDuration = 0.65
    private let torchPulseStart = 0.75
    private let totalCaptureDuration = 2.25
    private let hudUpdateInterval = 1.0 / 15.0

    var captureMode: PupilCaptureMode {
        hasDepthOutput ? .lidarAssistedRearTorch : .rearTorchCameraOnly
    }

    var guideColor: Color {
        if isCapturing { return Color.sceneAccent }
        switch confidence {
        case .high:
            return Color.sceneSafe
        case .medium:
            return Color.sceneWarning
        case .low:
            return Color.sceneDanger
        }
    }

    var distanceText: String {
        guard let distanceCentimeters else {
            return hasDepthOutput ? "Depth pending" : "No LiDAR"
        }
        if !acceptableDistanceRange.contains(distanceCentimeters) {
            return distanceCentimeters < acceptableDistanceRange.lowerBound ? "Too close" : "Too far"
        }
        return "\(Int(distanceCentimeters.rounded())) cm"
    }

    var steadinessText: String {
        if steadiness < 0.08 { return "High" }
        if steadiness < 0.18 { return "Medium" }
        return "Low"
    }

    var brightnessText: String {
        if brightness < 45 { return "Low" }
        if brightness > 215 { return "High" }
        return "Good"
    }

    var glareText: String {
        if glareRatio < 0.025 { return "Low" }
        if glareRatio < 0.075 { return "Watch" }
        return "High"
    }

    var analysisModeText: String {
        if neuralSegmentationActive { return "Neural" }
        return mlSegmenter.isAvailable ? "Neural ready" : "CV"
    }

    var measurementQualityText: String {
        "\(Int((measurementQuality * 100).rounded()))%"
    }

    var eyeDetectionText: String {
        if eyeDetectionQuality >= 0.72 { return "Locked" }
        if eyeDetectionQuality >= 0.38 { return "Searching" }
        return "Guide"
    }

    var sharpnessText: String {
        if sharpnessQuality >= 0.62 { return "Clear" }
        if sharpnessQuality >= 0.38 { return "Soft" }
        return "Blurred"
    }

    var isCaptureReady: Bool {
        confidence != .low
            && sharpnessQuality >= 0.42
            && glareRatio < 0.08
            && occlusionRisk < 0.62
            && measurementQuality >= 0.38
            && distanceIsAcceptable
    }

    private var distanceIsAcceptable: Bool {
        guard hasDepthOutput, let distanceCentimeters else { return true }
        return acceptableDistanceRange.contains(distanceCentimeters)
    }

    private var videoDistanceIsAcceptable: Bool {
        guard hasDepthOutput, let latestDistanceCentimeters else { return true }
        return acceptableDistanceRange.contains(latestDistanceCentimeters)
    }

    func setTargetEye(_ eye: PupilEyeSide) {
        videoQueue.async {
            self.targetEye = eye
        }
    }

    func requestAccessAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permission = .authorized
            start()
        case .notDetermined:
            permission = .notDetermined
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permission = granted ? .authorized : .denied
                    if granted {
                        self?.start()
                    }
                }
            }
        default:
            permission = .denied
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.inputs.isEmpty {
                self.configureSession()
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        videoQueue.async { [weak self] in
            guard let self else { return }
            self.captureInProgress = false
            self.activeCaptureID = nil
            self.captureStartedAt = nil
            self.resultHandler = nil
            self.baselineSamples.removeAll(keepingCapacity: true)
            self.reactionSamples.removeAll(keepingCapacity: true)
        }
        DispatchQueue.main.async {
            self.isCapturing = false
            self.captureProgress = 0
        }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.setTorch(false)
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func capture(eye: PupilEyeSide, completion: @escaping (PupilEyeResult) -> Void) {
        guard !isCapturing, isCaptureReady else {
            DispatchQueue.main.async {
                self.statusText = self.readinessText(for: self.confidence)
            }
            return
        }
        let captureID = UUID()
        let markCaptureStarted = {
            self.isCapturing = true
            self.captureProgress = 0
            self.statusText = "Hold still. Capturing baseline."
        }
        if Thread.isMainThread {
            markCaptureStarted()
        } else {
            DispatchQueue.main.async(execute: markCaptureStarted)
        }

        videoQueue.async { [weak self] in
            guard let self else { return }
            self.baselineSamples.removeAll(keepingCapacity: true)
            self.reactionSamples.removeAll(keepingCapacity: true)
            self.targetEye = eye
            self.captureEye = eye
            self.resultHandler = completion
            self.captureStartedAt = Date()
            self.captureInProgress = true
            self.activeCaptureID = captureID
            self.lastHUDUpdate = .distantPast

            self.videoQueue.asyncAfter(deadline: .now() + self.torchPulseStart) { [weak self] in
                guard let self, self.captureInProgress, self.activeCaptureID == captureID else { return }
                self.setTorch(true)
                DispatchQueue.main.async {
                    self.statusText = "Torch pulse active. Keep eye centered."
                }
            }

            self.videoQueue.asyncAfter(deadline: .now() + self.totalCaptureDuration) { [weak self] in
                guard let self, self.captureInProgress, self.activeCaptureID == captureID else { return }
                self.finishCapture(captureID: captureID)
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        let device = AVCaptureDevice.default(.builtInLiDARDepthCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        captureDevice = device

        guard let device, let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            DispatchQueue.main.async {
                self.statusText = "Rear camera unavailable."
            }
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        configureDevice(device)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        if !device.activeFormat.supportedDepthDataFormats.isEmpty {
            depthOutput.isFilteringEnabled = true
            depthOutput.setDelegate(self, callbackQueue: depthQueue)
            if session.canAddOutput(depthOutput) {
                session.addOutput(depthOutput)
                hasDepthOutput = true
            }
        }

        session.commitConfiguration()
    }

    private func configureDevice(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            if let depthFormat = device.activeFormat.supportedDepthDataFormats.first {
                device.activeDepthDataFormat = depthFormat
            }
        } catch {
        }
    }

    private func setTorch(_ isOn: Bool) {
        guard let captureDevice, captureDevice.hasTorch else { return }
        do {
            try captureDevice.lockForConfiguration()
            defer { captureDevice.unlockForConfiguration() }
            if isOn {
                try captureDevice.setTorchModeOn(level: min(Float(0.35), AVCaptureDevice.maxAvailableTorchLevel))
            } else {
                captureDevice.torchMode = .off
            }
        } catch {
        }
    }

    private func handle(_ sample: PupilFrameSample) {
        let now = Date()
        var progress: Double?
        if let captureStartedAt, captureInProgress {
            let elapsed = now.timeIntervalSince(captureStartedAt)
            progress = min(elapsed / totalCaptureDuration, 1)
            if elapsed < baselineCaptureDuration {
                baselineSamples.append(sample)
            } else if elapsed >= torchPulseStart {
                reactionSamples.append(sample)
            }
        }

        let frameDelta = lastFrameSignature.map { abs(sample.signature - $0) } ?? 0
        lastFrameSignature = sample.signature
        lastFrameTime = now

        let nextConfidence = confidenceFor(
            brightness: sample.brightness,
            steadiness: frameDelta,
            segmentationQuality: sample.segmentationQuality,
            eyeDetectionQuality: sample.eyeDetectionQuality,
            sharpnessQuality: sample.sharpnessQuality,
            centerOffset: sample.centerOffset,
            glareRatio: sample.glareRatio,
            occlusionRisk: sample.occlusionRisk,
            measurementQuality: sample.measurementQuality
        )
        latestConfidence = nextConfidence
        guard now.timeIntervalSince(lastHUDUpdate) >= hudUpdateInterval else { return }
        lastHUDUpdate = now

        DispatchQueue.main.async {
            if let progress {
                self.captureProgress = progress
            }
            self.brightness = sample.brightness
            self.steadiness = frameDelta
            self.segmentationQuality = sample.segmentationQuality
            self.eyeDetectionQuality = sample.eyeDetectionQuality
            self.sharpnessQuality = sample.sharpnessQuality
            self.glareRatio = sample.glareRatio
            self.occlusionRisk = sample.occlusionRisk
            self.measurementQuality = sample.measurementQuality
            self.neuralSegmentationActive = sample.usedNeuralSegmentation
            self.confidence = nextConfidence
            if !self.isCapturing {
                self.statusText = self.readinessText(for: nextConfidence)
            }
        }
    }

    private func finishCapture(captureID: UUID) {
        guard captureInProgress, activeCaptureID == captureID else { return }
        captureInProgress = false
        activeCaptureID = nil
        setTorch(false)
        let result = buildResult()
        let handler = resultHandler
        resultHandler = nil
        captureStartedAt = nil
        baselineSamples.removeAll(keepingCapacity: true)
        reactionSamples.removeAll(keepingCapacity: true)
        DispatchQueue.main.async {
            self.isCapturing = false
            self.captureProgress = 1
            self.statusText = "Review result before saving."
            handler?(result)
        }
    }

    private func buildResult() -> PupilEyeResult {
        let usableBaseline = qualityFilteredSamples(baselineSamples)
        let usableReaction = qualityFilteredSamples(reactionSamples)
        let baseline = robustMedian(rejectDiameterOutliers(usableBaseline.map(\.pupilDiameterPixels)))
        let minimum = lowerPercentile(rejectDiameterOutliers(usableReaction.map(\.pupilDiameterPixels)), percentile: 0.20)
        let constriction = constrictionPercent(baseline: baseline, minimum: minimum)
        let latencySeconds = estimateLatencySeconds(baseline: baseline, reactionSamples: usableReaction)
        let measurementQuality = captureMeasurementQuality(baselineSamples: usableBaseline, reactionSamples: usableReaction)
        let flags = qualityFlags(
            baselineSamples: usableBaseline,
            reactionSamples: usableReaction,
            measurementQuality: measurementQuality,
            latencySeconds: latencySeconds
        )
        let usedNeuralSegmentation = neuralSegmentationWasPrimary(in: usableBaseline + usableReaction)
        let currentConfidence = resultConfidence(
            baseline: baseline,
            minimum: minimum,
            constriction: constriction,
            samples: usableBaseline + usableReaction,
            measurementQuality: measurementQuality,
            qualityFlags: flags
        )
        let status = reactionStatus(constriction: constriction, latencySeconds: latencySeconds, confidence: currentConfidence)
        let approximateMillimeters = approximateMillimeters(pixelDiameter: minimum)

        return PupilEyeResult(
            side: captureEye,
            baselineDiameterPixels: baseline,
            minimumDiameterPixels: minimum,
            approximateDiameterMillimeters: approximateMillimeters,
            constrictionPercent: constriction,
            latencySeconds: latencySeconds,
            measurementQuality: measurementQuality,
            qualityFlags: flags.isEmpty ? nil : flags,
            usedNeuralSegmentation: usedNeuralSegmentation,
            reactionStatus: status,
            confidence: currentConfidence,
            distanceCentimeters: latestDistanceCentimeters,
            depthConfidence: hasDepthOutput ? currentConfidence : nil,
            notes: ""
        )
    }

    private func confidenceFor(
        brightness: Double,
        steadiness: Double,
        segmentationQuality: Double,
        eyeDetectionQuality: Double,
        sharpnessQuality: Double,
        centerOffset: Double,
        glareRatio: Double,
        occlusionRisk: Double,
        measurementQuality: Double
    ) -> PupilConfidence {
        let brightnessOK = brightness > 55 && brightness < 205
        let centered = centerOffset < 0.34
        if brightnessOK,
           steadiness < 0.08,
           segmentationQuality > 0.58,
           eyeDetectionQuality > 0.55,
           sharpnessQuality > 0.62,
           glareRatio < 0.035,
           occlusionRisk < 0.38,
           measurementQuality > 0.66,
           centered,
           videoDistanceIsAcceptable {
            return .high
        }
        if brightness > 40,
           brightness < 225,
           steadiness < 0.20,
           segmentationQuality > 0.32,
           sharpnessQuality > 0.38,
           glareRatio < 0.08,
           occlusionRisk < 0.62,
           measurementQuality > 0.38,
           centerOffset < 0.50,
           videoDistanceIsAcceptable {
            return .medium
        }
        return .low
    }

    private func readinessText(for confidence: PupilConfidence) -> String {
        switch confidence {
        case .high:
            return "Ready. Keep the eye centered."
        case .medium:
            return eyeDetectionQuality < 0.38 ? "Usable. Move closer until the eye locks." : "Usable. Hold steadier if possible."
        case .low:
            if !distanceIsAcceptable {
                return "Move to the target distance before measuring."
            }
            if sharpnessQuality < 0.38 {
                return "Image is blurred. Hold still and wait for focus."
            }
            if glareRatio >= 0.08 {
                return "Glare detected. Change angle and reduce reflections."
            }
            if occlusionRisk >= 0.62 {
                return "Eye is partly covered. Re-center the open pupil."
            }
            if measurementQuality < 0.38 {
                return "Wait for a clearer pupil boundary before measuring."
            }
            if eyeDetectionQuality < 0.20 {
                return "Align the selected eye inside the guide."
            }
            if brightness < 45 || brightness > 215 {
                return "Adjust light before capturing."
            }
            return "Adjust distance, light, or alignment."
        }
    }

    private func resultConfidence(
        baseline: Double?,
        minimum: Double?,
        constriction: Double?,
        samples: [PupilFrameSample],
        measurementQuality: Double?,
        qualityFlags: [String]
    ) -> PupilConfidence {
        guard baseline != nil, minimum != nil, let constriction, constriction >= 0 else { return .low }
        let medianQuality = robustMedian(samples.map(\.segmentationQuality)) ?? 0
        let medianEyeQuality = robustMedian(samples.map(\.eyeDetectionQuality)) ?? 0
        let captureQuality = measurementQuality ?? 0
        if latestConfidence == .high, constriction > 8, medianQuality > 0.55, medianEyeQuality > 0.45, captureQuality > 0.62, qualityFlags.isEmpty {
            return .high
        }
        if latestConfidence != .low, constriction > 3, medianQuality > 0.30, captureQuality > 0.36, !qualityFlags.contains("Too few clear frames") {
            return .medium
        }
        return .low
    }

    private func reactionStatus(constriction: Double?, latencySeconds: Double?, confidence: PupilConfidence) -> PupilReactionStatus {
        guard confidence != .low, let constriction else { return .uncertain }
        if let latencySeconds, latencySeconds > 1.1, constriction >= 8 { return .sluggish }
        if constriction >= 25 { return .brisk }
        if constriction >= 8 { return .sluggish }
        return .notObserved
    }

    private func constrictionPercent(baseline: Double?, minimum: Double?) -> Double? {
        guard let baseline, let minimum, baseline > 1, minimum > 0 else { return nil }
        return max(0, min(100, ((baseline - minimum) / baseline) * 100))
    }

    private func approximateMillimeters(pixelDiameter: Double?) -> Double? {
        guard hasDepthOutput, let pixelDiameter, let latestDistanceCentimeters else { return nil }
        let estimatedMillimetersPerPixel = max(0.006, min(0.03, latestDistanceCentimeters / 1800))
        return pixelDiameter * estimatedMillimetersPerPixel
    }

    private func robustMedian(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }

    private func lowerPercentile(_ values: [Double], percentile: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let bounded = max(0, min(1, percentile))
        let index = min(sorted.count - 1, max(0, Int(Double(sorted.count - 1) * bounded)))
        return sorted[index]
    }

    private func qualityFilteredSamples(_ samples: [PupilFrameSample]) -> [PupilFrameSample] {
        samples.filter {
            $0.segmentationQuality >= 0.28
                && $0.sharpnessQuality >= 0.36
                && $0.glareRatio < 0.10
                && $0.occlusionRisk < 0.72
                && $0.measurementQuality >= 0.30
        }
    }

    private func rejectDiameterOutliers(_ values: [Double]) -> [Double] {
        guard values.count >= 5, let median = robustMedian(values) else { return values }
        let deviations = values.map { abs($0 - median) }
        let medianDeviation = max(1.0, robustMedian(deviations) ?? 1.0)
        return values.filter { abs($0 - median) <= medianDeviation * 3.5 }
    }

    private func estimateLatencySeconds(baseline: Double?, reactionSamples: [PupilFrameSample]) -> Double? {
        guard let baseline, let captureStartedAt, !reactionSamples.isEmpty else { return nil }
        let onsetThreshold = max(1.5, baseline * 0.04)
        let torchDate = captureStartedAt.addingTimeInterval(torchPulseStart)
        let sortedSamples = reactionSamples.sorted { $0.capturedAt < $1.capturedAt }
        guard let onset = sortedSamples.first(where: {
            $0.capturedAt >= torchDate && $0.pupilDiameterPixels <= baseline - onsetThreshold
        }) else {
            return nil
        }
        let latency = onset.capturedAt.timeIntervalSince(torchDate)
        return latency >= 0 ? min(latency, 3.0) : nil
    }

    private func captureMeasurementQuality(baselineSamples: [PupilFrameSample], reactionSamples: [PupilFrameSample]) -> Double? {
        let allSamples = baselineSamples + reactionSamples
        guard !allSamples.isEmpty else { return nil }
        let medianFrameQuality = robustMedian(allSamples.map(\.measurementQuality)) ?? 0
        let sampleBalance = min(1, Double(min(baselineSamples.count, reactionSamples.count)) / 8)
        let motionQuality = max(0, 1 - (robustMedian(allSamples.map(\.centerOffset)) ?? 0) * 1.9)
        return max(0, min(1, medianFrameQuality * 0.62 + sampleBalance * 0.24 + motionQuality * 0.14))
    }

    private func qualityFlags(
        baselineSamples: [PupilFrameSample],
        reactionSamples: [PupilFrameSample],
        measurementQuality: Double?,
        latencySeconds: Double?
    ) -> [String] {
        let allSamples = baselineSamples + reactionSamples
        var flags: [String] = []
        if baselineSamples.count < 5 || reactionSamples.count < 8 {
            flags.append("Too few clear frames")
        }
        if (robustMedian(allSamples.map(\.sharpnessQuality)) ?? 0) < 0.42 {
            flags.append("Soft focus")
        }
        if (robustMedian(allSamples.map(\.glareRatio)) ?? 0) >= 0.045 {
            flags.append("Glare")
        }
        if (robustMedian(allSamples.map(\.eyeDetectionQuality)) ?? 0) < 0.38 {
            flags.append("Eye ROI uncertain")
        }
        if (robustMedian(allSamples.map(\.occlusionRisk)) ?? 0) >= 0.55 {
            flags.append("Possible eyelid or glasses obstruction")
        }
        if hasDepthOutput, !videoDistanceIsAcceptable {
            flags.append("Distance outside guide range")
        }
        if measurementQuality == nil || (measurementQuality ?? 0) < 0.36 {
            flags.append("Low measurement quality")
        }
        if latencySeconds == nil {
            flags.append("Onset not observed")
        }
        return Array(Set(flags)).sorted()
    }

    private func neuralSegmentationWasPrimary(in samples: [PupilFrameSample]) -> Bool? {
        guard !samples.isEmpty else { return nil }
        let neuralCount = samples.filter(\.usedNeuralSegmentation).count
        return Double(neuralCount) / Double(samples.count) >= 0.5
    }

    private func trainingContext(for sample: PupilFrameSample) -> PupilTrainingFrameContext {
        let elapsed = captureStartedAt.map { sample.capturedAt.timeIntervalSince($0) }
        let phase: PupilTrainingCapturePhase
        if captureInProgress, let elapsed {
            if elapsed < baselineCaptureDuration {
                phase = .baseline
            } else if elapsed < torchPulseStart {
                phase = .torchTransition
            } else {
                phase = .reaction
            }
        } else {
            phase = .livePreview
        }

        let acceptedForTraining = sample.segmentationQuality >= 0.28
            && sample.sharpnessQuality >= 0.36
            && sample.glareRatio < 0.10
            && sample.occlusionRisk < 0.72
            && sample.measurementQuality >= 0.30

        return PupilTrainingFrameContext(
            schemaVersion: 2,
            captureID: activeCaptureID?.uuidString,
            captureMode: captureMode.rawValue,
            phase: phase,
            elapsedSeconds: elapsed,
            torchIsOn: phase == .reaction,
            acceptedForTraining: acceptedForTraining,
            neuralModelAvailable: mlSegmenter.isAvailable
        )
    }
}

extension PupilCameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameCounter += 1
        let shouldRunVision = cachedEyeROI == nil || frameCounter.isMultiple(of: 6)
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let sample = PupilFrameAnalyzer.sample(
                from: pixelBuffer,
                targetEye: targetEye,
                cachedROI: cachedEyeROI,
                shouldRunVision: shouldRunVision,
                mlSegmenter: mlSegmenter,
                orientation: .right
              )
        else { return }
        if let detectedEyeROI = sample.detectedEyeROI {
            cachedEyeROI = detectedEyeROI
        }
        if collectTrainingFrames, frameCounter.isMultiple(of: 10) {
            trainingFrameRecorder.save(
                pixelBuffer: pixelBuffer,
                sample: sample,
                eye: targetEye,
                distanceCentimeters: latestDistanceCentimeters,
                context: trainingContext(for: sample)
            )
        }
        handle(sample)
    }
}

extension PupilCameraController: AVCaptureDepthDataOutputDelegate {
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        let converted = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let depthMap = converted.depthDataMap
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap)?.assumingMemoryBound(to: Float32.self), width > 0, height > 0 else { return }

        let centerX = width / 2
        let centerY = height / 2
        let radius = max(2, min(width, height) / 12)
        var values: [Double] = []

        for y in max(0, centerY - radius)..<min(height, centerY + radius) {
            for x in max(0, centerX - radius)..<min(width, centerX + radius) {
                let value = Double(baseAddress[y * width + x])
                if value.isFinite, value > 0.05, value < 1.2 {
                    values.append(value * 100)
                }
            }
        }

        guard !values.isEmpty else { return }
        let sorted = values.sorted()
        let distance = sorted[sorted.count / 2]
        videoQueue.async { [weak self] in
            self?.latestDistanceCentimeters = distance
        }
        DispatchQueue.main.async {
            self.distanceCentimeters = distance
        }
    }
}

private struct PupilFrameSample {
    let capturedAt: Date
    let brightness: Double
    let pupilDiameterPixels: Double
    let signature: Double
    let segmentationQuality: Double
    let eyeDetectionQuality: Double
    let sharpnessQuality: Double
    let centerOffset: Double
    let glareRatio: Double
    let occlusionRisk: Double
    let measurementQuality: Double
    let usedNeuralSegmentation: Bool
    let roi: CGRect
    let detectedEyeROI: DetectedEyeROI?
}

private enum PupilFrameAnalyzer {
    static func sample(
        from pixelBuffer: CVPixelBuffer,
        targetEye: PupilEyeSide,
        cachedROI: DetectedEyeROI?,
        shouldRunVision: Bool,
        mlSegmenter: PupilMLSegmenter,
        orientation: CGImagePropertyOrientation
    ) -> PupilFrameSample? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard width > 0, height > 0 else { return nil }

        let detectedROI = shouldRunVision ? detectEyeROI(in: pixelBuffer, targetEye: targetEye, width: width, height: height) : nil
        let activeROI = detectedROI ?? cachedROI
        let roi = activeROI?.rect ?? fallbackROI(width: width, height: height)
        let mlCandidate = mlSegmenter.pupilCandidate(in: pixelBuffer, roi: roi, orientation: orientation)

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer), width > 0, height > 0 else { return nil }

        let startX = max(0, Int(roi.minX))
        let startY = max(0, Int(roi.minY))
        let endX = min(width, Int(roi.maxX))
        let endY = min(height, Int(roi.maxY))

        let sampledColumnCount = max(1, (max(0, endX - startX) + 3) / 4)
        let sampledRowCount = max(1, (max(0, endY - startY) + 3) / 4)
        var samples: [SampledPixel] = []
        samples.reserveCapacity(sampledColumnCount * sampledRowCount)
        var total = 0.0
        var count = 0
        var signature = 0.0
        var focusEnergy = 0.0
        var focusComparisons = 0
        var glareCount = 0
        var luminanceValues: [Double] = []
        luminanceValues.reserveCapacity(sampledColumnCount * sampledRowCount)
        var previousRowLuminances = Array<Double?>(repeating: nil, count: sampledColumnCount)

        for y in stride(from: startY, to: endY, by: 4) {
            let row = baseAddress.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            var previousLuminance: Double?
            var columnIndex = 0
            for x in stride(from: startX, to: endX, by: 4) {
                let offset = x * 4
                let blue = Double(row[offset])
                let green = Double(row[offset + 1])
                let red = Double(row[offset + 2])
                let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
                if let previousLuminance {
                    focusEnergy += abs(luminance - previousLuminance)
                    focusComparisons += 1
                }
                if let previousRowLuminance = previousRowLuminances[columnIndex] {
                    focusEnergy += abs(luminance - previousRowLuminance)
                    focusComparisons += 1
                }
                previousRowLuminances[columnIndex] = luminance
                previousLuminance = luminance
                if red > 244, green > 244, blue > 244 {
                    glareCount += 1
                }
                luminanceValues.append(luminance)
                samples.append(SampledPixel(x: x, y: y, luminance: luminance))
                total += luminance
                signature += luminance * Double((x - startX + 1) * (y - startY + 1) % 97)
                count += 1
                columnIndex += 1
            }
        }

        guard count > 0 else { return nil }
        let average = total / Double(count)
        let sorted = luminanceValues.sorted()
        let p05 = sorted[max(0, sorted.count / 20)]
        let p10 = sorted[max(0, sorted.count / 10)]
        let lowPercentile = sorted[max(0, sorted.count / 6)]
        let median = sorted[sorted.count / 2]
        let contrast = max(0, min(1, (median - lowPercentile) / 82))
        let thresholds = [
            p05 + max(5, (median - p05) * 0.20),
            p10 + max(7, (median - p10) * 0.26),
            lowPercentile + max(8, (median - lowPercentile) * 0.34),
            lowPercentile + max(12, (median - lowPercentile) * 0.45)
        ]
        .map { min(104, max(14, $0)) }

        let classicalCandidate = bestCandidate(samples: samples, thresholds: thresholds, roi: roi, contrast: contrast)
        let selectedCandidate = [classicalCandidate, mlCandidate]
            .compactMap { $0 }
            .max { $0.likelihood < $1.likelihood }
        guard let selectedCandidate else { return nil }

        let diameter = selectedCandidate.diameterPixels
        let centerQuality = selectedCandidate.centerQuality
        let segmentationQuality = selectedCandidate.segmentationQuality
        let sharpnessQuality = max(0, min(1, (focusEnergy / Double(max(focusComparisons, 1)) - 4) / 20))
        let pupilCenter = selectedCandidate.center
        let normalizedPupilCenter = CGPoint(x: pupilCenter.x / Double(width), y: pupilCenter.y / Double(height))
        let centerOffset = hypot(normalizedPupilCenter.x - 0.5, normalizedPupilCenter.y - 0.5)
        let eyeDetectionQuality = max(0, min(1, (activeROI?.quality ?? 0) * 0.78 + centerQuality * 0.22))
        let glareRatio = Double(glareCount) / Double(max(count, 1))
        let glareQuality = max(0, min(1, 1 - glareRatio / 0.10))
        let occlusionRisk = max(
            0,
            min(
                1,
                max(0, 0.58 - selectedCandidate.roundnessQuality) * 0.72
                    + max(0, 0.45 - selectedCandidate.areaQuality) * 0.40
                    + max(0, 0.38 - centerQuality) * 0.35
                    + max(0, glareRatio - 0.04) * 3.0
            )
        )
        let measurementQuality = max(
            0,
            min(
                1,
                segmentationQuality * 0.34
                    + eyeDetectionQuality * 0.18
                    + sharpnessQuality * 0.22
                    + glareQuality * 0.14
                    + selectedCandidate.roundnessQuality * 0.12
            )
        )
        let normalizedSignature = signature / Double(max(count, 1)) / 10000

        return PupilFrameSample(
            capturedAt: Date(),
            brightness: average,
            pupilDiameterPixels: diameter,
            signature: normalizedSignature,
            segmentationQuality: segmentationQuality,
            eyeDetectionQuality: eyeDetectionQuality,
            sharpnessQuality: sharpnessQuality,
            centerOffset: centerOffset,
            glareRatio: glareRatio,
            occlusionRisk: occlusionRisk,
            measurementQuality: measurementQuality,
            usedNeuralSegmentation: selectedCandidate.source == .neural,
            roi: roi,
            detectedEyeROI: detectedROI
        )
    }

    private static func bestCandidate(samples: [SampledPixel], thresholds: [Double], roi: CGRect, contrast: Double) -> PupilCandidate? {
        thresholds
            .compactMap { threshold in
                pupilCandidate(samples: samples, threshold: threshold, roi: roi, contrast: contrast)
            }
            .max { $0.likelihood < $1.likelihood }
    }

    private static func pupilCandidate(samples: [SampledPixel], threshold: Double, roi: CGRect, contrast: Double) -> PupilCandidate? {
        var darkPoints: [CGPoint] = []
        darkPoints.reserveCapacity(samples.count / 4)
        for sample in samples where sample.luminance < threshold {
            darkPoints.append(CGPoint(x: sample.x, y: sample.y))
        }
        guard darkPoints.count >= 6 else { return nil }

        let sampledAreaScale = 16.0
        let darkArea = Double(darkPoints.count) * sampledAreaScale
        let diameter = max(0, 2 * sqrt(darkArea / Double.pi))
        let roiArea = max(1, Double(roi.width * roi.height))
        let darkAreaRatio = darkArea / roiArea
        let areaQuality = triangularScore(value: darkAreaRatio, ideal: 0.105, tolerance: 0.125)
        let center = averagePoint(darkPoints)
        let centerQuality = centerQuality(for: darkPoints, roi: roi)
        let roundnessQuality = roundnessQuality(for: darkPoints)
        let diameterQuality = triangularScore(value: diameter / max(1, Double(min(roi.width, roi.height))), ideal: 0.34, tolerance: 0.28)
        let densityQuality = densityQuality(for: darkPoints)
        let likelihood = pupilLikelihood(
            contrast: contrast,
            areaQuality: areaQuality,
            centerQuality: centerQuality,
            roundnessQuality: roundnessQuality,
            diameterQuality: diameterQuality,
            densityQuality: densityQuality
        )
        let segmentationQuality = max(0, min(1, likelihood * 0.68 + contrast * 0.16 + centerQuality * 0.16))

        return PupilCandidate(
            diameterPixels: diameter,
            likelihood: likelihood,
            segmentationQuality: segmentationQuality,
            center: center,
            centerQuality: centerQuality,
            roundnessQuality: roundnessQuality,
            areaQuality: areaQuality,
            source: .classical
        )
    }

    private static func fallbackROI(width: Int, height: Int) -> CGRect {
        let roiWidth = max(80, width / 4)
        let roiHeight = max(60, height / 6)
        return CGRect(
            x: max(0, (width - roiWidth) / 2),
            y: max(0, (height - roiHeight) / 2),
            width: roiWidth,
            height: roiHeight
        )
    }

    private static func detectEyeROI(in pixelBuffer: CVPixelBuffer, targetEye: PupilEyeSide, width: Int, height: Int) -> DetectedEyeROI? {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let face = request.results?.first,
              let landmarks = face.landmarks,
              let region = targetEye == .left ? landmarks.leftEye : landmarks.rightEye,
              region.pointCount >= 4
        else {
            return nil
        }

        let points = region.normalizedPoints.map { point in
            CGPoint(
                x: (face.boundingBox.minX + CGFloat(point.x) * face.boundingBox.width) * CGFloat(width),
                y: (1 - (face.boundingBox.minY + CGFloat(point.y) * face.boundingBox.height)) * CGFloat(height)
            )
        }

        guard let bounds = pointBounds(for: points) else {
            return nil
        }

        let eyeWidth = max(42, bounds.width)
        let eyeHeight = max(28, bounds.height)
        let expanded = CGRect(
            x: bounds.minX - eyeWidth * 0.75,
            y: bounds.minY - eyeHeight * 1.25,
            width: eyeWidth * 2.5,
            height: eyeHeight * 3.2
        ).intersection(CGRect(x: 0, y: 0, width: width, height: height))

        guard expanded.width >= 42, expanded.height >= 28 else { return nil }

        let faceArea = face.boundingBox.width * face.boundingBox.height
        let faceQuality = max(0, min(1, Double(face.confidence) * 0.65 + Double(faceArea) * 1.3))
        let center = CGPoint(x: expanded.midX / CGFloat(width), y: expanded.midY / CGFloat(height))
        let guideDistance = hypot(center.x - 0.5, center.y - 0.5)
        let guideQuality = max(0, 1 - Double(guideDistance) * 2.4)

        return DetectedEyeROI(rect: expanded, quality: max(0, min(1, faceQuality * 0.72 + guideQuality * 0.28)))
    }

    fileprivate static func centerQuality(for points: [CGPoint], roi: CGRect) -> Double {
        guard !points.isEmpty else { return 0 }
        let center = averagePoint(points)
        let normalizedX = abs(center.x - roi.midX) / max(1, roi.width / 2)
        let normalizedY = abs(center.y - roi.midY) / max(1, roi.height / 2)
        return max(0, 1 - Double(hypot(normalizedX, normalizedY)) * 0.82)
    }

    fileprivate static func roundnessQuality(for points: [CGPoint]) -> Double {
        guard points.count >= 6, let bounds = pointBounds(for: points) else { return 0 }
        let width = max(1, bounds.width)
        let height = max(1, bounds.height)
        let ratio = Double(min(width, height) / max(width, height))
        return max(0, min(1, (ratio - 0.34) / 0.46))
    }

    private static func densityQuality(for points: [CGPoint]) -> Double {
        guard points.count >= 6, let bounds = pointBounds(for: points) else { return 0 }
        let boxArea = max(1, Double(bounds.width * bounds.height))
        let sampledArea = Double(points.count) * 16
        return triangularScore(value: sampledArea / boxArea, ideal: 0.66, tolerance: 0.44)
    }

    fileprivate static func averagePoint(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        var totalX: CGFloat = 0
        var totalY: CGFloat = 0
        for point in points {
            totalX += point.x
            totalY += point.y
        }
        let count = CGFloat(points.count)
        return CGPoint(x: totalX / count, y: totalY / count)
    }

    fileprivate static func pointBounds(for points: [CGPoint]) -> CGRect? {
        guard var minX = points.first?.x,
              var maxX = points.first?.x,
              var minY = points.first?.y,
              var maxY = points.first?.y
        else {
            return nil
        }

        for point in points.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func pupilLikelihood(
        contrast: Double,
        areaQuality: Double,
        centerQuality: Double,
        roundnessQuality: Double,
        diameterQuality: Double,
        densityQuality: Double
    ) -> Double {
        let score = -2.05
            + 1.50 * contrast
            + 1.25 * areaQuality
            + 1.10 * centerQuality
            + 1.05 * roundnessQuality
            + 0.85 * diameterQuality
            + 0.65 * densityQuality
        return 1 / (1 + exp(-score))
    }

    private static func triangularScore(value: Double, ideal: Double, tolerance: Double) -> Double {
        max(0, 1 - abs(value - ideal) / max(tolerance, 0.001))
    }
}

private struct SampledPixel {
    let x: Int
    let y: Int
    let luminance: Double
}

private struct PupilCandidate {
    let diameterPixels: Double
    let likelihood: Double
    let segmentationQuality: Double
    let center: CGPoint
    let centerQuality: Double
    let roundnessQuality: Double
    let areaQuality: Double
    let source: PupilSegmentationSource
}

private enum PupilSegmentationSource {
    case classical
    case neural
}

private struct DetectedEyeROI {
    let rect: CGRect
    let quality: Double
}

private enum PupilTrainingCapturePhase: String, Codable {
    case livePreview
    case baseline
    case torchTransition
    case reaction
}

private struct PupilTrainingFrameContext {
    let schemaVersion: Int
    let captureID: String?
    let captureMode: String
    let phase: PupilTrainingCapturePhase
    let elapsedSeconds: Double?
    let torchIsOn: Bool
    let acceptedForTraining: Bool
    let neuralModelAvailable: Bool
}

private final class PupilTrainingFrameRecorder {
    private let ciContext = CIContext()
    private let queue = DispatchQueue(label: "com.aidflow.pupil.training-recorder", qos: .utility)
    private lazy var folderURL: URL? = {
        guard let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let folder = supportURL
            .appendingPathComponent("AidFlow", isDirectory: true)
            .appendingPathComponent("PupilTrainingFrames", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    func save(pixelBuffer: CVPixelBuffer, sample: PupilFrameSample, eye: PupilEyeSide, distanceCentimeters: Double?, context: PupilTrainingFrameContext) {
        guard let folderURL else { return }
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let baseName = "\(timestamp)-\(eye.rawValue.lowercased())-\(UUID().uuidString.prefix(8))"
        let imageURL = folderURL.appendingPathComponent("\(baseName).png")
        let metadataURL = folderURL.appendingPathComponent("\(baseName).json")
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let roi = sample.roi

        queue.async { [ciContext] in
            let image = CIImage(cvPixelBuffer: pixelBuffer)
            let cropRect = CGRect(
                x: roi.minX,
                y: CGFloat(height) - roi.maxY,
                width: roi.width,
                height: roi.height
            ).intersection(CGRect(x: 0, y: 0, width: width, height: height))

            if !cropRect.isEmpty {
                let cropped = image.cropped(to: cropRect)
                if let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                   let data = ciContext.pngRepresentation(of: cropped, format: .RGBA8, colorSpace: colorSpace) {
                    try? data.write(to: imageURL, options: [.atomic])
                }
            }

            let metadata = PupilTrainingFrameMetadata(
                schemaVersion: context.schemaVersion,
                imageFile: imageURL.lastPathComponent,
                eye: eye.rawValue,
                recordedAt: Date(),
                captureID: context.captureID,
                captureMode: context.captureMode,
                capturePhase: context.phase.rawValue,
                elapsedSeconds: context.elapsedSeconds,
                torchIsOn: context.torchIsOn,
                acceptedForTraining: context.acceptedForTraining,
                neuralModelAvailable: context.neuralModelAvailable,
                frameWidth: width,
                frameHeight: height,
                roiX: Double(roi.minX),
                roiY: Double(roi.minY),
                roiWidth: Double(roi.width),
                roiHeight: Double(roi.height),
                brightness: sample.brightness,
                pupilDiameterPixels: sample.pupilDiameterPixels,
                segmentationQuality: sample.segmentationQuality,
                eyeDetectionQuality: sample.eyeDetectionQuality,
                sharpnessQuality: sample.sharpnessQuality,
                glareRatio: sample.glareRatio,
                occlusionRisk: sample.occlusionRisk,
                measurementQuality: sample.measurementQuality,
                usedNeuralSegmentation: sample.usedNeuralSegmentation,
                centerOffset: sample.centerOffset,
                distanceCentimeters: distanceCentimeters
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(metadata) {
                try? data.write(to: metadataURL, options: [.atomic])
            }
        }
    }
}

private struct PupilTrainingFrameMetadata: Codable {
    let schemaVersion: Int
    let imageFile: String
    let eye: String
    let recordedAt: Date
    let captureID: String?
    let captureMode: String
    let capturePhase: String
    let elapsedSeconds: Double?
    let torchIsOn: Bool
    let acceptedForTraining: Bool
    let neuralModelAvailable: Bool
    let frameWidth: Int
    let frameHeight: Int
    let roiX: Double
    let roiY: Double
    let roiWidth: Double
    let roiHeight: Double
    let brightness: Double
    let pupilDiameterPixels: Double
    let segmentationQuality: Double
    let eyeDetectionQuality: Double
    let sharpnessQuality: Double
    let glareRatio: Double
    let occlusionRisk: Double
    let measurementQuality: Double
    let usedNeuralSegmentation: Bool
    let centerOffset: Double
    let distanceCentimeters: Double?
}

private final class PupilMLSegmenter {
    private let visionModel: VNCoreMLModel?

    init() {
        if let url = Bundle.main.url(forResource: "PupilSegmentation", withExtension: "mlmodelc"),
           let model = try? MLModel(contentsOf: url),
           let visionModel = try? VNCoreMLModel(for: model) {
            self.visionModel = visionModel
        } else {
            self.visionModel = nil
        }
    }

    var isAvailable: Bool {
        visionModel != nil
    }

    func pupilCandidate(in pixelBuffer: CVPixelBuffer, roi: CGRect, orientation: CGImagePropertyOrientation) -> PupilCandidate? {
        guard let visionModel else { return nil }
        var observations: [VNObservation] = []
        let request = VNCoreMLRequest(model: visionModel) { request, _ in
            observations = request.results ?? []
        }
        request.imageCropAndScaleOption = .scaleFill
        request.regionOfInterest = normalizedVisionROI(roi: roi, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        if let pixelObservation = observations.compactMap({ $0 as? VNPixelBufferObservation }).first {
            return candidate(fromMask: pixelObservation.pixelBuffer, roi: roi)
        }

        if let featureObservation = observations.compactMap({ $0 as? VNCoreMLFeatureValueObservation }).first,
           let multiArray = featureObservation.featureValue.multiArrayValue {
            return candidate(from: multiArray, roi: roi)
        }

        return nil
    }

    private func normalizedVisionROI(roi: CGRect, width: Int, height: Int) -> CGRect {
        guard width > 0, height > 0 else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        let x = max(0, min(1, roi.minX / CGFloat(width)))
        let yFromTop = max(0, min(1, roi.minY / CGFloat(height)))
        let w = max(0.02, min(1 - x, roi.width / CGFloat(width)))
        let h = max(0.02, min(1 - yFromTop, roi.height / CGFloat(height)))
        return CGRect(x: x, y: max(0, 1 - yFromTop - h), width: w, height: h)
    }

    private func candidate(fromMask mask: CVPixelBuffer, roi: CGRect) -> PupilCandidate? {
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }

        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(mask)
        guard let baseAddress = CVPixelBufferGetBaseAddress(mask), width > 0, height > 0 else { return nil }

        var points: [CGPoint] = []
        var totalConfidence = 0.0
        var count = 0

        for y in stride(from: 0, to: height, by: 2) {
            let row = baseAddress.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in stride(from: 0, to: width, by: 2) {
                let value = Double(row[x]) / 255
                guard value > 0.50 else { continue }
                let mapped = CGPoint(
                    x: roi.minX + (CGFloat(x) / CGFloat(width)) * roi.width,
                    y: roi.minY + (CGFloat(y) / CGFloat(height)) * roi.height
                )
                points.append(mapped)
                totalConfidence += value
                count += 1
            }
        }

        return candidate(fromMaskPoints: points, meanMaskConfidence: totalConfidence / Double(max(count, 1)), roi: roi)
    }

    private func candidate(from multiArray: MLMultiArray, roi: CGRect) -> PupilCandidate? {
        let shape = multiArray.shape.map(\.intValue)
        guard let height = shape.suffix(2).first, let width = shape.suffix(1).first, width > 0, height > 0 else { return nil }
        let count = multiArray.count
        guard count >= width * height else { return nil }

        let offset = count - width * height
        var values: [Double] = []
        values.reserveCapacity(width * height)
        for index in 0..<(width * height) {
            values.append(multiArray[offset + index].doubleValue)
        }

        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = max(0.0001, maxValue - minValue)
        var points: [CGPoint] = []
        var confidenceTotal = 0.0

        for y in stride(from: 0, to: height, by: 2) {
            for x in stride(from: 0, to: width, by: 2) {
                let normalized = (values[y * width + x] - minValue) / range
                guard normalized > 0.55 else { continue }
                points.append(
                    CGPoint(
                        x: roi.minX + (CGFloat(x) / CGFloat(width)) * roi.width,
                        y: roi.minY + (CGFloat(y) / CGFloat(height)) * roi.height
                    )
                )
                confidenceTotal += normalized
            }
        }

        return candidate(fromMaskPoints: points, meanMaskConfidence: confidenceTotal / Double(max(points.count, 1)), roi: roi)
    }

    private func candidate(fromMaskPoints points: [CGPoint], meanMaskConfidence: Double, roi: CGRect) -> PupilCandidate? {
        guard points.count >= 8 else { return nil }
        let bounds = PupilFrameAnalyzer.pointBounds(for: points)
        let width = max(1, bounds?.width ?? roi.width)
        let height = max(1, bounds?.height ?? roi.height)
        let diameter = Double((width + height) / 2)
        let areaRatio = Double(points.count * 4) / max(1, Double(roi.width * roi.height))
        let areaQuality = max(0, 1 - abs(areaRatio - 0.11) / 0.14)
        let center = PupilFrameAnalyzer.averagePoint(points)
        let centerQuality = PupilFrameAnalyzer.centerQuality(for: points, roi: roi)
        let roundnessQuality = PupilFrameAnalyzer.roundnessQuality(for: points)
        let densityQuality = max(0, min(1, meanMaskConfidence))
        let likelihood = 1 / (1 + exp(-(-1.35 + 1.60 * densityQuality + 1.15 * areaQuality + 1.00 * centerQuality + 0.90 * roundnessQuality)))
        let segmentationQuality = max(0, min(1, likelihood * 0.72 + densityQuality * 0.28))

        return PupilCandidate(
            diameterPixels: diameter,
            likelihood: likelihood,
            segmentationQuality: segmentationQuality,
            center: center,
            centerQuality: centerQuality,
            roundnessQuality: roundnessQuality,
            areaQuality: areaQuality,
            source: .neural
        )
    }
}
