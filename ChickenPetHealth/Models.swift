//
//  Models.swift
//  ChickenPetHealth
//

import Foundation

enum BirdSpecies: String, CaseIterable, Identifiable, Codable {
    case chicken = "Chicken"
    case duck = "Duck"
    case goose = "Goose"
    case turkey = "Turkey"
    case quail = "Quail"

    var id: String { rawValue }
    var emoji: String {
        switch self {
        case .chicken: return "🐔"
        case .duck: return "🦆"
        case .goose: return "🪿"
        case .turkey: return "🦃"
        case .quail: return "🐥"
        }
    }
}

enum BirdGender: String, CaseIterable, Identifiable, Codable {
    case female = "Female"
    case male = "Male"
    case unknown = "Unknown"

    var id: String { rawValue }
}

enum HealthStatus: String, CaseIterable, Identifiable, Codable {
    case healthy = "Healthy"
    case monitoring = "Under Observation"
    case sick = "Needs Care"

    var id: String { rawValue }
}

struct Bird: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var species: BirdSpecies
    var gender: BirdGender
    var birthDate: Date
    var notes: String
    var status: HealthStatus

    init(
        id: UUID = UUID(),
        name: String,
        species: BirdSpecies,
        gender: BirdGender = .unknown,
        birthDate: Date,
        notes: String = "",
        status: HealthStatus = .healthy
    ) {
        self.id = id
        self.name = name
        self.species = species
        self.gender = gender
        self.birthDate = birthDate
        self.notes = notes
        self.status = status
    }

    var ageInMonths: Int {
        Calendar.current.dateComponents([.month], from: birthDate, to: .now).month ?? 0
    }

    var shortDescription: String {
        "\(species.rawValue) · \(ageInMonths) mo"
    }
}

enum ReminderCategory: String, CaseIterable, Identifiable, Codable {
    case vaccine = "Vaccine"
    case medication = "Medication"
    case checkup = "Health Check"
    case course = "Treatment Course"

    var id: String { rawValue }
}

struct Reminder: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var details: String
    var dueDate: Date
    var category: ReminderCategory
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        title: String,
        details: String,
        dueDate: Date,
        category: ReminderCategory,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.dueDate = dueDate
        self.category = category
        self.isCompleted = isCompleted
    }
}

enum TreatmentCategory: String, CaseIterable, Identifiable, Codable {
    case vaccine = "Vaccine"
    case medication = "Medication"
    case illness = "Illness"
    case prevention = "Prevention"

    var id: String { rawValue }
}

enum TreatmentScope: String, CaseIterable, Identifiable, Codable {
    case individual = "Single Bird"
    case flock = "Flock"

    var id: String { rawValue }
}

enum TreatmentTarget: Hashable, Codable {
    case bird(UUID)
    case flock(String)

    private enum CodingKeys: String, CodingKey {
        case type
        case birdID
        case flockName
    }

    private enum TargetType: String, Codable {
        case bird
        case flock
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(TargetType.self, forKey: .type)
        switch type {
        case .bird:
            let id = try container.decode(UUID.self, forKey: .birdID)
            self = .bird(id)
        case .flock:
            let name = try container.decode(String.self, forKey: .flockName)
            self = .flock(name)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .bird(let id):
            try container.encode(TargetType.bird, forKey: .type)
            try container.encode(id, forKey: .birdID)
        case .flock(let name):
            try container.encode(TargetType.flock, forKey: .type)
            try container.encode(name, forKey: .flockName)
        }
    }
}

struct TreatmentRecord: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var target: TreatmentTarget
    var category: TreatmentCategory
    var medication: String
    var dosage: String
    var startDate: Date
    var durationDays: Int
    var notes: String

    init(
        id: UUID = UUID(),
        title: String,
        target: TreatmentTarget,
        category: TreatmentCategory,
        medication: String,
        dosage: String,
        startDate: Date,
        durationDays: Int,
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.target = target
        self.category = category
        self.medication = medication
        self.dosage = dosage
        self.startDate = startDate
        self.durationDays = durationDays
        self.notes = notes
    }
}
