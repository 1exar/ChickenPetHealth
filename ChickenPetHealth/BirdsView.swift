//
//  BirdsView.swift
//  ChickenPetHealth
//

import SwiftUI

struct BirdsView: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @State private var selectedSpecies: BirdSpecies?
    @State private var showAddBird = false
    @State private var expandedBirdID: UUID?

    private var filteredBirds: [Bird] {
        store.birds.filter { bird in
            let matchesSearch = searchText.isEmpty ||
                bird.name.localizedCaseInsensitiveContains(searchText) ||
                bird.notes.localizedCaseInsensitiveContains(searchText)
            let matchesSpecies = selectedSpecies == nil || bird.species == selectedSpecies
            return matchesSearch && matchesSpecies
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background(for: colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        header
                        searchField
                        speciesFilterRow
                        if filteredBirds.isEmpty {
                            EmptyStateView(
                                title: "No birds logged",
                                subtitle: "Add your first bird to start tracking health history."
                            )
                            .padding(.vertical, 40)
                        } else {
                            ForEach(filteredBirds) { bird in
                                BirdCardView(
                                    bird: bird,
                                    isExpanded: expandedBirdID == bird.id,
                                    onToggle: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            expandedBirdID = expandedBirdID == bird.id ? nil : bird.id
                                        }
                                    },
                                    onDelete: {
                                        expandedBirdID = nil
                                        store.deleteBird(id: bird.id)
                                    }
                                )
                            }
                        }
                        addBirdButton
                    }
                    .padding()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showAddBird) {
            BirdFormSheet()
                .environmentObject(store)
        }
    }

    private var header: some View {
        HStack {
            Text("Bird Profiles")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            Spacer()
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.mutedText(for: colorScheme))
            TextField("Search a bird", text: $searchText)
                .foregroundColor(.white)
                .tint(Theme.accent)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card(for: colorScheme)))
    }

    private var speciesFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Button {
                    selectedSpecies = nil
                } label: {
                    Text("All species")
                        .font(.caption)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selectedSpecies == nil ? Theme.accent.opacity(0.2) : Theme.background(for: colorScheme).opacity(0.5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(selectedSpecies == nil ? Theme.accent : Color.clear, lineWidth: 1)
                        )
                }
                .foregroundColor(.white)
                ForEach(BirdSpecies.allCases) { species in
                    Button {
                        selectedSpecies = species
                    } label: {
                        Text(species.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(selectedSpecies == species ? Theme.accent.opacity(0.2) : Theme.background(for: colorScheme).opacity(0.5))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(selectedSpecies == species ? Theme.accent : Color.clear, lineWidth: 1)
                            )
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }

    private var addBirdButton: some View {
        Button {
            showAddBird = true
        } label: {
            Label("Add bird", systemImage: "plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(RoundedRectangle(cornerRadius: 18).fill(Theme.accentGradient))
                .foregroundColor(.black)
        }
        .padding(.top, 20)
    }
}

struct BirdCardView: View {
    let bird: Bird
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: isExpanded ? 18 : 12) {
                HStack {
                    Circle()
                        .fill(Theme.background(for: colorScheme).opacity(0.3))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Text(bird.species.emoji)
                                .font(.system(size: 28))
                        )
                    VStack(alignment: .leading) {
                        Text(bird.name)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(bird.shortDescription)
                            .font(.caption)
                            .foregroundColor(Theme.mutedText(for: colorScheme))
                    }
                    Spacer()
                    StatusBadge(status: bird.status)
                        .opacity(isExpanded ? 0 : 1)
                }
                if !bird.notes.isEmpty {
                    Text(bird.notes)
                        .font(.caption)
                        .foregroundColor(Theme.mutedText(for: colorScheme))
                }
                HStack {
                    Tag(label: "Health history")
                    Tag(label: "Vaccination log")
                    Tag(label: "Medical notes")
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 24).fill(Theme.card(for: colorScheme)))
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
                .padding(.top, 10)
                .padding(.trailing, 10)
                .zIndex(1)
            }
        }
    }
}
