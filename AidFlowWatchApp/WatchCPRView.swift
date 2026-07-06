import SwiftUI

struct WatchCPRView: View {
    @EnvironmentObject private var sceneStore: WatchSceneStore

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(sceneStore.cprPhaseText)
                    .font(.headline)
                Text("\(sceneStore.compressionCount)/30")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("Cycle \(sceneStore.cycleCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if sceneStore.compressionCount >= 30 {
                Button {
                    sceneStore.completeBreaths()
                } label: {
                    Label("Breaths done", systemImage: "lungs.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            } else {
                Button {
                    sceneStore.addCompression()
                } label: {
                    Label("Compression", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }

            Button {
                sceneStore.toggleCPR()
            } label: {
                Label(sceneStore.isCPRRunning ? "Pause" : "Start", systemImage: sceneStore.isCPRRunning ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 8)
        .navigationTitle("CPR")
        .onAppear {
            sceneStore.startScene()
        }
    }
}

#Preview {
    NavigationStack {
        WatchCPRView()
            .environmentObject(WatchSceneStore())
    }
}
