//
//  AddEntrySheets.swift
//  ChickenPetHealth
//

import SwiftUI

struct AddReminderSheet: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var details = ""
    @State private var dueDate = Date()
    @State private var category: ReminderCategory = .vaccine

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Notes", text: $details, axis: .vertical)
                }
                Section("Schedule") {
                    DatePicker("Due date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    Picker("Category", selection: $category) {
                        ForEach(ReminderCategory.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                }
            }
            .navigationTitle("New reminder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addReminder(title: title, details: details, dueDate: dueDate, category: category)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

struct BirdFormSheet: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    private let birdToEdit: Bird?
    @State private var name: String
    @State private var species: BirdSpecies
    @State private var gender: BirdGender
    @State private var birthDate: Date
    @State private var status: HealthStatus
    @State private var notes: String

    init(birdToEdit: Bird? = nil) {
        self.birdToEdit = birdToEdit
        _name = State(initialValue: birdToEdit?.name ?? "")
        _species = State(initialValue: birdToEdit?.species ?? .chicken)
        _gender = State(initialValue: birdToEdit?.gender ?? .unknown)
        _birthDate = State(initialValue: birdToEdit?.birthDate ?? Date())
        _status = State(initialValue: birdToEdit?.status ?? .healthy)
        _notes = State(initialValue: birdToEdit?.notes ?? "")
    }

    private var isEditing: Bool { birdToEdit != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $name)
                    Picker("Species", selection: $species) {
                        ForEach(BirdSpecies.allCases) { species in
                            Text(species.rawValue).tag(species)
                        }
                    }
                    Picker("Gender", selection: $gender) {
                        ForEach(BirdGender.allCases) { gender in
                            Text(gender.rawValue).tag(gender)
                        }
                    }
                }
                Section("Health") {
                    DatePicker("Birth date", selection: $birthDate, displayedComponents: .date)
                    Picker("Status", selection: $status) {
                        ForEach(HealthStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle(isEditing ? "Edit bird" : "Add bird")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if var existing = birdToEdit {
                            existing.name = name
                            existing.species = species
                            existing.gender = gender
                            existing.birthDate = birthDate
                            existing.status = status
                            existing.notes = notes
                            store.updateBird(existing)
                        } else {
                            store.addBird(
                                name: name,
                                species: species,
                                gender: gender,
                                birthDate: birthDate,
                                notes: notes,
                                status: status
                            )
                        }
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct AddTreatmentSheet: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    private let recordToEdit: TreatmentRecord?
    @State private var title: String
    @State private var category: TreatmentCategory
    @State private var scope: TreatmentScope
    @State private var selectedBirdID: Bird.ID?
    @State private var flockName: String
    @State private var medication: String
    @State private var dosage: String
    @State private var startDate: Date
    @State private var durationDays: Int
    @State private var notes: String

    init(recordToEdit: TreatmentRecord? = nil) {
        self.recordToEdit = recordToEdit
        _title = State(initialValue: recordToEdit?.title ?? "")
        _category = State(initialValue: recordToEdit?.category ?? .medication)
        switch recordToEdit?.target {
        case .bird(let id):
            _scope = State(initialValue: .individual)
            _selectedBirdID = State(initialValue: id)
            _flockName = State(initialValue: "")
        case .flock(let name):
            _scope = State(initialValue: .flock)
            _selectedBirdID = State(initialValue: nil)
            _flockName = State(initialValue: name)
        case .none:
            _scope = State(initialValue: .individual)
            _selectedBirdID = State(initialValue: nil)
            _flockName = State(initialValue: "")
        }
        _medication = State(initialValue: recordToEdit?.medication ?? "")
        _dosage = State(initialValue: recordToEdit?.dosage ?? "")
        _startDate = State(initialValue: recordToEdit?.startDate ?? Date())
        _durationDays = State(initialValue: recordToEdit?.durationDays ?? 1)
        _notes = State(initialValue: recordToEdit?.notes ?? "")
    }

    private var isEditing: Bool { recordToEdit != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Treatment") {
                    TextField("Title", text: $title)
                    Picker("Category", selection: $category) {
                        ForEach(TreatmentCategory.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    Picker("Scope", selection: $scope) {
                        ForEach(TreatmentScope.allCases) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    if scope == .individual {
                        if store.birds.isEmpty {
                            Text("Add a bird first to target an individual.")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            Picker("Bird", selection: $selectedBirdID) {
                                ForEach(store.birds) { bird in
                                    Text(bird.name).tag(Optional(bird.id))
                                }
                            }
                        }
                    } else {
                        TextField("Flock name", text: $flockName)
                    }
                }
                Section("Medication") {
                    TextField("Medication", text: $medication)
                    TextField("Dosage", text: $dosage)
                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                    Stepper("Duration: \(durationDays) day(s)", value: $durationDays, in: 1...60)
                    TextField("Notes", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle(isEditing ? "Edit treatment" : "New treatment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard isFormValid else { return }
                        let target: TreatmentTarget
                        if scope == .individual, let id = selectedBirdID {
                            target = .bird(id)
                        } else {
                            target = .flock(flockName)
                        }

                        if var existing = recordToEdit {
                            existing.title = title
                            existing.category = category
                            existing.target = target
                            existing.medication = medication
                            existing.dosage = dosage
                            existing.startDate = startDate
                            existing.durationDays = durationDays
                            existing.notes = notes
                            store.updateTreatment(existing)
                        } else {
                            store.addTreatment(
                                title: title,
                                target: target,
                                category: category,
                                medication: medication,
                                dosage: dosage,
                                startDate: startDate,
                                durationDays: durationDays,
                                notes: notes
                            )
                        }
                        dismiss()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
        .onAppear {
            if selectedBirdID == nil, scope == .individual {
                selectedBirdID = store.birds.first?.id
            }
        }
        .onChange(of: scope) { _, newScope in
            if newScope == .individual, selectedBirdID == nil {
                selectedBirdID = store.birds.first?.id
            }
        }
    }

    private var isFormValid: Bool {
        guard !title.isEmpty, !medication.isEmpty, !dosage.isEmpty else { return false }
        if scope == .individual {
            return selectedBirdID != nil
        } else {
            return !flockName.isEmpty
        }
    }
}
