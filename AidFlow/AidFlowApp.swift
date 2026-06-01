import SwiftUI

@main
struct AidFlowApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var incidentStore = IncidentStore()
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(incidentStore)
                .environment(\.layoutDirection, AppLanguage.current.usesRightToLeftLayout ? .rightToLeft : .leftToRight)
                .id(appLanguage)
                .task {
                    incidentStore.loadDatabaseIfNeeded()
                }
                .onChange(of: scenePhase) { phase in
                    guard phase == .background else { return }
                    incidentStore.flushDatabase()
                }
        }
    }
}
