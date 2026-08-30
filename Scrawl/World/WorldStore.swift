import Combine
import UIKit

@MainActor
final class WorldStore: ObservableObject {
    static let maxCreatures = 10
    static let maxSnapshots = 16

    @Published private(set) var creatures: [Creature] = []
    @Published private(set) var images: [UUID: UIImage] = [:]
    @Published private(set) var snapshots: [PondSnapshot] = []
    @Published private(set) var snapshotThumbs: [UUID: UIImage] = [:]
    @Published private(set) var lastSaveFailed = false
    @Published private(set) var lastSnapshotSavedAt: Date?
    @Published private(set) var nettedFish: [NettedFish] = []
    @Published private(set) var nettedCreatureIds: [UUID] = []
    @Published var isFishing = false
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
        _soundEnabled = Published(initialValue: enabled)
        _creatures = Published(initialValue: [])
        _images = Published(initialValue: [:])
        _lastSaveFailed = Published(initialValue: false)
        Self.migrateLegacyWorldIfNeeded()
        let loaded = Self.loadLibrary()
        _snapshots = Published(initialValue: loaded.snapshots)
        _snapshotThumbs = Published(initialValue: loaded.thumbs)
    }

    var pondHasLife: Bool {
        creatures.isEmpty == false || nettedFish.isEmpty == false || nettedCreatureIds.isEmpty == false
    }

    var canSavePond: Bool { pondHasLife }

    func add(image: UIImage, kind: CreatureKind, hunts: Bool, skills: [CreatureSkill]) {
        var nextCreatures = creatures
        var nextImages = images
        if nextCreatures.count >= Self.maxCreatures {
            let oldest = nextCreatures.removeFirst()
            nextImages.removeValue(forKey: oldest.id)
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
    }

    func remove(id: UUID) {
        guard let index = creatures.firstIndex(where: { $0.id == id }) else { return }
        creatures.remove(at: index)
        images.removeValue(forKey: id)
    }

    func addNetted(_ fish: NettedFish) {
        guard nettedFish.contains(where: { $0.id == fish.id }) == false else { return }
        nettedFish.append(fish)
    }

    func addNettedCreature(id: UUID) {
        guard nettedCreatureIds.contains(id) == false else { return }
        nettedCreatureIds.append(id)
    }

    func clearWorld() {
        creatures = []
        images = [:]
        nettedFish = []
        nettedCreatureIds = []
        isFishing = false
    }

    func saveSnapshot() {
        guard canSavePond else { return }
        do {
            try FileManager.default.createDirectory(at: Self.snapshotsRoot, withIntermediateDirectories: true)
            pruneIfNeeded()
            let id = UUID()
            let savedAt = Date()
            let folder = Self.folder(for: id)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for creature in creatures {
                guard let image = images[creature.id], let data = image.pngData() else { continue }
                try data.write(to: folder.appendingPathComponent(creature.fileName), options: .atomic)
            }
            let payload = try JSONEncoder().encode(
                WorldFile(creatures: creatures, netted: nettedFish, nettedCreatureIds: nettedCreatureIds)
            )
            try payload.write(to: folder.appendingPathComponent("world.json"), options: .atomic)
            let thumbImages = creatures.compactMap { images[$0.id] }
            let thumb: UIImage
            if thumbImages.isEmpty, let fish = nettedFish.first {
                thumb = Self.makeThumb(from: [
                    PondArt.fish(length: fish.length, body: fish.bodyColor, belly: fish.bellyColor, spots: fish.spots)
                ])
            } else {
                thumb = Self.makeThumb(from: thumbImages)
            }
            if let data = thumb.pngData() {
                try data.write(to: folder.appendingPathComponent("thumb.png"), options: .atomic)
            }
            let item = PondSnapshot(
                id: id,
                savedAt: savedAt,
                creatureCount: creatures.count,
                fishCount: nettedFish.count + nettedCreatureIds.count
            )
            snapshots.insert(item, at: 0)
            snapshotThumbs[id] = thumb
            try writeIndex()
            lastSnapshotSavedAt = savedAt
            lastSaveFailed = false
        } catch {
            lastSaveFailed = true
        }
    }

    func loadSnapshot(id: UUID) {
        let folder = Self.folder(for: id)
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("world.json")),
              let file = try? JSONDecoder().decode(WorldFile.self, from: data) else {
            lastSaveFailed = true
            return
        }
        var loaded: [Creature] = []
        var pics: [UUID: UIImage] = [:]
        for item in file.creatures {
            let url = folder.appendingPathComponent(item.fileName)
            guard let image = UIImage(contentsOfFile: url.path) else { continue }
            loaded.append(item)
            pics[item.id] = image
        }
        nettedFish = file.netted
        nettedCreatureIds = file.nettedCreatureIds
        images = pics
        creatures = loaded
        isFishing = false
        lastSaveFailed = false
    }

    func deleteSnapshot(id: UUID) {
        snapshots.removeAll { $0.id == id }
        snapshotThumbs.removeValue(forKey: id)
        try? FileManager.default.removeItem(at: Self.folder(for: id))
        try? writeIndex()
    }

    private func pruneIfNeeded() {
        while snapshots.count >= Self.maxSnapshots, let oldest = snapshots.last {
            deleteSnapshot(id: oldest.id)
        }
    }

    private func writeIndex() throws {
        let payload = try JSONEncoder().encode(SnapshotIndex(items: snapshots))
        try payload.write(to: Self.indexURL, options: .atomic)
    }

    private static func loadLibrary() -> (snapshots: [PondSnapshot], thumbs: [UUID: UIImage]) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let data = try? Data(contentsOf: indexURL),
              let file = try? JSONDecoder().decode(SnapshotIndex.self, from: data) else {
            return ([], [:])
        }
        var thumbs: [UUID: UIImage] = [:]
        var kept: [PondSnapshot] = []
        for item in file.items {
            let world = folder(for: item.id).appendingPathComponent("world.json")
            guard FileManager.default.fileExists(atPath: world.path) else { continue }
            kept.append(item)
            let thumbURL = folder(for: item.id).appendingPathComponent("thumb.png")
            if let thumb = UIImage(contentsOfFile: thumbURL.path) {
                thumbs[item.id] = thumb
            }
        }
        return (kept, thumbs)
    }

    private static func migrateLegacyWorldIfNeeded() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let legacyURL = folder.appendingPathComponent("world.json")
        guard FileManager.default.fileExists(atPath: legacyURL.path) else { return }
        guard let data = try? Data(contentsOf: legacyURL),
              let file = try? JSONDecoder().decode(WorldFile.self, from: data),
              file.creatures.isEmpty == false else {
            try? FileManager.default.removeItem(at: legacyURL)
            return
        }

        var loaded: [Creature] = []
        var pics: [UUID: UIImage] = [:]
        for item in file.creatures {
            let url = folder.appendingPathComponent(item.fileName)
            guard let image = UIImage(contentsOfFile: url.path) else { continue }
            loaded.append(item)
            pics[item.id] = image
        }
        guard loaded.isEmpty == false else {
            try? FileManager.default.removeItem(at: legacyURL)
            return
        }

        let id = UUID()
        let dest = folder(for: id)
        try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        for creature in loaded {
            let from = folder.appendingPathComponent(creature.fileName)
            let to = dest.appendingPathComponent(creature.fileName)
            try? FileManager.default.copyItem(at: from, to: to)
        }
        if let payload = try? JSONEncoder().encode(WorldFile(creatures: loaded)) {
            try? payload.write(to: dest.appendingPathComponent("world.json"), options: .atomic)
        }
        let thumb = makeThumb(from: loaded.compactMap { pics[$0.id] })
        if let thumbData = thumb.pngData() {
            try? thumbData.write(to: dest.appendingPathComponent("thumb.png"), options: .atomic)
        }

        var items = loadLibrary().snapshots
        items.insert(PondSnapshot(id: id, savedAt: Date(), creatureCount: loaded.count, fishCount: 0), at: 0)
        if let payload = try? JSONEncoder().encode(SnapshotIndex(items: items)) {
            try? payload.write(to: indexURL, options: .atomic)
        }

        for creature in loaded {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(creature.fileName))
        }
        try? FileManager.default.removeItem(at: legacyURL)
    }

    private static func makeThumb(from images: [UIImage]) -> UIImage {
        let side: CGFloat = 160
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { ctx in
            UIColor(red: 0.18, green: 0.52, blue: 0.56, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: side, height: side)))
            let tiles = Array(images.prefix(4))
            guard tiles.isEmpty == false else { return }
            if tiles.count == 1 {
                drawFitted(tiles[0], in: CGRect(x: 12, y: 12, width: 136, height: 136))
                return
            }
            let cells = [
                CGRect(x: 8, y: 8, width: 70, height: 70),
                CGRect(x: 82, y: 8, width: 70, height: 70),
                CGRect(x: 8, y: 82, width: 70, height: 70),
                CGRect(x: 82, y: 82, width: 70, height: 70)
            ]
            for (index, image) in tiles.enumerated() {
                drawFitted(image, in: cells[index])
            }
        }
    }

    private static func drawFitted(_ image: UIImage, in rect: CGRect) {
        let size = image.size
        guard size.width > 1, size.height > 1 else { return }
        let scale = min(rect.width / size.width, rect.height / size.height)
        let width = size.width * scale
        let height = size.height * scale
        image.draw(in: CGRect(
            x: rect.midX - width / 2,
            y: rect.midY - height / 2,
            width: width,
            height: height
        ))
    }

    private static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Scrawl", isDirectory: true)
    }

    private static var snapshotsRoot: URL {
        folder.appendingPathComponent("snapshots", isDirectory: true)
    }

    private static var indexURL: URL {
        folder.appendingPathComponent("snapshots.json")
    }

    private static func folder(for id: UUID) -> URL {
        snapshotsRoot.appendingPathComponent(id.uuidString, isDirectory: true)
    }
}

struct PondSnapshot: Codable, Identifiable, Equatable {
    let id: UUID
    let savedAt: Date
    let creatureCount: Int
    let fishCount: Int

    init(id: UUID, savedAt: Date, creatureCount: Int, fishCount: Int) {
        self.id = id
        self.savedAt = savedAt
        self.creatureCount = creatureCount
        self.fishCount = fishCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        creatureCount = try container.decode(Int.self, forKey: .creatureCount)
        fishCount = try container.decodeIfPresent(Int.self, forKey: .fishCount) ?? 0
    }
}

private struct SnapshotIndex: Codable {
    var items: [PondSnapshot]
}

struct SkillPulse: Equatable {
    let skill: CreatureSkill
    let token: UUID
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
}
