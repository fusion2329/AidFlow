import SwiftUI

struct MainTabView: View {
    @AppStorage("safetyDisclaimerAccepted") private var safetyDisclaimerAccepted = false
    @State private var selectedTab: AppTab = .home
    @State private var showingArrivalFromLiveActivity = false
    @State private var homeStackID = UUID()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .id(homeStackID)
            .tabItem {
                Label("Home".afLocalized, systemImage: "house.fill")
            }
            .tag(AppTab.home)

            NavigationStack {
                PastIncidentsView()
            }
            .tabItem {
                Label("Routine".afLocalized, systemImage: "calendar.badge.clock")
            }
            .tag(AppTab.routine)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings".afLocalized, systemImage: "gearshape.fill")
            }
            .tag(AppTab.settings)
        }
        .tint(Color.sceneAccent)
        .fullScreenCover(isPresented: $showingArrivalFromLiveActivity) {
            NavigationStack {
                ArrivalModeView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done".afLocalized) {
                                showingArrivalFromLiveActivity = false
                            }
                        }
                    }
            }
        }
        .onOpenURL { url in
            guard url.scheme == "aidflow", url.host == "arrival" else { return }
            selectedTab = .home
            showingArrivalFromLiveActivity = true
        }
        .onChange(of: selectedTab) { newValue in
            if newValue == .home {
                homeStackID = UUID()
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { !safetyDisclaimerAccepted },
                set: { _ in }
            )
        ) {
            NavigationStack {
                FirstLaunchSafetyDisclaimerView {
                    safetyDisclaimerAccepted = true
                }
            }
            .interactiveDismissDisabled(true)
        }
    }
}

private enum AppTab: Hashable {
    case home
    case routine
    case settings
}
