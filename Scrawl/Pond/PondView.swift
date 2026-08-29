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
                    scene.onEat = { [sound] in
                        sound.play(.gulp)
                        sound.hapticLight()
                    }
                    scene.onCreatureEaten = { [world] id in
                        world.remove(id: id)
                    }
                    scene.sync(creatures: world.creatures, images: world.images)
                }
                .onChange(of: geo.size) { _, size in
                    scene.size = size
                }
                .onChange(of: world.skillPulse) { _, pulse in
                    guard let pulse else { return }
                    scene.playSkill(pulse.skill)
                }
                .onChange(of: world.creatures) { _, creatures in
                    scene.sync(creatures: creatures, images: world.images)
                }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
