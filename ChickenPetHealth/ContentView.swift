//
//  ContentView.swift
//  ChickenPetHealth
//

import SwiftUI
import AppTrackingTransparency

struct ContentView: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0

    var body: some View {
        // Use chosen theme or fall back to current device scheme
        let activeScheme: ColorScheme = store.themeMode.colorScheme ?? colorScheme

        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            BirdsView()
                .tabItem { Label("Birds", systemImage: "bird.fill") }
                .tag(1)

            TreatmentLogView()
                .tabItem { Label("Treatment", systemImage: "pills.fill") }
                .tag(2)

            AnalyticsView()
                .tabItem { Label("Analytics", systemImage: "chart.pie.fill") }
                .tag(3)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .tint(Theme.accent)
        .preferredColorScheme(activeScheme)
        .environment(\.colorScheme, activeScheme)
        .animation(.none, value: selectedTab)
        .background(Theme.background(for: activeScheme).ignoresSafeArea())
        .onAppear {
            applyAppearance(for: activeScheme)
            requestTrackingPermissionIfNeeded()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                requestTrackingPermissionIfNeeded()
            }
        }
        .onChange(of: store.themeMode) { _ in
            let scheme: ColorScheme = store.themeMode.colorScheme ?? colorScheme
            applyAppearance(for: scheme)
        }
    }

    private func requestTrackingPermissionIfNeeded() {
        guard #available(iOS 14, *), ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            ATTrackingManager.requestTrackingAuthorization { _ in }
        }
    }

    private func applyAppearance(for scheme: ColorScheme) {
        let background = UIColor(Theme.background(for: scheme))

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = background
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = .white

        // Keep the tab bar flush with our background without blur or glass
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundEffect = nil
        tabAppearance.backgroundColor = .clear
        tabAppearance.shadowColor = .clear
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().isTranslucent = true
        UITabBar.appearance().tintColor = .white
        UITabBar.appearance().unselectedItemTintColor = UIColor.white.withAlphaComponent(0.75)
    }
}

#if DEBUG
#Preview {
    ContentView()
        .environmentObject(AppDataStore.preview)
}
#endif
