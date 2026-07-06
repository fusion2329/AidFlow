import SwiftUI

struct WatchChecklistView: View {
    @EnvironmentObject private var sceneStore: WatchSceneStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(sceneStore.currentChecklistStep)
                .font(.title2.bold())
                .lineLimit(2)

            ProgressView(value: Double(sceneStore.checklistIndex + 1), total: Double(sceneStore.checklistSteps.count))
                .tint(.green)

            VStack(spacing: 8) {
                Button {
                    sceneStore.markCurrentStepDone()
                } label: {
                    Label("Done", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button {
                    sceneStore.appendEvent(title: "Needs attention", detail: sceneStore.currentChecklistStep)
                } label: {
                    Label("Log note", systemImage: "exclamationmark.triangle")
                        .frame(maxWidth: .infinity)
                }
            }

            List {
                ForEach(Array(sceneStore.checklistSteps.enumerated()), id: \.offset) { index, step in
                    HStack {
                        Image(systemName: index < sceneStore.checklistIndex ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(index < sceneStore.checklistIndex ? .green : .secondary)
                        Text(step)
                    }
                    .font(.caption)
                }
            }
            .listStyle(.carousel)
        }
        .padding(.top, 8)
        .navigationTitle("Scene")
        .onAppear {
            sceneStore.startScene()
        }
    }
}

#Preview {
    NavigationStack {
        WatchChecklistView()
            .environmentObject(WatchSceneStore())
    }
}
