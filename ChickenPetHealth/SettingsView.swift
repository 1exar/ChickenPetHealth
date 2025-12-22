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
        let scheme: ColorScheme = store.themeMode.colorScheme ?? colorScheme
        let bg = Theme.background(for: scheme)
        let card = Theme.card(for: scheme)

        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()

                VStack(spacing: 16) {
                    header
                        .frame(maxWidth: .infinity, alignment: .center)

                    Form {
                        Section("Appearance") {
                            Picker("Theme", selection: Binding(get: { store.themeMode }, set: { store.setThemeMode($0) })) {
                                ForEach(AppThemeMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .colorScheme(.dark)
                            Text("Switch between light, dark, or match device regardless of system settings.")
                                .font(.caption)
                                .foregroundColor(Theme.mutedText(for: scheme))
                        }
                        .foregroundColor(.white)
                        .listRowBackground(card)

                        Section("Notifications") {
                            Toggle(isOn: $notificationsEnabled) {
                                Text("Reminders").foregroundColor(.white)
                            }
                            Button {
                                store.requestNotificationPermission()
                            } label: {
                                Text("Grant notification permission").foregroundColor(.white)
                            }
                            Picker("Sound", selection: $selectedSound) {
                                Text("Hen").tag("Hen")
                                Text("Rooster").tag("Rooster")
                                Text("Neutral").tag("Neutral")
                            }
                            .colorScheme(.dark)
                            .foregroundColor(.white)
                            .tint(Theme.accent)
                        }
                        .listRowBackground(card)

                        Section("Knowledge") {
                            Text("Editable medication library lets you store favorite treatments.")
                                .font(.caption)
                                .foregroundColor(Theme.mutedText(for: scheme))
                            Text("QR tags for cages and sensor API support are planned.")
                                .font(.caption)
                                .foregroundColor(Theme.mutedText(for: scheme))
                        }
                        .foregroundColor(.white)
                        .listRowBackground(card)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: 540)
                    .fixedSize(horizontal: false, vertical: true)
                    .scrollContentBackground(.hidden)
                    .scrollDisabled(true)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .environment(\.colorScheme, scheme)
            .preferredColorScheme(scheme)
            .tint(Theme.accent)
            .toolbar(.hidden, for: .navigationBar)
        }
        .environment(\.colorScheme, scheme)
        .preferredColorScheme(scheme)
    }

    private var header: some View {
        HStack {
            Text("Settings")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
        }
    }
}
