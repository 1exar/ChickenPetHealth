//
//  TreatmentLogView.swift
//  ChickenPetHealth
//

import SwiftUI

struct TreatmentLogView: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var filter: TreatmentCategory? = nil
    @State private var expandedTreatmentID: UUID?
    @State private var showAddSheet = false

    private var filteredRecords: [TreatmentRecord] {
        store.treatments.filter { record in
            guard let filter else { return true }
            return record.category == filter
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Filter", selection: $filter) {
                        Text("All").tag(TreatmentCategory?.none)
                        ForEach(TreatmentCategory.allCases) { category in
                            Text(category.rawValue).tag(TreatmentCategory?.some(category))
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(Theme.accent)
                    .colorScheme(.dark) // Keep segment labels white on dark background
                    .listRowBackground(Theme.background(for: colorScheme))
                }
                Text("Records")
                    .font(.headline)
                    .foregroundColor(.white)
                    .listRowBackground(Theme.background(for: colorScheme))
                    .listRowSeparator(.hidden)

                if store.treatments.isEmpty {
                    Text("No treatments yet")
                        .font(.caption)
                        .foregroundColor(Theme.mutedText(for: colorScheme))
                        .listRowBackground(Theme.background(for: colorScheme))
                        .listRowSeparator(.hidden)
                } else if filteredRecords.isEmpty {
                    Text("No entries for this filter")
                        .font(.caption)
                        .foregroundColor(Theme.mutedText(for: colorScheme))
                        .listRowBackground(Theme.background(for: colorScheme))
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(filteredRecords) { record in
                        TreatmentRowView(
                            record: record,
                            isExpanded: expandedTreatmentID == record.id,
                            onToggle: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if expandedTreatmentID == record.id {
                                        expandedTreatmentID = nil
                                    } else {
                                        expandedTreatmentID = record.id
                                    }
                                }
                            },
                            onDelete: {
                                store.deleteTreatment(id: record.id)
                                expandedTreatmentID = nil
                            }
                        )
                        .listRowBackground(Theme.card(for: colorScheme))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background(for: colorScheme))
            .foregroundColor(.white)
            .listStyle(.plain)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                header
                    .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTreatmentSheet()
                .environmentObject(store)
        }
    }

    private var header: some View {
        HStack {
            Text("Treatment log")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            Spacer()
            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(Theme.accent)
                    .padding(6)
                    .background(Circle().stroke(Theme.accent.opacity(0.6), lineWidth: 1))
            }
            .accessibilityLabel("Add treatment")
        }
        .padding(.bottom, 6)
        .background(Theme.background(for: colorScheme).ignoresSafeArea(edges: .top))
    }
}

struct TreatmentRowView: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.colorScheme) private var colorScheme
    let record: TreatmentRecord
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: isExpanded ? 12 : 6) {
                HStack {
                    Text(record.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text(record.category.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 10).fill(tagColor.opacity(0.25)))
                        .foregroundColor(tagColor)
                        .opacity(isExpanded ? 0 : 1)
                }
                Text(store.label(for: record.target))
                    .font(.caption)
                    .foregroundColor(Theme.mutedText(for: colorScheme))
                Text("\(record.medication) • \(record.dosage)")
                    .font(.caption)
                    .foregroundColor(Theme.mutedText(for: colorScheme))
                HStack {
                    Text("Started \(record.startDate, style: .date)")
                    Spacer()
                    Text("\(record.durationDays)-day course")
                }
                .font(.caption2)
                .foregroundColor(Theme.mutedText(for: colorScheme))
                if !record.notes.isEmpty {
                    Text(record.notes)
                        .font(.caption2)
                        .foregroundColor(Theme.mutedText(for: colorScheme))
                }
            }
            .padding(.vertical, 6)
            .foregroundColor(.white)
            .contentShape(Rectangle())
            .onTapGesture {
                if !isExpanded {
                    onToggle()
                }
            }

            if isExpanded {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .padding(6)
                        .background(Circle().fill(Theme.overlay(for: colorScheme)))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                .padding(.top, 8)
                .zIndex(1)
            }
        }
    }

    private var tagColor: Color {
        switch record.category {
        case .vaccine: return .green
        case .medication: return Theme.treatmentBlue
        case .illness: return Theme.warning
        case .prevention: return Theme.accent
        }
    }
}
