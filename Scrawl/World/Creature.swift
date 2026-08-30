import Foundation

enum CreatureSkill: String, Codable, CaseIterable, Identifiable {
    case dash
    case jump
    case glow
    case bubbles
    case fish
    case eat
    case shield
    case scare

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .dash: return "bolt.fill"
        case .jump: return "arrow.up"
        case .glow: return "sparkles"
        case .bubbles: return "water.waves"
        case .fish: return "fish.fill"
        case .eat: return "mouth.fill"
        case .shield: return "shield.fill"
        case .scare: return "wind"
        }
    }

    var isBurst: Bool {
        switch self {
        case .eat, .shield: return false
        default: return true
        }
    }

    var isKidPlay: Bool {
        switch self {
        case .dash, .jump, .glow, .bubbles, .fish: return true
        default: return false
        }
    }
}

struct Creature: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let fileName: String
    var kind: CreatureKind
    var hunts: Bool
    var skills: [CreatureSkill]

    enum CodingKeys: String, CodingKey {
        case id, createdAt, fileName, kind, hunts, skills
    }

    init(id: UUID, createdAt: Date, fileName: String, kind: CreatureKind, hunts: Bool, skills: [CreatureSkill]) {
        self.id = id
        self.createdAt = createdAt
        self.fileName = fileName
        self.kind = kind
        self.hunts = hunts
        self.skills = skills
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        fileName = try container.decode(String.self, forKey: .fileName)
        kind = try container.decodeIfPresent(CreatureKind.self, forKey: .kind) ?? .doodle
        hunts = try container.decodeIfPresent(Bool.self, forKey: .hunts) ?? false
        skills = try container.decodeIfPresent([CreatureSkill].self, forKey: .skills) ?? []
    }
}

struct WorldFile: Codable {
    var creatures: [Creature]
}
