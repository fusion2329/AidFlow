import ActivityKit
import Foundation
import OSLog

private let liveActivityLogger = Logger(subsystem: "AidFlow", category: "LiveActivity")

final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private let standaloneCPRIncidentID = "standalone-cpr"
    private var currentActivity: Activity<AidFlowLiveActivityAttributes>?
    private var cprStates: [UUID: AidFlowLiveActivityAttributes.CPRState] = [:]

    private init() {}

    func startOrUpdate(for incident: Incident) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        Task {
            let state = contentState(for: incident)
            let content = ActivityContent(state: state, staleDate: nil)
            await endDuplicateActivities(keeping: incident.id.uuidString)

            if let activity = activity(forIncidentID: incident.id.uuidString) {
                currentActivity = activity
                await activity.update(content)
                return
            }

            do {
                currentActivity = try Activity.request(
                    attributes: AidFlowLiveActivityAttributes(incidentID: incident.id.uuidString),
                    content: content,
                    pushType: nil
                )
            } catch {
                #if DEBUG
                liveActivityLogger.debug("Live Activity request failed: \(error.localizedDescription, privacy: .public)")
                #endif
            }
        }
    }

    func end(for incident: Incident?) {
        Task {
            if let incident {
                cprStates[incident.id] = nil
                let matchingActivities = Activity<AidFlowLiveActivityAttributes>.activities.filter {
                    $0.attributes.incidentID == incident.id.uuidString
                }
                for activity in matchingActivities {
                    await activity.end(ActivityContent(state: contentState(for: incident), staleDate: nil), dismissalPolicy: .immediate)
                    if currentActivity?.id == activity.id {
                        currentActivity = nil
                    }
                }
                return
            }

            for activity in Activity<AidFlowLiveActivityAttributes>.activities {
                await activity.end(ActivityContent(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate)
                if currentActivity?.id == activity.id {
                    currentActivity = nil
                }
            }
            cprStates.removeAll()
        }
    }

    func updateCPRState(_ cprState: AidFlowLiveActivityAttributes.CPRState?, for incident: Incident?) {
        guard let incident else { return }
        if let cprState {
            cprStates[incident.id] = cprState
        } else {
            cprStates[incident.id] = nil
        }
        startOrUpdate(for: incident)
    }

    func updateStandaloneCPRState(_ cprState: AidFlowLiveActivityAttributes.CPRState?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        Task {
            if let cprState {
                let state = standaloneCPRContentState(cprState: cprState)
                let content = ActivityContent(state: state, staleDate: nil)
                await endDuplicateActivities(keeping: standaloneCPRIncidentID)

                if let activity = activity(forIncidentID: standaloneCPRIncidentID) {
                    currentActivity = activity
                    await activity.update(content)
                    return
                }

                do {
                    currentActivity = try Activity.request(
                        attributes: AidFlowLiveActivityAttributes(incidentID: standaloneCPRIncidentID),
                        content: content,
                        pushType: nil
                    )
                } catch {
                    #if DEBUG
                    liveActivityLogger.debug("Standalone CPR Live Activity request failed: \(error.localizedDescription, privacy: .public)")
                    #endif
                }
            } else {
                await endStandaloneCPRActivity()
            }
        }
    }

    private func activity(forIncidentID incidentID: String) -> Activity<AidFlowLiveActivityAttributes>? {
        if let currentActivity, currentActivity.attributes.incidentID == incidentID {
            return currentActivity
        }

        return Activity<AidFlowLiveActivityAttributes>.activities.first {
            $0.attributes.incidentID == incidentID
        }
    }

    private func endDuplicateActivities(keeping incidentID: String) async {
        let activeActivities = Activity<AidFlowLiveActivityAttributes>.activities
        var didKeepOneMatchingActivity = false

        for activity in activeActivities {
            if activity.attributes.incidentID == incidentID, !didKeepOneMatchingActivity {
                didKeepOneMatchingActivity = true
                continue
            }

            await activity.end(ActivityContent(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate)
            if currentActivity?.id == activity.id {
                currentActivity = nil
            }
        }
    }

    private func endStandaloneCPRActivity() async {
        let matchingActivities = Activity<AidFlowLiveActivityAttributes>.activities.filter {
            $0.attributes.incidentID == standaloneCPRIncidentID
        }
        for activity in matchingActivities {
            await activity.end(ActivityContent(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate)
            if currentActivity?.id == activity.id {
                currentActivity = nil
            }
        }
    }

    private func contentState(for incident: Incident) -> AidFlowLiveActivityAttributes.ContentState {
        let totalSteps = ArrivalFlow.steps.count
        let stepIndex = min(max(incident.arrivalStepIndex, 0), totalSteps)
        let step = stepIndex < totalSteps ? ArrivalFlow.steps[stepIndex] : nil
        let location = incident.location
        let cprState = cprStates[incident.id]

        return AidFlowLiveActivityAttributes.ContentState(
            stepTitle: AppStrings.display(step?.title ?? "Checklist complete"),
            stepPrompt: AppStrings.display(step?.prompt ?? "Keep monitoring, update the timeline, and prepare handover."),
            stepNumber: min(stepIndex + 1, totalSteps),
            totalSteps: totalSteps,
            startedAt: cprState?.startedAt ?? incident.startedAt,
            address: addressText(for: location),
            coordinateText: location?.coordinateText ?? "",
            cprState: cprState
        )
    }

    private func standaloneCPRContentState(cprState: AidFlowLiveActivityAttributes.CPRState) -> AidFlowLiveActivityAttributes.ContentState {
        AidFlowLiveActivityAttributes.ContentState(
            stepTitle: "CPR Counter",
            stepPrompt: "Follow the 110/min compression rhythm.",
            stepNumber: 0,
            totalSteps: 0,
            startedAt: cprState.startedAt,
            address: "Standalone CPR tool",
            coordinateText: "",
            cprState: cprState
        )
    }

    private func addressText(for location: IncidentLocation?) -> String {
        guard let location else { return "Location not captured".afLocalized }

        let address = location.address.trimmingCharacters(in: .whitespacesAndNewlines)
        return address.isEmpty ? "Location not captured".afLocalized : address
    }
}
