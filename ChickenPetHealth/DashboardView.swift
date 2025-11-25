//
//  DashboardView.swift
//  ChickenPetHealth
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showReminderSheet = false
    @State private var showTreatmentSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    greetingCard
                    remindersCard
                    quickAddCard
                    flockStatusCard
                }
                .padding()
            }
            .background(Theme.background(for: colorScheme))
            .navigationTitle("Flock Health")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showReminderSheet = true
                    } label: {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(Theme.accent)
                    }
                    .accessibilityLabel("Add reminder")
                }
            }
        }
        .sheet(isPresented: $showReminderSheet) {
            AddReminderSheet()
                .environmentObject(store)
        }
        .sheet(isPresented: $showTreatmentSheet) {
            AddTreatmentSheet()
                .environmentObject(store)
        }
    }

    private var greetingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.reminders.isEmpty ? "All calm in the coop 🕊" : "You have \(store.reminders.count) reminders today")
                .font(.title2.bold())
            Text("Keep logging care events to maintain a happy flock.")
                .font(.callout)
                .foregroundColor(Theme.mutedText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Theme.card(for: colorScheme))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.05), radius: 10, x: 0, y: 8)
        )
    }

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reminders")
                    .font(.headline)
                Spacer()
                Text(Date.now, style: .date)
                    .font(.caption)
                    .foregroundColor(Theme.mutedText(for: colorScheme))
            }
            if store.reminders.isEmpty {
                EmptyStateView(
                    title: "No reminders yet",
                    subtitle: "Log a vaccine, medication, or wellness check to receive timely nudges."
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(store.reminders) { reminder in
                        ReminderRow(
                            reminder: reminder,
                            onToggle: { store.toggleReminderCompletion(id: reminder.id) },
                            onDelete: { store.deleteReminder(id: reminder.id) }
                        )
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 24).fill(Theme.card(for: colorScheme)))
    }

    private var quickAddCard: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                Text("Quick action")
                    .font(.subheadline)
                    .foregroundColor(Theme.mutedText(for: colorScheme))
                Text("Log vaccine, illness, or medication in two taps.")
                    .font(.footnote)
                    .foregroundColor(Theme.mutedText(for: colorScheme))
            }
            Spacer()
            Menu {
                Button("Record reminder", systemImage: "bell") {
                    showReminderSheet = true
                }
                Button("Log treatment", systemImage: "pills.fill") {
                    showTreatmentSheet = true
                }
            } label: {
                Image(systemName: "plus")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding()
                    .background(Circle().fill(Theme.accentGradient))
                    .shadow(radius: 8)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).stroke(Theme.accent, lineWidth: colorScheme == .dark ? 1 : 0.6))
    }

    private var flockStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Flock status")
                    .font(.headline)
                Spacer()
                Text(colorLabel)
                    .font(.caption)
                    .foregroundColor(Theme.accent)
            }
            HStack(spacing: 12) {
                statusTile(title: "Healthy", value: healthyCount, tint: .green)
                statusTile(title: "Observing", value: monitoringCount, tint: .yellow)
                statusTile(title: "Needs care", value: sickCount, tint: Theme.warning)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 24).fill(Theme.card(for: colorScheme)))
    }

    private func statusTile(title: String, value: Int, tint: Color) -> some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.mutedText(for: colorScheme))
            Text("\(value)")
                .font(.title3.bold())
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(tint.opacity(0.18)))
    }

    private var healthyCount: Int {
        store.birds.filter { $0.status == .healthy }.count
    }

    private var monitoringCount: Int {
        store.birds.filter { $0.status == .monitoring }.count
    }

    private var sickCount: Int {
        store.birds.filter { $0.status == .sick }.count
    }

    private var colorLabel: String {
        if sickCount > 0 {
            return "Status color: red"
        } else if monitoringCount > 0 {
            return "Status color: amber"
        } else {
            return "Status color: green"
        }
    }
}

struct ReminderRow: View {
    let reminder: Reminder
    let onToggle: () -> Void
    let onDelete: () -> Void
    @State private var pulse = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.subheadline.bold())
                Text("\(reminder.details)")
                    .font(.caption)
                    .foregroundColor(Theme.mutedText(for: colorScheme))
                Text(reminder.dueDate, style: .time)
                    .font(.caption2)
                    .foregroundColor(Theme.mutedText(for: colorScheme))
            }
            Spacer()
            Button(action: onToggle) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(reminder.isCompleted ? .green : Theme.accent)
            }
            .buttonStyle(.plain)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .padding(8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.overlay(for: colorScheme))
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(reminder.isCompleted ? .green.opacity(0.25) : Theme.accent.opacity(0.3))
                .frame(width: 12, height: 12)
                .offset(x: -10, y: 10)
                .scaleEffect(pulse ? 1.6 : 0.8)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
        }
        .onAppear { pulse = true }
    }
}
