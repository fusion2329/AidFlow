import ActivityKit
import Foundation

struct AidFlowLiveActivityAttributes: ActivityAttributes {
    struct CPRState: Codable, Hashable {
        var isRunning: Bool
        var compressionCount: Int
        var cycleCount: Int
        var isBreathPhase: Bool
        var breathSecondsRemaining: Int
        var startedAt: Date
        var updatedAt: Date

        var phaseTitle: String {
            isBreathPhase ? "Give breaths" : "CPR compressions"
        }

        var phaseValue: String {
            isBreathPhase ? "\(breathSecondsRemaining)s" : "\(compressionCount)/30"
        }
    }

    struct ContentState: Codable, Hashable {
        var stepTitle: String
        var stepPrompt: String
        var stepNumber: Int
        var totalSteps: Int
        var startedAt: Date
        var address: String
        var coordinateText: String
        var cprState: CPRState?
    }

    var incidentID: String
}
