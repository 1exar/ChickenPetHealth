//
//  AnalyticsView.swift
//  ChickenPetHealth
//

import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    healthPieCard
                    proceduresCard
                    insightsCard
                }
                .padding()
            }
            .background(Theme.background(for: colorScheme))
            .navigationTitle("Analytics")
        }
    }

    private var healthPieCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health distribution")
                .font(.headline)
            HStack {
                DoughnutChart(slices: healthSlices, size: 60)
                    .padding(.trailing, 12)
                VStack(alignment: .leading, spacing: 8) {
                    legendRow(color: .green, label: "Healthy", value: healthyCount)
                    legendRow(color: .yellow, label: "Observing", value: monitoringCount)
                    legendRow(color: Theme.warning, label: "Needs care", value: sickCount)
                    Text("\(store.birds.count) birds total")
                        .font(.caption)
                        .foregroundColor(Theme.mutedText(for: colorScheme))
                }
                Spacer()
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 24).fill(Theme.card(for: colorScheme)))
    }

    private var proceduresCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Care procedures")
                    .font(.headline)
            }
            ForEach(TreatmentCategory.allCases) { category in
                let value = store.treatments.filter { $0.category == category }.count
                HStack {
                    Text(category.rawValue)
                    Spacer()
                    Text("\(value)")
                        .font(.headline)
                }
                ProgressView(value: store.treatments.isEmpty ? 0 : Double(value) / Double(max(1, store.treatments.count)))
                    .tint(color(for: category))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 24).fill(Theme.card(for: colorScheme)))
    }

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Assistant insights")
                .font(.headline)
            Text(summaryText)
                .font(.footnote)
                .foregroundColor(Theme.mutedText(for: colorScheme))
            Text(nextStepText)
                .font(.footnote)
                .foregroundColor(Theme.accent)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 24).fill(Theme.card(for: colorScheme)))
    }

    private func legendRow(color: Color, label: String, value: Int) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption)
            Spacer()
            Text("\(value)")
                .font(.caption.bold())
        }
    }

    private var healthyCount: Int { store.birds.filter { $0.status == .healthy }.count }
    private var monitoringCount: Int { store.birds.filter { $0.status == .monitoring }.count }
    private var sickCount: Int { store.birds.filter { $0.status == .sick }.count }

    private var healthSlices: [DoughnutSlice] {
        let total = max(1, store.birds.count)
        return [
            DoughnutSlice(value: Double(healthyCount) / Double(total), color: .green),
            DoughnutSlice(value: Double(monitoringCount) / Double(total), color: .yellow),
            DoughnutSlice(value: Double(sickCount) / Double(total), color: Theme.warning)
        ]
    }

    private func color(for category: TreatmentCategory) -> Color {
        switch category {
        case .vaccine: return .green
        case .medication: return Theme.treatmentBlue
        case .illness: return Theme.warning
        case .prevention: return Theme.accent
        }
    }

    private var summaryText: String {
        if sickCount > monitoringCount + healthyCount {
            return "More birds need care than are healthy. Prioritize vet visits and review medication plans."
        } else if healthyCount == store.birds.count {
            return "All birds are marked healthy. Keep routines to maintain current streak."
        } else {
            return "A few birds are under observation. Review notes and set reminders for follow-up checks."
        }
    }

    private var nextStepText: String {
        if store.reminders.isEmpty {
            return "Set reminders for upcoming vaccines to keep immunity on track."
        } else {
            return "You have \(store.reminders.count) scheduled reminders. Tap any card to mark it done."
        }
    }
}

struct DoughnutSlice: Identifiable {
    let id = UUID()
    let value: Double
    let color: Color
}

struct DoughnutChart: View {
    let slices: [DoughnutSlice]
    var size: CGFloat = 160
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ForEach(Array(slices.enumerated()), id: \.offset) { index, slice in
                Circle()
                    .trim(from: startAngle(for: index), to: endAngle(for: index))
                    .stroke(slice.color, lineWidth: 16)
                    .rotationEffect(.degrees(-90))
            }
            Circle()
                .fill(Theme.background(for: colorScheme))
                .frame(width: size * 0.45, height: size * 0.45)
            Image(systemName: "stethoscope")
                .foregroundColor(Theme.accent)
        }
        .frame(width: size, height: size)
    }

    private func startAngle(for index: Int) -> CGFloat {
        CGFloat(cumulativeValue(upTo: index))
    }

    private func endAngle(for index: Int) -> CGFloat {
        CGFloat(cumulativeValue(upTo: index + 1))
    }

    private func cumulativeValue(upTo index: Int) -> Double {
        slices.prefix(index).reduce(0) { $0 + $1.value }
    }
}
