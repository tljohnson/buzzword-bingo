import Foundation
import Observation

struct GameSettings: Codable, Equatable {
    var sound = true
    var haptics = true
}

struct GameSnapshot: Codable {
    var version = 1
    var quick: BingoGame
    var daily: BingoGame
    var mode: GameMode
    var statistics: GameStatistics
    var settings: GameSettings
    var dailyKey: String
    var dailyStarted = false

    var isValid: Bool {
        version == 1 && quick.isValid && daily.isValid
            && quick.mode == .quick && daily.mode == .daily
    }
}

@Observable
final class GameStore {
    private(set) var snapshot: GameSnapshot
    private(set) var celebration = 0
    private(set) var lastLineCount = 0
    private let defaults: UserDefaults
    private let key = "meeting-buzzword-bingo.snapshot.v1"
    private var activeSince: Date?

    var game: BingoGame { snapshot.mode == .quick ? snapshot.quick : snapshot.daily }
    var statistics: GameStatistics { snapshot.statistics }
    var settings: GameSettings { snapshot.settings }
    var mode: GameMode { snapshot.mode }

    init(defaults: UserDefaults = .standard, now: Date = Date()) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode(GameSnapshot.self, from: data), saved.isValid {
            snapshot = saved
        } else {
            var statistics = GameStatistics()
            statistics.recordStart()
            snapshot = GameSnapshot(
                quick: BingoGame(pack: .mixed, mode: .quick, date: now),
                daily: BingoGame(pack: .mixed, mode: .daily, date: now),
                mode: .quick, statistics: statistics, settings: GameSettings(),
                dailyKey: BingoGame.dateKey(now)
            )
        }
        refreshDaily(now: now)
        save()
    }

    func setActive(_ active: Bool, now: Date = Date()) {
        checkpoint(now: now)
        activeSince = active ? now : nil
        if active { refreshDaily(now: now) }
        save()
    }

    func selectMode(_ mode: GameMode, now: Date = Date()) {
        guard mode != snapshot.mode else { return }
        checkpoint(now: now)
        refreshDaily(now: now)
        snapshot.mode = mode
        // The daily board is counted only when first opened, not when pre-generated.
        if mode == .daily && !snapshot.dailyStarted {
            snapshot.statistics.recordStart()
            snapshot.dailyStarted = true
        }
        save()
    }

    func newBoard(pack: PhrasePack, now: Date = Date()) {
        checkpoint(now: now)
        snapshot.mode = .quick
        snapshot.quick = BingoGame(pack: pack, mode: .quick, date: now)
        snapshot.statistics.recordStart()
        save()
    }

    func toggle(_ index: Int, now: Date = Date()) {
        checkpoint(now: now)
        refreshDaily(now: now)
        var updated = game
        let wasWon = updated.hasWon
        let previousTiles = updated.tiles
        let newLines = updated.toggle(index: index)
        guard previousTiles != updated.tiles else { return }
        if snapshot.mode == .quick { snapshot.quick = updated } else { snapshot.daily = updated }
        snapshot.statistics.record(newLines: newLines, firstWin: !wasWon && updated.hasWon,
                                   seconds: updated.activeSeconds)
        if !newLines.isEmpty {
            lastLineCount = newLines.count
            celebration += 1
        }
        save()
    }

    func updateSettings(sound: Bool? = nil, haptics: Bool? = nil) {
        if let sound { snapshot.settings.sound = sound }
        if let haptics { snapshot.settings.haptics = haptics }
        save()
    }

    func refreshDaily(now: Date = Date()) {
        guard snapshot.dailyKey != BingoGame.dateKey(now) else { return }
        snapshot.daily = BingoGame(pack: .mixed, mode: .daily, date: now)
        snapshot.dailyKey = BingoGame.dateKey(now)
        snapshot.dailyStarted = snapshot.mode == .daily
        if snapshot.mode == .daily {
            snapshot.statistics.recordStart()
        }
        save()
    }

    private func checkpoint(now: Date) {
        guard let start = activeSince else { return }
        let elapsed = max(0, now.timeIntervalSince(start))
        if snapshot.mode == .quick { snapshot.quick.activeSeconds += elapsed }
        else { snapshot.daily.activeSeconds += elapsed }
        activeSince = now
    }

    private func save() {
        if let data = try? JSONEncoder().encode(snapshot) { defaults.set(data, forKey: key) }
    }
}
