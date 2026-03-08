import Foundation
import AVFoundation

@MainActor
final class WorkoutCuePlayer {
    static let shared = WorkoutCuePlayer()

    enum Cue: String, CaseIterable {
        case restStart = "rest_start_soft_bell"
        case restCountdown = "rest_warning_3_beeps"
        case restEnd = "rest_end_emphatic_bell"
    }

    private let prefs = UserPreferences.shared
    private var players: [Cue: AVAudioPlayer] = [:]
    private var audioSessionConfigured = false

    private init() {
        Cue.allCases.forEach(loadPlayer(for:))
    }

    func play(_ cue: Cue) {
        guard prefs.restSoundCuesEnabled else { return }
        configureAudioSessionIfNeeded()

        guard let player = players[cue] else {
            #if DEBUG
            assertionFailure("Missing audio resource for cue: \(cue.rawValue).wav")
            #endif
            return
        }

        if player.isPlaying {
            player.stop()
        }
        player.currentTime = 0
        player.play()
    }

    private func loadPlayer(for cue: Cue) {
        guard let url = Bundle.main.url(forResource: cue.rawValue, withExtension: "wav") else {
            #if DEBUG
            assertionFailure("Bundled sound not found: \(cue.rawValue).wav")
            #endif
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            players[cue] = player
        } catch {
            #if DEBUG
            print("Failed to load cue \(cue.rawValue): \(error)")
            #endif
        }
    }

    private func configureAudioSessionIfNeeded() {
        guard !audioSessionConfigured else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            audioSessionConfigured = true
        } catch {
            #if DEBUG
            print("WorkoutCuePlayer audio session setup failed: \(error)")
            #endif
        }
    }
}
