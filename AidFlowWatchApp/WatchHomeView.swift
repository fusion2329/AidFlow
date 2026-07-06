import SwiftUI

struct WatchHomeView: View {
    @EnvironmentObject private var sceneStore: WatchSceneStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    statusPanel

                    NavigationLink {
                        WatchChecklistView()
                    } label: {
                        WatchActionRow(title: "Scene", subtitle: sceneStore.currentChecklistStep, systemImage: "cross.case.fill")
                    }

                    NavigationLink {
                        WatchCPRView()
                    } label: {
                        WatchActionRow(title: "CPR", subtitle: sceneStore.cprPhaseText, systemImage: "waveform.path.ecg")
                    }

                    NavigationLink {
                        WatchHandoverBriefView()
                    } label: {
                        WatchActionRow(title: "Handover", subtitle: "\(sceneStore.timeline.count) events", systemImage: "doc.text.fill")
                    }
                }
                .padding(.vertical, 6)
            }
            .navigationTitle("AidFlow")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if sceneStore.hasActiveScene {
                        Button(role: .destructive) {
                            sceneStore.resetScene()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Reset scene")
                    }
                }
            }
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sceneStore.hasActiveScene ? "Active scene" : "Ready")
                .font(.headline)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(elapsedText(at: context.date))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
            }

            Text(sceneStore.hasActiveScene ? "Next: \(sceneStore.currentChecklistStep)" : "Tap Scene to start")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func elapsedText(at date: Date) -> String {
        guard let startedAt = sceneStore.sceneStartedAt else { return "00:00" }
        let elapsed = max(0, Int(date.timeIntervalSince(startedAt)))
        return String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
    }
}

struct WatchActionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)
                .frame(width: 28, height: 28)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    WatchHomeView()
        .environmentObject(WatchSceneStore())
}
