import Foundation
import XCTest
@testable import BuzzwordBingo

final class GameEngineTests: XCTestCase {
    private func game(pack: PhrasePack = .mixed, seed: UInt64 = 42) -> BingoGame {
        BingoGame(pack: pack, mode: .quick, seed: seed)
    }

    private func localDate(day: Int = 26, hour: Int = 12) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private func mark(_ indices: [Int], in game: inout BingoGame) -> Set<Int> {
        var awards = Set<Int>()
        for index in indices where !game.tiles[index].isMarked {
            awards.formUnion(game.toggle(index: index))
        }
        return awards
    }

    func testPacksHaveUniqueIDsAndDisplayMetadata() {
        XCTAssertEqual(Set(PhrasePack.allCases.map(\.id)).count, 4)
        for pack in PhrasePack.allCases {
            XCTAssertFalse(pack.name.isEmpty)
            XCTAssertFalse(pack.subtitle.isEmpty)
            XCTAssertFalse(pack.symbol.isEmpty)
            XCTAssertEqual(pack.id, pack.rawValue)
        }
    }

    func testEveryCuratedPackContainsAtLeastFortyUniquePhrases() {
        for pack in PhrasePack.allCases where pack != .mixed {
            XCTAssertGreaterThanOrEqual(pack.phrases.count, 40)
            XCTAssertEqual(Set(pack.phrases).count, pack.phrases.count)
            XCTAssertTrue(pack.phrases.allSatisfy { !$0.isEmpty })
        }
    }

    func testMixedPackIsTheUniqueUnionOfCuratedPacks() {
        let expected = Set([PhrasePack.allHands, .techTalk, .strategy].flatMap(\.phrases))
        XCTAssertEqual(Set(PhrasePack.mixed.phrases), expected)
        XCTAssertEqual(PhrasePack.mixed.phrases.count, expected.count)
    }

    func testGenerationProducesTwentyFourUniquePhrasesAndFreeCenter() {
        for pack in PhrasePack.allCases {
            for seed in UInt64(0)..<20 {
                let board = game(pack: pack, seed: seed)
                XCTAssertTrue(board.isValid)
                XCTAssertEqual(board.tiles.map(\.index), Array(0..<25))
                XCTAssertEqual(Set(board.tiles.map(\.phrase)).count, 25)
                XCTAssertEqual(board.tiles.filter(\.isMarked).map(\.index), [12])
                XCTAssertEqual(board.tiles.filter(\.isFree).map(\.index), [12])
                XCTAssertTrue(Set(board.tiles.filter { !$0.isFree }.map(\.phrase)).isSubset(of: Set(pack.phrases)))
            }
        }
    }

    func testInitialGameState() {
        let board = game()
        XCTAssertEqual(board.activeSeconds, 0)
        XCTAssertEqual(board.markedCount, 0)
        XCTAssertEqual(board.nearestLineCount, 1)
        XCTAssertEqual(board.completedLines, [])
        XCTAssertEqual(board.awardedLines, [])
        XCTAssertEqual(board.winningTileIndices, [])
        XCTAssertFalse(board.hasWon)
        XCTAssertEqual(board.tiles[12].id, 12)
    }

    func testExplicitSeedIsRepeatableIncludingZeroAndMaximum() {
        for seed in [UInt64(0), 1, 42, UInt64.max] {
            XCTAssertEqual(game(seed: seed).tiles, game(seed: seed).tiles)
            XCTAssertEqual(game(seed: seed).seed, seed)
        }
    }

    func testDifferentSeedsProduceDifferentBoards() {
        XCTAssertNotEqual(game(seed: 1).tiles, game(seed: 2).tiles)
    }

    func testDailyBoardIsStableThroughoutLocalDay() {
        for pack in PhrasePack.allCases {
            let first = BingoGame(pack: pack, mode: .daily, date: localDate(hour: 0))
            let later = BingoGame(pack: pack, mode: .daily, date: localDate(hour: 23))
            XCTAssertEqual(first.seed, later.seed)
            XCTAssertEqual(first.tiles, later.tiles)
            XCTAssertNotEqual(first.id, later.id)
        }
    }

    func testDailySeedUsesDateAndPack() {
        let first = BingoGame(pack: .allHands, mode: .daily, date: localDate())
        let tomorrow = BingoGame(pack: .allHands, mode: .daily, date: localDate(day: 27))
        let otherPack = BingoGame(pack: .strategy, mode: .daily, date: localDate())
        XCTAssertNotEqual(first.seed, tomorrow.seed)
        XCTAssertNotEqual(first.tiles, tomorrow.tiles)
        XCTAssertNotEqual(first.seed, otherPack.seed)
        XCTAssertEqual(first.createdAt, localDate())
        XCTAssertEqual(first.mode, .daily)
        XCTAssertEqual(first.pack, .allHands)
    }

    func testDailySeedMatchesKnownFNVValue() {
        // A literal fixture catches accidentally replacing stable hashing with hashValue.
        let board = BingoGame(pack: .mixed, mode: .daily, date: localDate())
        XCTAssertEqual(board.seed, 17_823_120_016_758_288_381)
    }

    func testDateKeyUsesLocalGregorianCalendarDay() {
        XCTAssertEqual(BingoGame.dateKey(localDate(hour: 0)), "2026-10-26")
        XCTAssertEqual(BingoGame.dateKey(localDate(hour: 23)), "2026-10-26")
        XCTAssertEqual(BingoGame.dateKey(localDate(day: 27)), "2026-10-27")
    }

    func testLineIndicesHaveExpectedStableIDs() {
        XCTAssertEqual(BingoGame.lineIndices.count, 12)
        for row in 0..<5 {
            XCTAssertEqual(BingoGame.lineIndices[row], (0..<5).map { row * 5 + $0 })
        }
        for column in 0..<5 {
            XCTAssertEqual(BingoGame.lineIndices[5 + column], (0..<5).map { $0 * 5 + column })
        }
        XCTAssertEqual(BingoGame.lineIndices[10], [0, 6, 12, 18, 24])
        XCTAssertEqual(BingoGame.lineIndices[11], [4, 8, 12, 16, 20])
        XCTAssertEqual(Set(BingoGame.lineIndices).count, 12)
    }

    func testEveryRowColumnAndDiagonalCanWinIndependently() {
        for line in BingoGame.lineIndices.indices {
            var board = game()
            XCTAssertEqual(mark(BingoGame.lineIndices[line], in: &board), [line])
            XCTAssertEqual(board.completedLines, [line])
            XCTAssertEqual(board.awardedLines, [line])
            XCTAssertEqual(board.winningTileIndices, Set(BingoGame.lineIndices[line]))
            XCTAssertTrue(board.hasWon)
            XCTAssertEqual(board.nearestLineCount, 5)
        }
    }

    func testToggleMarksAndUnmarksAnOrdinaryTile() {
        var board = game()
        XCTAssertEqual(board.toggle(index: 0), [])
        XCTAssertTrue(board.tiles[0].isMarked)
        XCTAssertEqual(board.markedCount, 1)
        XCTAssertEqual(board.toggle(index: 0), [])
        XCTAssertFalse(board.tiles[0].isMarked)
        XCTAssertEqual(board.markedCount, 0)
    }

    func testFreeAndInvalidIndicesAreNoOps() {
        var board = game()
        let original = board
        for index in [12, -1, 25, Int.min, Int.max] {
            XCTAssertEqual(board.toggle(index: index), [])
            XCTAssertEqual(board, original)
        }
    }

    func testNearestLineCountIncludesTheFreeSquare() {
        var board = game()
        _ = mark([10, 11, 13], in: &board)
        XCTAssertEqual(board.markedCount, 3)
        XCTAssertEqual(board.nearestLineCount, 4)
        XCTAssertTrue(board.completedLines.isEmpty)
    }

    func testOneTapCanAwardTwoLines() {
        var board = game()
        _ = mark([1, 2, 3, 4, 5, 10, 15, 20], in: &board)
        XCTAssertEqual(board.awardedLines, [])
        XCTAssertEqual(board.toggle(index: 0), [0, 5])
        XCTAssertEqual(board.completedLines, [0, 5])
        XCTAssertEqual(board.winningTileIndices.count, 9)
    }

    func testUnmarkingRemovesHighlightsButDoesNotFarmAwards() {
        var board = game()
        _ = mark(BingoGame.lineIndices[0], in: &board)
        XCTAssertEqual(board.toggle(index: 0), [])
        XCTAssertTrue(board.completedLines.isEmpty)
        XCTAssertTrue(board.winningTileIndices.isEmpty)
        XCTAssertTrue(board.hasWon)
        XCTAssertEqual(board.awardedLines, [0])
        XCTAssertEqual(board.toggle(index: 0), [])
        XCTAssertEqual(board.completedLines, [0])
        XCTAssertEqual(board.awardedLines, [0])
    }

    func testFullBoardAwardsAllTwelveLinesExactlyOnce() {
        var board = game()
        XCTAssertEqual(mark(Array(0..<25), in: &board), Set(0..<12))
        XCTAssertEqual(board.completedLines, Set(0..<12))
        XCTAssertEqual(board.awardedLines, Set(0..<12))
        XCTAssertEqual(board.winningTileIndices, Set(0..<25))
        XCTAssertEqual(board.markedCount, 24)
        for index in 0..<25 {
            XCTAssertEqual(board.toggle(index: index), [])
        }
        XCTAssertEqual(mark(Array(0..<25), in: &board), [])
        XCTAssertEqual(board.awardedLines, Set(0..<12))
    }

    func testGameCodableRoundTripPreservesProgressAndAwards() throws {
        var board = game()
        board.activeSeconds = 47.5
        _ = mark(BingoGame.lineIndices[10], in: &board)
        _ = board.toggle(index: 0)
        let restored = try JSONDecoder().decode(BingoGame.self, from: JSONEncoder().encode(board))
        XCTAssertEqual(restored, board)
        XCTAssertTrue(restored.isValid)
        var resumed = restored
        XCTAssertEqual(resumed.toggle(index: 0), [])
    }

    func testValidationRejectsMissingDuplicateOrOutOfRangePositions() {
        var missing = game()
        missing.tiles.removeLast()
        XCTAssertFalse(missing.isValid)
        var duplicate = game()
        duplicate.tiles[0].index = 1
        XCTAssertFalse(duplicate.isValid)
        var invalid = game()
        invalid.tiles[0].index = 25
        XCTAssertFalse(invalid.isValid)
    }

    func testValidationRejectsDuplicateAndEmptyPhrases() {
        var duplicate = game()
        duplicate.tiles[0].phrase = duplicate.tiles[1].phrase
        XCTAssertFalse(duplicate.isValid)
        var empty = game()
        empty.tiles[0].phrase = " \n "
        XCTAssertFalse(empty.isValid)
    }

    func testValidationRejectsIncorrectFreeSquare() {
        var board = game()
        board.tiles[12].isMarked = false
        XCTAssertFalse(board.isValid)
        board = game()
        board.tiles[12].isFree = false
        XCTAssertFalse(board.isValid)
        board = game()
        board.tiles[0].isFree = true
        XCTAssertFalse(board.isValid)
        board = game()
        board.tiles[12].phrase = "not free"
        XCTAssertFalse(board.isValid)
    }

    func testValidationRejectsInvalidTimeAndAwardIDs() {
        for seconds in [-1, Double.infinity, Double.nan] {
            var board = game()
            board.activeSeconds = seconds
            XCTAssertFalse(board.isValid)
        }
        var board = game()
        board.awardedLines = [12]
        XCTAssertFalse(board.isValid)
    }

    func testRestoredTileOrderingDoesNotChangeIndexSemantics() {
        var board = game()
        board.tiles.reverse()
        XCTAssertTrue(board.isValid)
        for index in BingoGame.lineIndices[0] { board.toggle(index: index) }
        XCTAssertEqual(board.completedLines, [0])
        XCTAssertEqual(board.winningTileIndices, Set(0..<5))
    }

    func testStatisticsStartAtZeroAndRecordBoards() {
        var statistics = GameStatistics()
        XCTAssertEqual(statistics.boardsPlayed, 0)
        XCTAssertEqual(statistics.boardsWon, 0)
        XCTAssertEqual(statistics.totalLines, 0)
        XCTAssertNil(statistics.bestSeconds)
        statistics.recordStart()
        statistics.recordStart()
        XCTAssertEqual(statistics.boardsPlayed, 2)
    }

    func testStatisticsCountMultipleLinesButOnlyFirstWinAndBestTime() {
        var statistics = GameStatistics()
        statistics.record(newLines: [0, 5], firstWin: true, seconds: 60)
        XCTAssertEqual(statistics.boardsWon, 1)
        XCTAssertEqual(statistics.totalLines, 2)
        XCTAssertEqual(statistics.bestSeconds, 60)
        statistics.record(newLines: [10], firstWin: false, seconds: 5)
        XCTAssertEqual(statistics.boardsWon, 1)
        XCTAssertEqual(statistics.totalLines, 3)
        XCTAssertEqual(statistics.bestSeconds, 60)
        statistics.record(newLines: [1], firstWin: true, seconds: 90)
        XCTAssertEqual(statistics.bestSeconds, 60)
        statistics.record(newLines: [2], firstWin: true, seconds: 40)
        XCTAssertEqual(statistics.bestSeconds, 40)
        XCTAssertEqual(statistics.boardsWon, 3)
    }

    func testStatisticsDoNotChangeForAnEmptyNonwinningEvent() {
        var statistics = GameStatistics()
        statistics.record(newLines: [], firstWin: false, seconds: 5)
        XCTAssertEqual(statistics, GameStatistics())
    }

    func testStatisticsIgnoreInvalidTimesForBestButKeepWinCount() {
        var statistics = GameStatistics()
        for seconds in [-1, Double.infinity, Double.nan] {
            statistics.record(newLines: [0], firstWin: true, seconds: seconds)
        }
        XCTAssertEqual(statistics.boardsWon, 3)
        XCTAssertEqual(statistics.totalLines, 3)
        XCTAssertNil(statistics.bestSeconds)
        statistics.record(newLines: [1], firstWin: true, seconds: 0)
        XCTAssertEqual(statistics.bestSeconds, 0)
    }

    func testStatisticsCodableRoundTrip() throws {
        var statistics = GameStatistics()
        statistics.recordStart()
        statistics.record(newLines: [1, 2], firstWin: true, seconds: 34.5)
        let restored = try JSONDecoder().decode(GameStatistics.self, from: JSONEncoder().encode(statistics))
        XCTAssertEqual(restored, statistics)
    }
}
