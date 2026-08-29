import SpriteKit
import UIKit

final class PondFish: SKSpriteNode {
    var velocity = CGVector.zero
    var cooldown: CGFloat = 0
}

final class PondActor: SKSpriteNode {
    var creatureId = UUID()
    var kind: CreatureKind = .doodle
    var hunts = false
    var skills: [CreatureSkill] = []
    var velocity = CGVector.zero
    var eatCooldown: CGFloat = 0
    var skillCooldown: CGFloat = 0
    var dashBoost: CGFloat = 0
    var tangled: CGFloat = 0
    var tangleImmune: CGFloat = 0
    var grazeCooldown: CGFloat = 0
    var beingEaten = false
    var ready = false
    var casting = false

    var isHunter: Bool { kind != .grass && (hunts || skills.contains(.eat)) }
    var isShielded: Bool { skills.contains(.shield) }
    var swims: Bool {
        switch kind {
        case .grass: return false
        case .doodle: return true
        default: return true
        }
    }
}

final class PondScene: SKScene {
    var onTapCreature: (() -> Void)?
    var onFishBump: (() -> Void)?
    var onCreatureEaten: ((UUID) -> Void)?
    var onEat: (() -> Void)?
    var onSkill: (() -> Void)?

    private var actors: [UUID: PondActor] = [:]
    private var leaving = Set<UUID>()
    private var fishes: [PondFish] = []
    private var lastTime: TimeInterval = 0
    private var bubbleTimer: CGFloat = 0
    private var lastBuiltSize: CGSize = .zero

    func sync(creatures: [Creature], images: [UUID: UIImage]) {
        let ids = Set(creatures.map(\.id))
        for (id, node) in actors where !ids.contains(id) && leaving.contains(id) == false {
            leave(id: id, node: node)
        }
        for creature in creatures {
            guard actors[creature.id] == nil, leaving.contains(creature.id) == false else { continue }
            guard let image = images[creature.id] else { continue }
            enter(creature: creature, image: image)
        }
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.10, green: 0.36, blue: 0.42, alpha: 1)
        view.allowsTransparency = false
        view.isMultipleTouchEnabled = true
        rebuildIfNeeded()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        rebuildIfNeeded()
    }

    override func update(_ currentTime: TimeInterval) {
        if lastTime == 0 { lastTime = currentTime }
        let dt = CGFloat(min(currentTime - lastTime, 1.0 / 30.0))
        lastTime = currentTime

        bubbleTimer += dt
        if bubbleTimer > 0.9 {
            bubbleTimer = 0
            spawnBubble()
        }

        for fish in fishes {
            fish.cooldown = max(0, fish.cooldown - dt)
            var position = fish.position
            position.x += fish.velocity.dx * dt
            position.y += fish.velocity.dy * dt

            let margin: CGFloat = 36
            if position.x < margin { fish.velocity.dx = abs(fish.velocity.dx); position.x = margin }
            if position.x > size.width - margin { fish.velocity.dx = -abs(fish.velocity.dx); position.x = size.width - margin }
            if position.y < margin { fish.velocity.dy = abs(fish.velocity.dy); position.y = margin }
            if position.y > size.height - margin { fish.velocity.dy = -abs(fish.velocity.dy); position.y = size.height - margin }

            if Int.random(in: 0...180) == 0 {
                fish.velocity.dx += CGFloat.random(in: -18...18)
                fish.velocity.dy += CGFloat.random(in: -12...12)
                let speed = hypot(fish.velocity.dx, fish.velocity.dy)
                let target = CGFloat.random(in: 28...62)
                if speed > 1 {
                    fish.velocity.dx = fish.velocity.dx / speed * target
                    fish.velocity.dy = fish.velocity.dy / speed * target
                }
            }

            fish.position = position
            fish.zRotation = atan2(fish.velocity.dy, fish.velocity.dx)
        }

        moveActors(dt: dt)
        tickHabitat(dt: dt)
        resolveFishDoodleBumps()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let hit = nodes(at: location)
            .compactMap { $0 as? PondActor }
            .first { $0.beingEaten == false }
        guard let node = hit else { return }
        bounce(node)
        splash(at: node.position, big: false)
        onTapCreature?()
    }

    func playSkill(_ skill: CreatureSkill) {
        let targets = actors.values.filter { $0.ready && $0.beingEaten == false }
        if targets.isEmpty {
            splash(at: CGPoint(x: size.width * 0.5, y: size.height * 0.5), big: true)
            onSkill?()
            return
        }
        for actor in targets {
            castSkills(on: actor, picked: [skill])
        }
        onSkill?()
    }

    private func resolveFishDoodleBumps() {
        let doodles = actors.values.filter { $0.kind == .doodle && $0.beingEaten == false && $0.isHunter == false }
        for fish in fishes where fish.cooldown <= 0 {
            for doodle in doodles {
                let dx = fish.position.x - doodle.position.x
                let dy = fish.position.y - doodle.position.y
                let limit = max(36, (fish.size.width + doodle.size.width) * 0.28)
                if hypot(dx, dy) < limit {
                    fish.cooldown = 1.7
                    bump(fish: fish, doodle: doodle)
                    break
                }
            }
        }
    }

    private func moveActors(dt: CGFloat) {
        let margin: CGFloat = 40
        for actor in actors.values where actor.swims && actor.beingEaten == false && actor.casting == false && actor.ready && actor.tangled <= 0 {
            actor.eatCooldown = max(0, actor.eatCooldown - dt)
            if actor.kind.blockedByWeeds, inWeeds(actor.position) {
                actor.velocity.dy += 55 * dt
                if actor.position.y < size.height * 0.35 {
                    actor.velocity.dy += 30 * dt
                }
            } else if actor.kind == .crab, actor.position.y > size.height * 0.42 {
                actor.velocity.dy -= 28 * dt
            } else if Int.random(in: 0...90) == 0 {
                actor.velocity.dx += CGFloat.random(in: -20...20)
                actor.velocity.dy += CGFloat.random(in: -14...14)
            }

            var speed = hypot(actor.velocity.dx, actor.velocity.dy)
            let boost: CGFloat = 1 + actor.dashBoost * 1.8
            actor.dashBoost = max(0, actor.dashBoost - dt * 1.2)
            let target = (actor.isHunter ? CGFloat.random(in: 48...78) : CGFloat.random(in: 28...52)) * boost
            if speed < 12 {
                actor.velocity.dx = 24
                speed = 24
            }
            if speed > 1 {
                let cap: CGFloat = (actor.isHunter ? 86 : 58) * boost
                let scale = min(cap, max(18, speed > cap ? cap : speed)) / speed
                if Int.random(in: 0...40) == 0 {
                    actor.velocity.dx = actor.velocity.dx / speed * target
                    actor.velocity.dy = actor.velocity.dy / speed * target
                } else if speed > cap {
                    actor.velocity.dx *= scale
                    actor.velocity.dy *= scale
                }
            }

            var position = actor.position
            position.x += actor.velocity.dx * dt
            position.y += actor.velocity.dy * dt
            if position.x < margin { actor.velocity.dx = abs(actor.velocity.dx); position.x = margin }
            if position.x > size.width - margin { actor.velocity.dx = -abs(actor.velocity.dx); position.x = size.width - margin }
            if position.y < margin { actor.velocity.dy = abs(actor.velocity.dy); position.y = margin }
            if position.y > size.height - margin { actor.velocity.dy = -abs(actor.velocity.dy); position.y = size.height - margin }
            actor.position = position
            if actor.kind != .crab {
                actor.zRotation = atan2(actor.velocity.dy, actor.velocity.dx)
            }
        }
    }

    private func nearestPrey(for hunter: PondActor) -> PondActor? {
        actors.values
            .filter { prey in
                prey.creatureId != hunter.creatureId
                    && prey.beingEaten == false
                    && prey.isShielded == false
                    && hunter.kind.canEat(prey.kind)
                    && (hunter.kind.blockedByWeeds == false || inWeeds(prey.position) == false)
            }
            .min { hypot($0.position.x - hunter.position.x, $0.position.y - hunter.position.y)
                < hypot($1.position.x - hunter.position.x, $1.position.y - hunter.position.y) }
    }

    private func resolveEating() {
        let hunters = actors.values.filter {
            $0.isHunter && $0.beingEaten == false && $0.eatCooldown <= 0 && $0.ready && $0.casting == false && $0.tangled <= 0
        }
        for hunter in hunters {
            if hunter.kind.blockedByWeeds, inWeeds(hunter.position) {
                continue
            }
            if let prey = nearestPrey(for: hunter) {
                let limit = max(28, (hunter.size.width + prey.size.width) * 0.3)
                let dist = hypot(hunter.position.x - prey.position.x, hunter.position.y - prey.position.y)
                if dist < limit {
                    gulp(hunter: hunter, prey: prey)
                    continue
                }
            }
            guard hunter.kind.eatsDecorFish else { continue }
            for fish in fishes {
                let limit = max(30, hunter.size.width * 0.38)
                let dist = hypot(hunter.position.x - fish.position.x, hunter.position.y - fish.position.y)
                if dist < limit {
                    gulpDecor(hunter: hunter, fish: fish)
                    break
                }
            }
        }
    }

    private func gulp(hunter: PondActor, prey: PondActor) {
        prey.beingEaten = true
        hunter.eatCooldown = 1.3
        leaving.insert(prey.creatureId)
        actors[prey.creatureId] = nil
        prey.removeAllActions()
        splash(at: prey.position, big: true)
        sparkles(at: prey.position)
        hunter.run(SKAction.sequence([
            SKAction.scale(to: 1.28, duration: 0.12),
            SKAction.scale(to: 1.0, duration: 0.18)
        ]))
        prey.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 0.05, duration: 0.28),
                SKAction.fadeOut(withDuration: 0.28),
                SKAction.move(to: hunter.position, duration: 0.28)
            ]),
            SKAction.removeFromParent()
        ])) { [weak self] in
            self?.leaving.remove(prey.creatureId)
        }
        onEat?()
        onCreatureEaten?(prey.creatureId)
    }

    private func tickHabitat(dt: CGFloat) {
        for actor in actors.values where actor.ready && actor.beingEaten == false {
            actor.tangleImmune = max(0, actor.tangleImmune - dt)
            actor.grazeCooldown = max(0, actor.grazeCooldown - dt)
            if actor.tangled > 0 {
                actor.tangled -= dt
                if actor.tangled <= 0 {
                    actor.tangleImmune = 2.4
                    actor.removeAction(forKey: "tangle")
                }
                continue
            }
            if actor.kind.trappedByWeeds, actor.tangleImmune <= 0, inWeeds(actor.position) {
                tangle(actor)
                continue
            }
            if actor.kind.grazes, actor.grazeCooldown <= 0, inWeeds(actor.position) {
                graze(actor)
            }
        }
    }

    private func tangle(_ actor: PondActor) {
        actor.tangled = 3.6
        actor.velocity = .zero
        actor.removeAction(forKey: "wander")
        actor.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.rotate(toAngle: 0.28, duration: 0.14, shortestUnitArc: true),
            SKAction.rotate(toAngle: -0.28, duration: 0.14, shortestUnitArc: true)
        ])), withKey: "tangle")
        actor.run(SKAction.sequence([
            SKAction.colorize(with: SKColor(red: 0.35, green: 0.7, blue: 0.32, alpha: 1), colorBlendFactor: 0.45, duration: 0.12),
            SKAction.colorize(withColorBlendFactor: 0, duration: 0.5)
        ]))
        splash(at: actor.position, big: false)
    }

    private func graze(_ actor: PondActor) {
        actor.grazeCooldown = 2.2
        actor.run(SKAction.sequence([
            SKAction.scale(to: 1.12, duration: 0.1),
            SKAction.scale(to: 1.0, duration: 0.14)
        ]))
        if let weed = nearestWeedNode(from: actor.position) {
            weed.run(SKAction.sequence([
                SKAction.scale(to: 0.88, duration: 0.12),
                SKAction.scale(to: 1.0, duration: 0.2)
            ]))
        }
        let nibble = SKShapeNode(circleOfRadius: 3)
        nibble.fillColor = SKColor(red: 0.45, green: 0.78, blue: 0.32, alpha: 0.85)
        nibble.strokeColor = .clear
        nibble.position = actor.position
        nibble.zPosition = 27
        addChild(nibble)
        nibble.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: CGFloat.random(in: -16...16), y: 22, duration: 0.4),
                SKAction.fadeOut(withDuration: 0.4)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    private func inWeeds(_ point: CGPoint) -> Bool {
        weedZones().contains { hypot($0.x - point.x, $0.y - point.y) < $1 }
    }

    private func nearestWeed(from point: CGPoint) -> CGPoint? {
        weedZones().min { hypot($0.0.x - point.x, $0.0.y - point.y) < hypot($1.0.x - point.x, $1.0.y - point.y) }?.0
    }

    private func nearestWeedNode(from point: CGPoint) -> SKNode? {
        var best: SKNode?
        var bestDist = CGFloat.greatestFiniteMagnitude
        enumerateChildNodes(withName: "weed") { node, _ in
            let dist = hypot(node.position.x - point.x, node.position.y - point.y)
            if dist < bestDist {
                bestDist = dist
                best = node
            }
        }
        for actor in actors.values where actor.kind == .grass && actor.beingEaten == false {
            let dist = hypot(actor.position.x - point.x, actor.position.y - point.y)
            if dist < bestDist {
                bestDist = dist
                best = actor
            }
        }
        return best
    }

    private func weedZones() -> [(CGPoint, CGFloat)] {
        var zones: [(CGPoint, CGFloat)] = []
        enumerateChildNodes(withName: "weed") { node, _ in
            let radius = max(36, max(node.frame.width, node.frame.height) * 0.42)
            zones.append((node.position, radius))
        }
        for actor in actors.values where actor.kind == .grass && actor.beingEaten == false {
            let radius = max(40, max(actor.size.width, actor.size.height) * 0.55)
            zones.append((actor.position, radius))
        }
        return zones
    }

    private func swayGrass(_ node: PondActor) {
        node.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.rotate(toAngle: 0.16, duration: 1.6, shortestUnitArc: true),
            SKAction.rotate(toAngle: -0.16, duration: 1.6, shortestUnitArc: true)
        ])), withKey: "wander")
    }

    private func castSkills(on actor: PondActor, picked: [CreatureSkill]) {
        guard actor.ready, actor.beingEaten == false, picked.isEmpty == false else { return }
        actor.removeAction(forKey: "skill")
        actor.casting = true
        actor.skillCooldown = CGFloat.random(in: 5.0...8.5)
        actor.removeAction(forKey: "wander")
        actor.removeAction(forKey: "bounce")

        if picked.contains(.glow) {
            glow(actor)
        }
        if picked.contains(.bubbles) {
            blowBubbles(from: actor)
        }
        if picked.contains(.scare) {
            scareAway(from: actor)
        }
        if picked.contains(.jump) {
            jump(actor)
        } else if picked.contains(.dash) {
            dash(actor)
        } else {
            finishCast(actor)
        }
    }

    private func finishCast(_ actor: PondActor) {
        actor.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.35),
            SKAction.run { [weak self, weak actor] in
                guard let self, let actor, actor.beingEaten == false else { return }
                actor.casting = false
                self.resumeIdle(actor)
            }
        ]), withKey: "skill")
    }

    private func jump(_ actor: PondActor) {
        let start = actor.position
        let peakY = min(size.height - 24, start.y + 88)
        let up = SKAction.move(to: CGPoint(x: start.x, y: peakY), duration: 0.28)
        up.timingMode = .easeOut
        let down = SKAction.move(to: start, duration: 0.32)
        down.timingMode = .easeIn
        actor.run(SKAction.sequence([
            up,
            SKAction.run { [weak self, weak actor] in
                guard let self, let actor else { return }
                self.splash(at: actor.position, big: true)
            },
            down,
            SKAction.run { [weak self, weak actor] in
                guard let self, let actor else { return }
                self.splash(at: actor.position, big: false)
                actor.casting = false
                self.resumeIdle(actor)
            }
        ]), withKey: "skill")
    }

    private func dash(_ actor: PondActor) {
        splash(at: actor.position, big: false)
        if actor.swims {
            actor.dashBoost = 1
            let speed = max(40, hypot(actor.velocity.dx, actor.velocity.dy))
            actor.velocity.dx = actor.velocity.dx / speed * 140
            actor.velocity.dy = actor.velocity.dy / speed * 90
            finishCast(actor)
            return
        }
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let dist: CGFloat = 130
        var dest = CGPoint(
            x: actor.position.x + cos(angle) * dist,
            y: actor.position.y + sin(angle) * dist * 0.55
        )
        dest.x = min(max(40, dest.x), size.width - 40)
        dest.y = min(max(36, dest.y), size.height - 36)
        let move = SKAction.move(to: dest, duration: 0.38)
        move.timingMode = .easeOut
        actor.run(SKAction.sequence([
            move,
            SKAction.run { [weak self, weak actor] in
                guard let self, let actor, actor.beingEaten == false else { return }
                actor.casting = false
                self.resumeIdle(actor)
            }
        ]), withKey: "skill")
    }

    private func resumeIdle(_ actor: PondActor) {
        guard actor.beingEaten == false else { return }
        if actor.kind == .grass {
            swayGrass(actor)
            return
        }
        if actor.swims {
            if hypot(actor.velocity.dx, actor.velocity.dy) < 12 {
                actor.velocity = CGVector(dx: 28, dy: CGFloat.random(in: -14...14))
            }
            return
        }
        wander(actor)
    }

    private func scareAway(from actor: PondActor) {
        splash(at: actor.position, big: true)
        for fish in fishes {
            let dx = fish.position.x - actor.position.x
            let dy = fish.position.y - actor.position.y
            let dist = max(1, hypot(dx, dy))
            if dist < 180 {
                fish.velocity = CGVector(dx: dx / dist * 150, dy: dy / dist * 110)
                fish.cooldown = 1.1
            }
        }
        for other in actors.values where other.creatureId != actor.creatureId && other.beingEaten == false && other.isHunter == false {
            let dx = other.position.x - actor.position.x
            let dy = other.position.y - actor.position.y
            let dist = max(1, hypot(dx, dy))
            if dist < 150, other.swims {
                other.velocity = CGVector(dx: dx / dist * 90, dy: dy / dist * 70)
            }
        }
    }

    private func gulpDecor(hunter: PondActor, fish: PondFish) {
        hunter.eatCooldown = 1.1
        fishes.removeAll { $0 === fish }
        fish.removeAllActions()
        splash(at: fish.position, big: true)
        sparkles(at: fish.position)
        hunter.run(SKAction.sequence([
            SKAction.scale(to: 1.28, duration: 0.12),
            SKAction.scale(to: 1.0, duration: 0.18)
        ]))
        fish.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 0.05, duration: 0.28),
                SKAction.fadeOut(withDuration: 0.28),
                SKAction.move(to: hunter.position, duration: 0.28)
            ]),
            SKAction.removeFromParent()
        ]))
        onEat?()
        run(SKAction.sequence([
            SKAction.wait(forDuration: 2.4),
            SKAction.run { [weak self] in
                self?.spawnDecorFish()
            }
        ]))
    }

    private func glow(_ actor: PondActor) {
        sparkles(at: actor.position)
        actor.run(SKAction.sequence([
            SKAction.colorize(with: SKColor(red: 1, green: 0.92, blue: 0.35, alpha: 1), colorBlendFactor: 0.7, duration: 0.12),
            SKAction.colorize(withColorBlendFactor: 0, duration: 0.55)
        ]), withKey: "glow")
        let ring = SKShapeNode(circleOfRadius: 16)
        ring.strokeColor = SKColor(red: 1, green: 0.9, blue: 0.35, alpha: 0.9)
        ring.lineWidth = 3
        ring.fillColor = .clear
        ring.position = actor.position
        ring.zPosition = 28
        addChild(ring)
        ring.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 5.5, duration: 0.55),
                SKAction.fadeOut(withDuration: 0.55)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    private func blowBubbles(from actor: PondActor) {
        for i in 0..<10 {
            let bubble = SKShapeNode(circleOfRadius: CGFloat.random(in: 4...9))
            bubble.fillColor = SKColor.white.withAlphaComponent(0.35)
            bubble.strokeColor = SKColor.white.withAlphaComponent(0.8)
            bubble.lineWidth = 1.4
            bubble.position = actor.position
            bubble.zPosition = 26
            addChild(bubble)
            let dx = CGFloat.random(in: -36...36)
            let dy = CGFloat.random(in: 50...130)
            bubble.run(SKAction.sequence([
                SKAction.wait(forDuration: Double(i) * 0.04),
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: 0.9),
                    SKAction.fadeOut(withDuration: 0.9)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func bump(fish: PondFish, doodle: SKSpriteNode) {
        let away = CGVector(
            dx: fish.position.x - doodle.position.x,
            dy: fish.position.y - doodle.position.y
        )
        let length = max(1, hypot(away.dx, away.dy))
        fish.velocity = CGVector(dx: away.dx / length * 90, dy: away.dy / length * 70)
        fish.removeAction(forKey: "flip")
        fish.run(SKAction.sequence([
            SKAction.scale(to: 1.22, duration: 0.12),
            SKAction.scale(to: 1.0, duration: 0.16)
        ]), withKey: "flip")

        bounce(doodle)
        doodle.run(SKAction.sequence([
            SKAction.colorize(with: SKColor(red: 1, green: 0.92, blue: 0.4, alpha: 1), colorBlendFactor: 0.45, duration: 0.08),
            SKAction.colorize(withColorBlendFactor: 0, duration: 0.22)
        ]))

        splash(at: contactPoint(fish.position, doodle.position), big: true)
        sparkles(at: doodle.position)
        if Bool.random() {
            hearts(at: doodle.position)
        }
        onFishBump?()
    }

    private func contactPoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    private func enter(creature: Creature, image: UIImage) {
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        let node = PondActor(texture: texture)
        node.creatureId = creature.id
        node.kind = creature.kind
        node.hunts = creature.hunts || creature.skills.contains(.eat)
        node.skills = creature.skills
        node.name = creature.id.uuidString
        node.size = Self.displaySize(for: image.size, kind: creature.kind)
        node.position = CGPoint(x: size.width * 0.5, y: size.height + 50)
        node.zPosition = creature.kind == .grass ? 6 : 12
        node.setScale(0.15)
        addChild(node)
        actors[creature.id] = node

        let dest: CGPoint
        if creature.kind == .grass {
            dest = CGPoint(
                x: CGFloat.random(in: 48...max(56, size.width - 48)),
                y: CGFloat.random(in: 34...max(48, size.height * 0.32))
            )
        } else {
            dest = randomPoint(for: node.size)
        }
        let drop = SKAction.group([
            SKAction.move(to: dest, duration: 0.48),
            SKAction.scale(to: 1, duration: 0.48)
        ])
        drop.timingMode = .easeOut
        node.run(SKAction.sequence([
            drop,
            SKAction.run { [weak self, weak node] in
                guard let self, let node else { return }
                node.ready = true
                node.skillCooldown = CGFloat.random(in: 2.2...4.8)
                self.splash(at: node.position, big: true)
                self.celebrateArrival(at: node.position)
                if node.kind == .grass {
                    self.swayGrass(node)
                } else if node.swims {
                    node.velocity = CGVector(
                        dx: CGFloat.random(in: -48...48),
                        dy: CGFloat.random(in: -28...28)
                    )
                    if abs(node.velocity.dx) < 16 { node.velocity.dx = 22 }
                    if node.kind == .crab { node.velocity.dy = -18 }
                } else {
                    self.wander(node)
                }
            }
        ]), withKey: "drop")
    }

    private func leave(id: UUID, node: SKSpriteNode) {
        leaving.insert(id)
        actors[id] = nil
        node.removeAllActions()
        let offscreen = CGPoint(x: size.width + 90, y: node.position.y)
        node.run(SKAction.sequence([
            SKAction.group([
                SKAction.move(to: offscreen, duration: 0.75),
                SKAction.fadeOut(withDuration: 0.75)
            ]),
            SKAction.removeFromParent()
        ])) { [weak self] in
            self?.leaving.remove(id)
        }
    }

    private func wander(_ node: SKSpriteNode) {
        guard node.parent != nil else { return }
        let dest = randomPoint(for: node.size)
        let distance = hypot(dest.x - node.position.x, dest.y - node.position.y)
        let duration = max(3.4, min(8.5, Double(distance) / 42.0))
        let move = SKAction.move(to: dest, duration: duration)
        move.timingMode = .easeInEaseOut
        let wiggle = SKAction.sequence([
            SKAction.rotate(toAngle: 0.12, duration: duration / 2, shortestUnitArc: true),
            SKAction.rotate(toAngle: -0.12, duration: duration / 2, shortestUnitArc: true)
        ])
        node.run(SKAction.sequence([
            SKAction.group([move, wiggle]),
            SKAction.run { [weak self, weak node] in
                guard let self, let node else { return }
                self.wander(node)
            }
        ]), withKey: "wander")
    }

    private func celebrateArrival(at point: CGPoint) {
        sparkles(at: point)
        hearts(at: point)
        for actor in actors.values where actor.ready && actor.beingEaten == false && actor.tangled <= 0 {
            bounce(actor)
        }
        for fish in fishes {
            let dx = point.x - fish.position.x
            let dy = point.y - fish.position.y
            let dist = max(1, hypot(dx, dy))
            fish.velocity = CGVector(dx: dx / dist * 70, dy: dy / dist * 48)
            fish.cooldown = 0.8
        }
    }

    private func bounce(_ node: SKSpriteNode) {
        node.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.28, duration: 0.12),
                SKAction.rotate(byAngle: .pi / 6, duration: 0.12)
            ]),
            SKAction.group([
                SKAction.scale(to: 1.0, duration: 0.16),
                SKAction.rotate(toAngle: 0, duration: 0.16, shortestUnitArc: true)
            ])
        ]), withKey: "bounce")
    }

    private func splash(at point: CGPoint, big: Bool) {
        let ring = SKShapeNode(circleOfRadius: big ? 10 : 6)
        ring.strokeColor = SKColor.white.withAlphaComponent(0.75)
        ring.lineWidth = 2.5
        ring.fillColor = .clear
        ring.position = point
        ring.zPosition = 30
        addChild(ring)
        ring.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: big ? 7 : 4.2, duration: 0.55),
                SKAction.fadeOut(withDuration: 0.55)
            ]),
            SKAction.removeFromParent()
        ]))

        let count = big ? 10 : 5
        for _ in 0..<count {
            let drop = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.8...4.2))
            drop.fillColor = SKColor.white.withAlphaComponent(0.85)
            drop.strokeColor = .clear
            drop.position = point
            drop.zPosition = 31
            addChild(drop)
            let dx = CGFloat.random(in: -70...70)
            let dy = CGFloat.random(in: 24...90)
            drop.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: 0.42),
                    SKAction.fadeOut(withDuration: 0.42)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func sparkles(at point: CGPoint) {
        let colors: [SKColor] = [
            SKColor(red: 1, green: 0.92, blue: 0.35, alpha: 1),
            SKColor.white,
            SKColor(red: 1, green: 0.55, blue: 0.2, alpha: 1)
        ]
        for _ in 0..<12 {
            let star = SKShapeNode(rectOf: CGSize(width: 8, height: 8), cornerRadius: 1)
            star.fillColor = colors.randomElement() ?? .white
            star.strokeColor = .clear
            star.zRotation = .pi / 4
            star.position = point
            star.zPosition = 32
            addChild(star)
            let dx = CGFloat.random(in: -90...90)
            let dy = CGFloat.random(in: 10...80)
            star.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: 0.55),
                    SKAction.fadeOut(withDuration: 0.55),
                    SKAction.scale(to: 0.2, duration: 0.55)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func hearts(at point: CGPoint) {
        for i in 0..<3 {
            let heart = SKLabelNode(text: "♥")
            heart.fontName = "Helvetica-Bold"
            heart.fontSize = 22
            heart.fontColor = SKColor(red: 0.95, green: 0.35, blue: 0.48, alpha: 1)
            heart.position = point
            heart.zPosition = 33
            addChild(heart)
            let dx = CGFloat([-18, 0, 18][i])
            heart.run(SKAction.sequence([
                SKAction.wait(forDuration: Double(i) * 0.06),
                SKAction.group([
                    SKAction.moveBy(x: dx, y: 70, duration: 0.7),
                    SKAction.fadeOut(withDuration: 0.7)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func spawnBubble() {
        guard size.width > 40 else { return }
        let bubble = SKShapeNode(circleOfRadius: CGFloat.random(in: 2.5...5.5))
        bubble.fillColor = SKColor.white.withAlphaComponent(0.22)
        bubble.strokeColor = SKColor.white.withAlphaComponent(0.45)
        bubble.lineWidth = 1
        bubble.position = CGPoint(x: CGFloat.random(in: 24...max(25, size.width - 24)), y: 10)
        bubble.zPosition = 5
        bubble.name = "bubble"
        addChild(bubble)
        bubble.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: CGFloat.random(in: -24...24), y: size.height * 0.85, duration: Double.random(in: 3.8...7)),
                SKAction.fadeOut(withDuration: 5.5)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    private func randomPoint(for spriteSize: CGSize) -> CGPoint {
        let padX = max(48, spriteSize.width / 2 + 18)
        let padY = max(40, spriteSize.height / 2 + 18)
        let minX = padX
        let maxX = max(minX + 8, size.width - padX)
        let minY = padY
        let maxY = max(minY + 8, size.height - padY - 10)
        return CGPoint(
            x: CGFloat.random(in: minX...maxX),
            y: CGFloat.random(in: minY...maxY)
        )
    }

    private static func displaySize(for imageSize: CGSize, kind: CreatureKind) -> CGSize {
        let longest = max(imageSize.width, imageSize.height, 1)
        let target: CGFloat
        switch kind {
        case .tadpole: target = 72
        case .smallFish: target = 92
        case .crab: target = 108
        case .bigFish: target = 142
        case .grass: target = 96
        case .doodle: target = min(158, max(92, longest * 0.22))
        }
        let scale = target / longest
        return CGSize(width: max(64, imageSize.width * scale), height: max(52, imageSize.height * scale))
    }

    private func rebuildIfNeeded() {
        guard size.width > 40, size.height > 40 else { return }
        let changed = abs(lastBuiltSize.width - size.width) > 2 || abs(lastBuiltSize.height - size.height) > 2
        guard changed else { return }
        lastBuiltSize = size
        rebuildWater()
        rebuildFlora()
        rebuildFish()
    }

    private func rebuildWater() {
        enumerateChildNodes(withName: "water") { node, _ in node.removeFromParent() }
        let water = SKSpriteNode(texture: SKTexture(image: PondArt.water(size: size)))
        water.name = "water"
        water.size = size
        water.position = CGPoint(x: size.width / 2, y: size.height / 2)
        water.zPosition = -20
        addChild(water)
    }

    private func rebuildFlora() {
        enumerateChildNodes(withName: "lily") { node, _ in node.removeFromParent() }
        enumerateChildNodes(withName: "reed") { node, _ in node.removeFromParent() }
        enumerateChildNodes(withName: "weed") { node, _ in node.removeFromParent() }

        let pads: [(CGFloat, CGFloat, CGFloat, Bool)] = [
            (0.14, 0.28, 46, true),
            (0.32, 0.16, 34, false),
            (0.52, 0.24, 40, true),
            (0.73, 0.18, 30, false),
            (0.88, 0.34, 38, true),
            (0.22, 0.62, 28, false),
            (0.78, 0.58, 32, false)
        ]
        for (rx, ry, radius, flower) in pads {
            let texture = SKTexture(image: PondArt.lilyPad(radius: radius, flower: flower))
            let pad = SKSpriteNode(texture: texture)
            pad.name = "lily"
            pad.position = CGPoint(x: size.width * rx, y: size.height * ry)
            pad.zPosition = 3
            pad.zRotation = CGFloat.random(in: -0.4...0.4)
            addChild(pad)
            pad.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.moveBy(x: 0, y: 4, duration: Double.random(in: 2.2...3.1)),
                SKAction.moveBy(x: 0, y: -4, duration: Double.random(in: 2.2...3.1))
            ])))
        }

        for i in 0..<8 {
            let reed = SKSpriteNode(texture: SKTexture(image: PondArt.reed()))
            reed.name = "reed"
            reed.position = CGPoint(
                x: size.width * (0.04 + CGFloat(i) * 0.13) + CGFloat.random(in: -8...8),
                y: 28 + CGFloat.random(in: 0...10)
            )
            reed.zPosition = 4
            reed.zRotation = CGFloat.random(in: -0.12...0.12)
            addChild(reed)
        }

        let weedSpots: [(CGFloat, CGFloat, CGFloat)] = [
            (0.12, 0.18, 1.0),
            (0.28, 0.12, 0.85),
            (0.48, 0.16, 1.15),
            (0.66, 0.11, 0.9),
            (0.84, 0.19, 1.05)
        ]
        for (rx, ry, scale) in weedSpots {
            let weed = SKSpriteNode(texture: SKTexture(image: PondArt.seaweed()))
            weed.name = "weed"
            weed.setScale(scale)
            weed.position = CGPoint(x: size.width * rx, y: size.height * ry)
            weed.zPosition = 4
            addChild(weed)
            weed.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.rotate(toAngle: 0.14, duration: Double.random(in: 1.6...2.2), shortestUnitArc: true),
                SKAction.rotate(toAngle: -0.14, duration: Double.random(in: 1.6...2.2), shortestUnitArc: true)
            ])))
        }
    }

    private func rebuildFish() {
        fishes.forEach { $0.removeFromParent() }
        fishes.removeAll()

        let kinds: [(CGFloat, UIColor, UIColor, Bool)] = [
            (78, UIColor(red: 0.92, green: 0.42, blue: 0.14, alpha: 1), UIColor(red: 1, green: 0.72, blue: 0.32, alpha: 1), true),
            (64, UIColor(red: 0.95, green: 0.22, blue: 0.16, alpha: 1), UIColor(red: 1, green: 0.55, blue: 0.35, alpha: 1), false),
            (70, UIColor(red: 0.95, green: 0.82, blue: 0.28, alpha: 1), UIColor(red: 1, green: 0.93, blue: 0.55, alpha: 1), false),
            (58, UIColor(red: 0.85, green: 0.85, blue: 0.88, alpha: 1), UIColor(red: 1, green: 0.45, blue: 0.38, alpha: 1), true),
            (52, UIColor(red: 0.18, green: 0.48, blue: 0.72, alpha: 1), UIColor(red: 0.45, green: 0.75, blue: 0.9, alpha: 1), false)
        ]
        for (length, body, belly, spots) in kinds {
            let fish = PondFish(texture: SKTexture(image: PondArt.fish(length: length, body: body, belly: belly, spots: spots)))
            fish.name = "fish"
            fish.position = CGPoint(
                x: CGFloat.random(in: 60...(size.width - 60)),
                y: CGFloat.random(in: 50...(size.height - 50))
            )
            fish.zPosition = 8
            fish.velocity = CGVector(
                dx: CGFloat.random(in: -50...50),
                dy: CGFloat.random(in: -28...28)
            )
            if abs(fish.velocity.dx) < 18 { fish.velocity.dx = 24 }
            addChild(fish)
            fishes.append(fish)
        }
    }

    private func spawnDecorFish() {
        guard size.width > 80 else { return }
        let kinds: [(CGFloat, UIColor, UIColor, Bool)] = [
            (64, UIColor(red: 0.92, green: 0.42, blue: 0.14, alpha: 1), UIColor(red: 1, green: 0.72, blue: 0.32, alpha: 1), true),
            (58, UIColor(red: 0.95, green: 0.22, blue: 0.16, alpha: 1), UIColor(red: 1, green: 0.55, blue: 0.35, alpha: 1), false),
            (52, UIColor(red: 0.18, green: 0.48, blue: 0.72, alpha: 1), UIColor(red: 0.45, green: 0.75, blue: 0.9, alpha: 1), false)
        ]
        let pick = kinds.randomElement() ?? kinds[0]
        let fish = PondFish(texture: SKTexture(image: PondArt.fish(length: pick.0, body: pick.1, belly: pick.2, spots: pick.3)))
        fish.name = "fish"
        fish.position = CGPoint(x: -40, y: CGFloat.random(in: 50...max(60, size.height - 50)))
        fish.zPosition = 8
        fish.velocity = CGVector(dx: 36, dy: CGFloat.random(in: -16...16))
        fish.alpha = 0
        addChild(fish)
        fishes.append(fish)
        fish.run(SKAction.fadeIn(withDuration: 0.35))
    }
}
