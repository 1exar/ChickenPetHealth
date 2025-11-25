//
//  SettingsView.swift
//  ChickenPetHealth
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var notificationsEnabled = true
    @State private var selectedSound = "Hen"

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: Binding(get: { store.themeMode }, set: { store.setThemeMode($0) })) {
                        ForEach(AppThemeMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Switch between light, dark, or match device regardless of system settings.")
                        .font(.caption)
                        .foregroundColor(Theme.mutedText(for: colorScheme))
                }
                Section("Notifications") {
                    Toggle("Reminders", isOn: $notificationsEnabled)
                    Button("Grant notification permission") {
                        store.requestNotificationPermission()
                    }
                    Picker("Sound", selection: $selectedSound) {
                        Text("Hen").tag("Hen")
                        Text("Rooster").tag("Rooster")
                        Text("Neutral").tag("Neutral")
                    }
                }
                Section("Knowledge") {
                    Text("Editable medication library lets you store favorite treatments.")
                        .font(.caption)
                    Text("QR tags for cages and sensor API support are planned.")
                        .font(.caption)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background(for: colorScheme))
            .navigationTitle("Settings")
        }
    }
}
