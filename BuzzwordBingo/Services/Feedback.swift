import AVFoundation
import UIKit

@MainActor
final class Feedback {
    static let shared = Feedback()
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var buffer: AVAudioPCMBuffer?

    private init() {
        let rate = 44_100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_410),
              let samples = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = buffer.frameCapacity
        var phase = 0.0
        for index in 0..<Int(buffer.frameLength) {
            let t = Double(index) / rate
            let frequency = 760 * exp(-t * 24) + 160
            phase += 2 * .pi * frequency / rate
            let envelope = min(t * 1_500, 1) * exp(-t * 65)
            samples[index] = Float(sin(phase) * envelope * 0.48)
        }
        self.buffer = buffer
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func tap(settings: GameSettings, marked: Bool, won: Bool) {
        if settings.haptics {
            if won { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            else { UIImpactFeedbackGenerator(style: marked ? .light : .soft).impactOccurred() }
        }
        guard settings.sound, marked, let buffer else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            if !engine.isRunning { try engine.start() }
            if !player.isPlaying { player.play() }
            player.scheduleBuffer(buffer)
        } catch {
            // Audio interruptions must never interrupt the game.
        }
    }
}
