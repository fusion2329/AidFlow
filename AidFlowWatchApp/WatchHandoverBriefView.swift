import SwiftUI

struct WatchHandoverBriefView: View {
    @EnvironmentObject private var sceneStore: WatchSceneStore

    var body: some View {
        List {
            Section("MIST") {
                HandoverLine(label: "Mechanism", value: sceneStore.hasActiveScene ? "First aid scene" : "Not started")
                HandoverLine(label: "Injuries", value: "Check iPhone")
                HandoverLine(label: "Signs", value: "CPR \(sceneStore.compressionCount)/30")
                HandoverLine(label: "Treatment", value: sceneStore.cprPhaseText)
            }

            Section("Timeline") {
                if sceneStore.timeline.isEmpty {
                    Text("No events yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sceneStore.timeline.prefix(6)) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.caption.weight(.semibold))
                            Text(entry.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if !entry.detail.isEmpty {
                                Text(entry.detail)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Handover")
    }
}

private struct HandoverLine: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
        }
    }
}

#Preview {
    NavigationStack {
        WatchHandoverBriefView()
            .environmentObject(WatchSceneStore())
    }
}
