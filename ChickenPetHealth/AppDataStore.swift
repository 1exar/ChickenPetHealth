//
//  AppDataStore.swift
//  ChickenPetHealth
//

import SwiftUI
import Combine

private struct PersistedState: Codable {
    var birds: [Bird]
    var reminders: [Reminder]
    var treatments: [TreatmentRecord]
}

final class AppDataStore: ObservableObject {
    @Published private(set) var birds: [Bird] = []
    @Published private(set) var reminders: [Reminder] = []
    @Published private(set) var treatments: [TreatmentRecord] = []
    @Published var themeMode: AppThemeMode = .system

    private let notificationScheduler = NotificationScheduler()
    private let persistenceURL: URL = {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return directory.appendingPathComponent("ChickenPetHealthData.json")
    }()
    private let persistenceQueue = DispatchQueue(label: "com.chickenpethealth.persistence", qos: .background)

    init() {
        loadPersistedData()
    }

    func setThemeMode(_ mode: AppThemeMode) {
        themeMode = mode
    }

    func requestNotificationPermission() {
        notificationScheduler.requestAuthorization()
    }

    func addBird(
        name: String,
        species: BirdSpecies,
        gender: BirdGender,
        birthDate: Date,
        notes: String,
        status: HealthStatus
    ) {
        let newBird = Bird(name: name, species: species, gender: gender, birthDate: birthDate, notes: notes, status: status)
        birds.append(newBird)
        persistData()
    }

    func addReminder(title: String, details: String, dueDate: Date, category: ReminderCategory) {
        let reminder = Reminder(title: title, details: details, dueDate: dueDate, category: category)
        reminders.append(reminder)
        reminders.sort { $0.dueDate < $1.dueDate }
        notificationScheduler.schedule(reminder: reminder)
        persistData()
    }

    func toggleReminderCompletion(id: UUID) {
        guard let index = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[index].isCompleted.toggle()
        if reminders[index].isCompleted {
            notificationScheduler.cancel(reminderID: reminders[index].id)
        }
        persistData()
    }

    func deleteReminder(id: UUID) {
        reminders.removeAll { reminder in
            if reminder.id == id {
                notificationScheduler.cancel(reminderID: reminder.id)
                return true
            }
            return false
        }
        persistData()
    }

    func updateBird(_ bird: Bird) {
        guard let index = birds.firstIndex(where: { $0.id == bird.id }) else { return }
        birds[index] = bird
        persistData()
    }

    func deleteBird(id: UUID) {
        birds.removeAll { $0.id == id }
        persistData()
    }

    func addTreatment(
        title: String,
        target: TreatmentTarget,
        category: TreatmentCategory,
        medication: String,
        dosage: String,
        startDate: Date,
        durationDays: Int,
        notes: String
    ) {
        let record = TreatmentRecord(
            title: title,
            target: target,
            category: category,
            medication: medication,
            dosage: dosage,
            startDate: startDate,
            durationDays: durationDays,
            notes: notes
        )
        treatments.append(record)
        persistData()
    }

    func deleteTreatment(id: UUID) {
        treatments.removeAll { $0.id == id }
        persistData()
    }

    func updateTreatment(_ record: TreatmentRecord) {
        guard let index = treatments.firstIndex(where: { $0.id == record.id }) else { return }
        treatments[index] = record
        persistData()
    }

    func label(for target: TreatmentTarget) -> String {
        switch target {
        case .bird(let id):
            return birds.first(where: { $0.id == id })?.name ?? "Bird"
        case .flock(let name):
            return name.isEmpty ? "Flock" : name
        }
    }
}

#if DEBUG
extension AppDataStore {
    static var preview: AppDataStore {
        let store = AppDataStore()
        store.addBird(name: "Willow", species: .chicken, gender: .female, birthDate: Calendar.current.date(byAdding: .month, value: -15, to: .now) ?? .now, notes: "Calm layer", status: .healthy)
        store.addBird(name: "River", species: .duck, gender: .female, birthDate: Calendar.current.date(byAdding: .month, value: -10, to: .now) ?? .now, notes: "Enjoys pond time", status: .monitoring)
        store.addReminder(title: "Newcastle Vaccine", details: "Apply to all chickens", dueDate: .now.addingTimeInterval(3600 * 5), category: .vaccine)
        store.addReminder(title: "Check River", details: "Monitor appetite", dueDate: .now.addingTimeInterval(3600 * 12), category: .checkup)
        if let birdId = store.birds.first?.id {
            store.addTreatment(
                title: "Vitamin D Boost",
                target: .bird(birdId),
                category: .prevention,
                medication: "Vit D",
                dosage: "3 ml",
                startDate: .now.addingTimeInterval(-3600 * 48),
                durationDays: 7,
                notes: "Repeat weekly"
            )
        }
        return store
    }
}
#endif

private extension AppDataStore {
    func loadPersistedData() {
        guard FileManager.default.fileExists(atPath: persistenceURL.path) else { return }
        do {
            let data = try Data(contentsOf: persistenceURL)
            let decoded = try JSONDecoder().decode(PersistedState.self, from: data)
            birds = decoded.birds
            reminders = decoded.reminders
            treatments = decoded.treatments
        } catch {
            print("Failed to load data: \(error.localizedDescription)")
        }
    }

    func persistData() {
        let snapshot = PersistedState(birds: birds, reminders: reminders, treatments: treatments)
        let url = persistenceURL
        persistenceQueue.async { [snapshot, url] in
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                print("Failed to save data: \(error.localizedDescription)")
            }
        }
    }
}
