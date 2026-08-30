import Combine
import UIKit

@MainActor
final class WorldStore: ObservableObject {
    static let maxCreatures = 10

    @Published private(set) var creatures: [Creature] = []
    @Published private(set) var images: [UUID: UIImage] = [:]
    @Published private(set) var lastSaveFailed = false
    @Published private(set) var skillPulse: SkillPulse?
    @Published var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: Self.soundKey)
        }
    }

    private static let soundKey = "scrawl.soundEnabled"

    func playSkill(_ skill: CreatureSkill, color: UIColor = UIColor(red: 0.96, green: 0.42, blue: 0.58, alpha: 1)) {
        var red: CGFloat = 0.96
        var green: CGFloat = 0.42
        var blue: CGFloat = 0.58
        var alpha: CGFloat = 1
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        skillPulse = SkillPulse(skill: skill, token: UUID(), red: red, green: green, blue: blue)
    }

    init() {
        let enabled: Bool
        if UserDefaults.standard.object(forKey: Self.soundKey) == nil {
            UserDefaults.standard.set(true, forKey: Self.soundKey)
            enabled = true
        } else {
            enabled = UserDefaults.standard.bool(forKey: Self.soundKey)
        }
        let snapshot = Self.readFromDisk()
        _soundEnabled = Published(initialValue: enabled)
        _creatures = Published(initialValue: snapshot.creatures)
        _images = Published(initialValue: snapshot.images)
        _lastSaveFailed = Published(initialValue: false)
    }

    func add(image: UIImage, kind: CreatureKind, hunts: Bool, skills: [CreatureSkill]) {
        var nextCreatures = creatures
        var nextImages = images
        if nextCreatures.count >= Self.maxCreatures {
            let oldest = nextCreatures.removeFirst()
            nextImages.removeValue(forKey: oldest.id)
            deleteImage(named: oldest.fileName)
        }

        let id = UUID()
        let creature = Creature(
            id: id,
            createdAt: Date(),
            fileName: "\(id.uuidString).png",
            kind: kind,
            hunts: hunts,
            skills: skills
        )
        nextImages[id] = image
        nextCreatures.append(creature)
        images = nextImages
        creatures = nextCreatures
        persist(newImage: image, for: creature)
    }

    func remove(id: UUID) {
        guard let index = creatures.firstIndex(where: { $0.id == id }) else { return }
        let removed = creatures.remove(at: index)
        images.removeValue(forKey: id)
        deleteImage(named: removed.fileName)
        persist(newImage: nil, for: nil)
    }

    func clearWorld() {
        let files = creatures.map(\.fileName)
        creatures = []
        images = [:]
        files.forEach { deleteImage(named: $0) }
        persist(newImage: nil, for: nil)
    }

    private static func readFromDisk() -> (creatures: [Creature], images: [UUID: UIImage]) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let data = try? Data(contentsOf: worldURL),
              let file = try? JSONDecoder().decode(WorldFile.self, from: data) else {
            return ([], [:])
        }

        var loaded: [Creature] = []
        var pics: [UUID: UIImage] = [:]
        for item in file.creatures {
            let url = folder.appendingPathComponent(item.fileName)
            guard let image = UIImage(contentsOfFile: url.path) else { continue }
            loaded.append(item)
            pics[item.id] = image
        }
        return (loaded, pics)
    }

    private func persist(newImage: UIImage?, for creature: Creature?) {
        do {
            try FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
            if let creature, let newImage, let data = newImage.pngData() {
                try data.write(to: Self.folder.appendingPathComponent(creature.fileName), options: .atomic)
            }
            let payload = try JSONEncoder().encode(WorldFile(creatures: creatures))
            try payload.write(to: Self.worldURL, options: .atomic)
            if lastSaveFailed {
                lastSaveFailed = false
            }
        } catch {
            if lastSaveFailed == false {
                lastSaveFailed = true
            }
        }
    }

    private static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Scrawl", isDirectory: true)
    }

    private static var worldURL: URL {
        folder.appendingPathComponent("world.json")
    }

    private func deleteImage(named fileName: String) {
        try? FileManager.default.removeItem(at: Self.folder.appendingPathComponent(fileName))
    }
}

struct SkillPulse: Equatable {
    let skill: CreatureSkill
    let token: UUID
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
}
