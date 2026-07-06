import Foundation

struct WatchTimelineEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let title: String
    let detail: String
}

final class WatchSceneStore: ObservableObject {
    @Published private(set) var sceneStartedAt: Date?
    @Published private(set) var checklistIndex = 0
    @Published private(set) var compressionCount = 0
    @Published private(set) var cycleCount = 0
    @Published private(set) var isCPRRunning = false
    @Published private(set) var timeline: [WatchTimelineEntry] = []

    let checklistSteps = [
        "Danger",
        "Response",
        "Airway",
        "Breathing",
        "Call 000",
        "Monitor"
    ]

    var hasActiveScene: Bool {
        sceneStartedAt != nil
    }

    var currentChecklistStep: String {
        checklistSteps[min(checklistIndex, checklistSteps.count - 1)]
    }

    var cprPhaseText: String {
        compressionCount >= 30 ? "2 breaths" : "Compressions"
    }

    func startScene() {
        guard sceneStartedAt == nil else { return }
        let startedAt = Date()
        sceneStartedAt = startedAt
        checklistIndex = 0
        timeline = [
            WatchTimelineEntry(
                timestamp: startedAt,
                title: "Scene started",
                detail: "Watch quick log opened."
            )
        ]
    }

    func resetScene() {
        sceneStartedAt = nil
        checklistIndex = 0
        compressionCount = 0
        cycleCount = 0
        isCPRRunning = false
        timeline = []
    }

    func markCurrentStepDone() {
        startScene()
        let completedStep = currentChecklistStep
        appendEvent(title: completedStep, detail: "Marked done on watch.")
        checklistIndex = min(checklistIndex + 1, checklistSteps.count - 1)
    }

    func appendEvent(title: String, detail: String = "") {
        timeline.insert(
            WatchTimelineEntry(timestamp: Date(), title: title, detail: detail),
            at: 0
        )
    }

    func toggleCPR() {
        startScene()
        isCPRRunning.toggle()
        appendEvent(
            title: isCPRRunning ? "CPR started" : "CPR paused",
            detail: cprPhaseText
        )
    }

    func addCompression() {
        startScene()
        guard compressionCount < 30 else { return }
        compressionCount += 1
        if compressionCount == 30 {
            appendEvent(title: "30 compressions", detail: "Give 2 breaths if trained.")
        }
    }

    func completeBreaths() {
        startScene()
        cycleCount += 1
        compressionCount = 0
        appendEvent(title: "CPR cycle \(cycleCount)", detail: "30:2 cycle completed.")
    }
}
