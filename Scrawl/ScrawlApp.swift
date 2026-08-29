import SwiftUI

@main
struct ScrawlApp: App {
    @StateObject private var world = WorldStore()
    @StateObject private var drawing = DrawingSession()
    @StateObject private var sound = SoundPlayer()

    var body: some Scene {
        WindowGroup {
            PlayView()
                .environmentObject(world)
                .environmentObject(drawing)
                .environmentObject(sound)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
                .onAppear {
                    sound.isEnabled = world.soundEnabled
                }
                .onChange(of: world.soundEnabled) { _, enabled in
                    sound.isEnabled = enabled
                }
        }
    }
}
