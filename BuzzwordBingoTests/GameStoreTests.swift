import XCTest
@testable import BuzzwordBingo

final class GameStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    override func setUp() {
        suite = "bingo-tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
    }

    func testFreshStoreAndRestore() {
        let store = GameStore(defaults: defaults, now: now)
        XCTAssertEqual(store.statistics.boardsPlayed, 1)
        store.toggle(0, now: now)
        store.updateSettings(sound: false, haptics: false)
        let restored = GameStore(defaults: defaults, now: now)
        XCTAssertEqual(restored.game, store.game)
        XCTAssertFalse(restored.settings.sound)
        XCTAssertFalse(restored.settings.haptics)
        XCTAssertEqual(restored.celebration, 0)
    }

    func testCorruptSnapshotRecovers() {
        defaults.set(Data("broken".utf8), forKey: "meeting-buzzword-bingo.snapshot.v1")
        let store = GameStore(defaults: defaults, now: now)
        XCTAssertTrue(store.game.isValid)
        XCTAssertEqual(store.statistics.boardsPlayed, 1)
    }

    func testIncompatibleSnapshotRecovers() throws {
        let store = GameStore(defaults: defaults, now: now)
        var snapshot = store.snapshot
        snapshot.version = 999
        defaults.set(try JSONEncoder().encode(snapshot), forKey: "meeting-buzzword-bingo.snapshot.v1")
        XCTAssertNotEqual(GameStore(defaults: defaults, now: now).game.id, store.game.id)
    }

    func testInvalidBoardRecovers() throws {
        let store = GameStore(defaults: defaults, now: now)
        var snapshot = store.snapshot
        snapshot.quick.tiles.removeLast()
        defaults.set(try JSONEncoder().encode(snapshot), forKey: "meeting-buzzword-bingo.snapshot.v1")
        XCTAssertTrue(GameStore(defaults: defaults, now: now).game.isValid)
    }

    func testDailyAndQuickProgressIndependent() {
        let store = GameStore(defaults: defaults, now: now)
        store.toggle(0, now: now)
        let quick = store.game
        store.selectMode(.daily, now: now)
        XCTAssertEqual(store.statistics.boardsPlayed, 2)
        XCTAssertFalse(store.game.tiles[0].isMarked)
        store.toggle(1, now: now)
        let daily = store.game
        store.selectMode(.quick, now: now)
        XCTAssertEqual(store.game, quick)
        store.selectMode(.daily, now: now)
        XCTAssertEqual(store.game, daily)
        XCTAssertEqual(store.statistics.boardsPlayed, 2)
    }

    func testDailyRolloverLeavesQuickUntouched() {
        let store = GameStore(defaults: defaults, now: now)
        let quick = store.game
        let oldDaily = store.snapshot.daily
        store.refreshDaily(now: now.addingTimeInterval(86_400))
        XCTAssertEqual(store.game, quick)
        XCTAssertNotEqual(store.snapshot.daily.seed, oldDaily.seed)
    }

    func testDailyRolloverUsesPersistedCalendarKey() throws {
        let store = GameStore(defaults: defaults, now: now)
        var snapshot = store.snapshot
        snapshot.dailyKey = "2000-01-01"
        let oldID = snapshot.daily.id
        defaults.set(try JSONEncoder().encode(snapshot), forKey: "meeting-buzzword-bingo.snapshot.v1")
        let restored = GameStore(defaults: defaults, now: now)
        XCTAssertNotEqual(restored.snapshot.daily.id, oldID)
        XCTAssertEqual(restored.snapshot.dailyKey, BingoGame.dateKey(now))
    }

    func testDailyRolloverWhileSelectedCountsNewBoard() {
        let store = GameStore(defaults: defaults, now: now)
        store.selectMode(.daily, now: now)
        store.refreshDaily(now: now.addingTimeInterval(86_400))
        XCTAssertEqual(store.statistics.boardsPlayed, 3)
        store.selectMode(.quick, now: now.addingTimeInterval(86_400))
        store.selectMode(.daily, now: now.addingTimeInterval(86_400))
        XCTAssertEqual(store.statistics.boardsPlayed, 3)
    }

    func testNewBoardPreservesDaily() {
        let store = GameStore(defaults: defaults, now: now)
        let daily = store.snapshot.daily
        let oldID = store.game.id
        store.newBoard(pack: .techTalk, now: now)
        XCTAssertNotEqual(store.game.id, oldID)
        XCTAssertEqual(store.game.pack, .techTalk)
        XCTAssertEqual(store.snapshot.daily, daily)
        XCTAssertEqual(store.statistics.boardsPlayed, 2)
    }

    func testTimeExcludesBackground() {
        let store = GameStore(defaults: defaults, now: now)
        store.setActive(true, now: now)
        store.setActive(false, now: now.addingTimeInterval(10))
        store.setActive(true, now: now.addingTimeInterval(110))
        store.toggle(0, now: now.addingTimeInterval(115))
        XCTAssertEqual(store.game.activeSeconds, 15, accuracy: 0.001)
    }

    func testSwitchCheckpointsCorrectGame() {
        let store = GameStore(defaults: defaults, now: now)
        store.setActive(true, now: now)
        store.selectMode(.daily, now: now.addingTimeInterval(10))
        store.setActive(false, now: now.addingTimeInterval(30))
        XCTAssertEqual(store.snapshot.quick.activeSeconds, 10)
        XCTAssertEqual(store.snapshot.daily.activeSeconds, 20)
    }

    func testWinAwardsOnlyOnceAndPersists() {
        let store = GameStore(defaults: defaults, now: now)
        store.setActive(true, now: now)
        for index in 0..<5 { store.toggle(index, now: now.addingTimeInterval(20)) }
        XCTAssertEqual(store.statistics.boardsWon, 1)
        XCTAssertEqual(store.statistics.totalLines, 1)
        XCTAssertEqual(store.statistics.bestSeconds, 20)
        XCTAssertEqual(store.celebration, 1)
        store.toggle(0, now: now.addingTimeInterval(21))
        store.toggle(0, now: now.addingTimeInterval(22))
        XCTAssertEqual(store.statistics.totalLines, 1)
        XCTAssertEqual(store.celebration, 1)
        let restored = GameStore(defaults: defaults, now: now)
        XCTAssertEqual(restored.statistics, store.statistics)
        XCTAssertEqual(restored.celebration, 0)
    }

    func testFreeAndInvalidTapDoNotCelebrate() {
        let store = GameStore(defaults: defaults, now: now)
        let game = store.game
        store.toggle(12, now: now)
        store.toggle(-1, now: now)
        XCTAssertEqual(store.game, game)
        XCTAssertEqual(store.celebration, 0)
    }
}
