import SwiftUI

@main
struct AidFlowWatchApp: App {
    @StateObject private var sceneStore = WatchSceneStore()

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(sceneStore)
                .preferredColorScheme(.dark)
        }
    }
}
