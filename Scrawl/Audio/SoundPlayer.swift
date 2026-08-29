import AVFoundation
import Combine
import UIKit

@MainActor
final class SoundPlayer: ObservableObject {
    var isEnabled = true

    private var players: [String: AVAudioPlayer] = [:]

    enum Cue: String {
        case drop
        case tap
        case empty
        case splash
        case gulp
        case skill
    }

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        players[Cue.drop.rawValue] = Self.makePlayer(frequency: 620, duration: 0.18, sweep: -180)
        players[Cue.tap.rawValue] = Self.makePlayer(frequency: 880, duration: 0.09, sweep: 40)
        players[Cue.empty.rawValue] = Self.makePlayer(frequency: 220, duration: 0.08, sweep: -40)
        players[Cue.splash.rawValue] = Self.makePlayer(frequency: 480, duration: 0.16, sweep: 220)
        players[Cue.gulp.rawValue] = Self.makePlayer(frequency: 160, duration: 0.22, sweep: -90)
        players[Cue.skill.rawValue] = Self.makePlayer(frequency: 1040, duration: 0.16, sweep: 260)
    }

    func play(_ cue: Cue) {
        guard isEnabled, let player = players[cue.rawValue] else { return }
        player.currentTime = 0
        player.play()
    }

    func hapticLight() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private static func makePlayer(frequency: Double, duration: Double, sweep: Double) -> AVAudioPlayer? {
        let sampleRate = 22_050.0
        let count = Int(sampleRate * duration)
        var samples = [Int16]()
        samples.reserveCapacity(count)
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let env = sin(min(1, t / 0.012) * .pi / 2) * pow(1 - t / duration, 1.6)
            let freq = frequency + sweep * (t / duration)
            let value = sin(2 * .pi * freq * t) * env
            samples.append(Int16(max(-1, min(1, value)) * 24_000))
        }
        let data = wavData(samples: samples, sampleRate: Int(sampleRate))
        let player = try? AVAudioPlayer(data: data)
        player?.prepareToPlay()
        player?.volume = 0.45
        return player
    }

    private static func wavData(samples: [Int16], sampleRate: Int) -> Data {
        let dataSize = samples.count * 2
        var data = Data()
        func ascii(_ s: String) { data.append(contentsOf: s.utf8) }
        func u16(_ v: UInt16) {
            var le = v.littleEndian
            data.append(Data(bytes: &le, count: 2))
        }
        func u32(_ v: UInt32) {
            var le = v.littleEndian
            data.append(Data(bytes: &le, count: 4))
        }
        ascii("RIFF")
        u32(UInt32(36 + dataSize))
        ascii("WAVE")
        ascii("fmt ")
        u32(16)
        u16(1)
        u16(1)
        u32(UInt32(sampleRate))
        u32(UInt32(sampleRate * 2))
        u16(2)
        u16(16)
        ascii("data")
        u32(UInt32(dataSize))
        for sample in samples {
            var le = UInt16(bitPattern: sample).littleEndian
            data.append(Data(bytes: &le, count: 2))
        }
        return data
    }
}
