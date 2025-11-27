//
//  ContentView.swift
//  ChickenPetHealth
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.colorScheme) private var colorScheme

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
    }
}

#if DEBUG
#Preview {
    ContentView()
        .environmentObject(AppDataStore.preview)
}
#endif
