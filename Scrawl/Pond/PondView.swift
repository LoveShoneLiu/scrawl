import SpriteKit
import SwiftUI

struct PondView: View {
    @EnvironmentObject private var world: WorldStore
    @EnvironmentObject private var sound: SoundPlayer

    @State private var scene = PondScene()

    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: scene)
                .onAppear {
                    scene.size = geo.size
                    scene.scaleMode = .resizeFill
                    scene.backgroundColor = Palette.pondBottom
                    scene.onTapCreature = { [sound] in
                        sound.play(.tap)
                        sound.hapticLight()
                    }
                    scene.onSkill = { [sound] in
                        sound.play(.skill)
                        sound.hapticLight()
                    }
                    scene.onFishBump = { [sound] in
                        sound.play(.splash)
                        sound.hapticLight()
                    }
                    scene.onCatch = { [sound] in
                        sound.play(.hooked)
                        sound.hapticLight()
                    }
                    scene.onNetted = { [world] fish in
                        world.addNetted(fish)
                    }
                    scene.onNettedDoodle = { [world] id in
                        world.addNettedCreature(id: id)
                    }
                    scene.onFishingChanged = { [world] active in
                        world.isFishing = active
                    }
                    scene.onEat = { [sound] in
                        sound.play(.gulp)
                        sound.hapticLight()
                    }
                    scene.onCreatureEaten = { [world] id in
                        world.remove(id: id)
                    }
                    scene.sync(
                        creatures: world.creatures,
                        images: world.images,
                        nettedIds: Set(world.nettedCreatureIds)
                    )
                    scene.syncNetted(world.nettedFish)
                    scene.syncNettedDoodles(
                        ids: world.nettedCreatureIds,
                        creatures: world.creatures,
                        images: world.images
                    )
                }
                .onChange(of: geo.size) { _, size in
                    scene.size = size
                }
                .onChange(of: world.skillPulse) { _, pulse in
                    guard let pulse else { return }
                    scene.playSkill(
                        pulse.skill,
                        color: UIColor(red: pulse.red, green: pulse.green, blue: pulse.blue, alpha: 1)
                    )
                }
                .onChange(of: world.creatures) { _, creatures in
                    scene.sync(
                        creatures: creatures,
                        images: world.images,
                        nettedIds: Set(world.nettedCreatureIds)
                    )
                    scene.syncNettedDoodles(
                        ids: world.nettedCreatureIds,
                        creatures: creatures,
                        images: world.images
                    )
                }
                .onChange(of: world.nettedFish) { _, netted in
                    scene.syncNetted(netted)
                }
                .onChange(of: world.nettedCreatureIds) { _, ids in
                    scene.sync(
                        creatures: world.creatures,
                        images: world.images,
                        nettedIds: Set(ids)
                    )
                    scene.syncNettedDoodles(
                        ids: ids,
                        creatures: world.creatures,
                        images: world.images
                    )
                }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
