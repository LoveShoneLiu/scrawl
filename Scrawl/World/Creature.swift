import Foundation
import UIKit

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

struct NettedFish: Codable, Equatable, Identifiable {
    let id: UUID
    let length: CGFloat
    let bodyR: CGFloat
    let bodyG: CGFloat
    let bodyB: CGFloat
    let bellyR: CGFloat
    let bellyG: CGFloat
    let bellyB: CGFloat
    let spots: Bool

    var bodyColor: UIColor {
        UIColor(red: bodyR, green: bodyG, blue: bodyB, alpha: 1)
    }

    var bellyColor: UIColor {
        UIColor(red: bellyR, green: bellyG, blue: bellyB, alpha: 1)
    }

    init(id: UUID = UUID(), length: CGFloat, body: UIColor, belly: UIColor, spots: Bool) {
        self.id = id
        self.length = length
        var bodyR: CGFloat = 1, bodyG: CGFloat = 1, bodyB: CGFloat = 1, bodyA: CGFloat = 1
        var bellyR: CGFloat = 1, bellyG: CGFloat = 1, bellyB: CGFloat = 1, bellyA: CGFloat = 1
        body.getRed(&bodyR, green: &bodyG, blue: &bodyB, alpha: &bodyA)
        belly.getRed(&bellyR, green: &bellyG, blue: &bellyB, alpha: &bellyA)
        self.bodyR = bodyR
        self.bodyG = bodyG
        self.bodyB = bodyB
        self.bellyR = bellyR
        self.bellyG = bellyG
        self.bellyB = bellyB
        self.spots = spots
    }
}

struct WorldFile: Codable {
    var creatures: [Creature]
    var netted: [NettedFish]
    var nettedCreatureIds: [UUID]

    init(creatures: [Creature], netted: [NettedFish] = [], nettedCreatureIds: [UUID] = []) {
        self.creatures = creatures
        self.netted = netted
        self.nettedCreatureIds = nettedCreatureIds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        creatures = try container.decodeIfPresent([Creature].self, forKey: .creatures) ?? []
        netted = try container.decodeIfPresent([NettedFish].self, forKey: .netted) ?? []
        nettedCreatureIds = try container.decodeIfPresent([UUID].self, forKey: .nettedCreatureIds) ?? []
    }
}
