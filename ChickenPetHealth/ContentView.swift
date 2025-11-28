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

    var body: some View {
        let activeScheme = store.themeMode.colorScheme ?? colorScheme

        TabView {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            BirdsView()
                .tabItem { Label("Birds", systemImage: "bird.fill") }

            TreatmentLogView()
                .tabItem { Label("Treatment", systemImage: "pills.fill") }

            AnalyticsView()
                .tabItem { Label("Analytics", systemImage: "chart.pie.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Theme.accent)
        .preferredColorScheme(store.themeMode.colorScheme)
        .background(Theme.background(for: activeScheme).ignoresSafeArea())
        .onAppear {
            requestTrackingPermissionIfNeeded()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                requestTrackingPermissionIfNeeded()
            }
        }
    }

    private func requestTrackingPermissionIfNeeded() {
        guard #available(iOS 14, *), ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            ATTrackingManager.requestTrackingAuthorization { _ in }
        }
    }
}

#if DEBUG
#Preview {
    ContentView()
        .environmentObject(AppDataStore.preview)
}
#endif
