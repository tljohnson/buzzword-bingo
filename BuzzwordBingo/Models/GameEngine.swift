import Foundation

enum PhrasePack: String, CaseIterable, Codable, Identifiable {
    case mixed
    case allHands
    case techTalk
    case strategy

    var id: String { rawValue }

    var name: String {
        switch self {
        case .mixed: return "The Remix"
        case .allHands: return "All Hands"
        case .techTalk: return "Tech Talk"
        case .strategy: return "Strategy Session"
        }
    }

    var subtitle: String {
        switch self {
        case .mixed: return "A little bit of every meeting."
        case .allHands: return "Big updates. Familiar phrases."
        case .techTalk: return "Ship it, scale it, circle back."
        case .strategy: return "Think big. Mark the buzzwords."
        }
    }

    var symbol: String {
        switch self {
        case .mixed: return "shuffle"
        case .allHands: return "person.3.fill"
        case .techTalk: return "terminal.fill"
        case .strategy: return "chart.line.uptrend.xyaxis"
        }
    }

    var phrases: [String] {
        switch self {
        case .mixed:
            var seen = Set<String>()
            return [Self.allHands, .techTalk, .strategy].flatMap(\.phrases)
                .filter { seen.insert($0).inserted }
        case .allHands:
            return [
                "Can everyone see my screen?", "You're on mute", "Let's get started",
                "Happy Monday", "Quick housekeeping", "A lot to unpack", "Circle back",
                "Take this offline", "Touch base", "Open the floor", "Any questions?",
                "Thanks for joining", "Can you hear me?", "Next slide, please",
                "At a high level", "Moving forward", "Team effort", "All hands on deck",
                "Company culture", "Employee engagement", "Work-life balance",
                "Exciting announcement", "Record quarter", "Shout-out to the team",
                "Thank you for your patience", "Let's double-click on that",
                "Keep the momentum", "On the same page", "In the loop", "Quick update",
                "Before we wrap up", "Give you some time back", "Hard stop",
                "Parking lot that", "Follow up by email", "The new normal",
                "Cross-functional collaboration", "Our people are our strength",
                "Stay tuned", "Put it in the chat", "Raise your virtual hand",
                "Sorry, I was on mute", "We've got a packed agenda", "One more thing",
                "Celebrate the wins", "Over to you", "Bandwidth", "Action items"
            ]
        case .techTalk:
            return [
                "Ship it", "Technical debt", "Move fast", "It works on my machine",
                "Edge case", "Scalability", "Single source of truth", "API-first",
                "Cloud native", "Microservices", "Containerize it", "Zero downtime",
                "Backward compatible", "Breaking change", "Feature flag", "Hotfix",
                "Code freeze", "Pull request", "Code review", "Unit tests",
                "Integration tests", "Continuous delivery", "Deployment pipeline",
                "Sprint planning", "Story points", "The backlog", "Tech stack",
                "Refactor", "Race condition", "Cache invalidation", "Observability",
                "Root cause", "Reproduce the bug", "Production-ready", "Rollback",
                "Latency", "Throughput", "Load balancing", "Rate limiting",
                "Authentication", "Dependency update", "Security review",
                "End-to-end encryption", "Developer experience", "Rubber duck",
                "Let me share my terminal", "Off-by-one error", "There's a ticket for that"
            ]
        case .strategy:
            return [
                "Low-hanging fruit", "Move the needle", "North star", "Win-win",
                "Synergy", "Leverage", "Paradigm shift", "Thought leadership",
                "Value proposition", "Core competency", "Strategic alignment",
                "Go-to-market", "Product-market fit", "Customer journey",
                "Stakeholder buy-in", "Key deliverables", "Success metrics",
                "Return on investment", "Competitive advantage", "Market landscape",
                "Blue-sky thinking", "Outside the box", "Deep dive", "Level set",
                "Boil the ocean", "Peel the onion", "Run it up the flagpole",
                "Disrupt the market", "Growth mindset", "Digital transformation",
                "Operational excellence", "Best-in-class", "Best practices",
                "Holistic approach", "Ecosystem", "Pivot", "Quick wins",
                "Long-term vision", "Strategic roadmap", "Value-add", "KPIs",
                "OKRs", "Resource allocation", "Risk appetite", "Future-proof",
                "Think at scale", "Connect the dots", "Art of the possible"
            ]
        }
    }
}

enum GameMode: String, Codable, CaseIterable {
    case quick
    case daily
}

struct BingoTile: Codable, Equatable, Identifiable {
    var index: Int
    var phrase: String
    var isMarked: Bool
    var isFree: Bool

    var id: Int { index }
}

struct BingoGame: Codable, Equatable {
    var id: UUID
    var mode: GameMode
    var pack: PhrasePack
    var seed: UInt64
    var tiles: [BingoTile]
    var createdAt: Date
    var activeSeconds: Double = 0
    var awardedLines: Set<Int> = []
    var hasWon: Bool = false

    init(pack: PhrasePack, mode: GameMode, date: Date = Date(), seed: UInt64? = nil) {
        self.id = UUID()
        self.mode = mode
        self.pack = pack
        self.createdAt = date
        self.seed = seed ?? (mode == .daily
            ? Self.stableSeed("\(Self.dateKey(date))|\(pack.rawValue)")
            : UInt64.random(in: UInt64.min...UInt64.max))

        var generator = SeededGenerator(state: self.seed)
        var phrases = pack.phrases
        // An explicit Fisher-Yates implementation keeps boards stable across Swift releases.
        for upper in stride(from: phrases.count - 1, through: 1, by: -1) {
            let selected = Int(generator.next() % UInt64(upper + 1))
            phrases.swapAt(upper, selected)
        }
        var phraseIndex = 0
        self.tiles = (0..<25).map { index in
            if index == 12 {
                return BingoTile(index: index, phrase: "FREE", isMarked: true, isFree: true)
            }
            defer { phraseIndex += 1 }
            return BingoTile(index: index, phrase: phrases[phraseIndex], isMarked: false, isFree: false)
        }
    }

    static func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static let lineIndices: [[Int]] = {
        let rows = (0..<5).map { row in (0..<5).map { row * 5 + $0 } }
        let columns = (0..<5).map { column in (0..<5).map { $0 * 5 + column } }
        return rows + columns + [[0, 6, 12, 18, 24], [4, 8, 12, 16, 20]]
    }()

    var completedLines: Set<Int> {
        let marked = Set(tiles.filter(\.isMarked).map(\.index))
        return Set(Self.lineIndices.indices.filter { line in
            Self.lineIndices[line].allSatisfy { marked.contains($0) }
        })
    }

    var winningTileIndices: Set<Int> {
        Set(completedLines.flatMap { Self.lineIndices[$0] })
    }

    var markedCount: Int {
        tiles.filter { $0.isMarked && !$0.isFree }.count
    }

    var nearestLineCount: Int {
        let marked = Set(tiles.filter(\.isMarked).map(\.index))
        return Self.lineIndices.map { line in line.filter { marked.contains($0) }.count }.max() ?? 0
    }

    var isValid: Bool {
        guard tiles.count == 25,
              Set(tiles.map(\.index)) == Set(0..<25),
              Set(tiles.map(\.phrase)).count == 25,
              tiles.allSatisfy({ !$0.phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              tiles.filter(\.isFree).count == 1,
              let center = tiles.first(where: { $0.index == 12 }),
              center.isFree, center.isMarked, center.phrase == "FREE",
              activeSeconds.isFinite, activeSeconds >= 0,
              awardedLines.isSubset(of: Set(Self.lineIndices.indices)) else { return false }
        return true
    }

    @discardableResult
    mutating func toggle(index: Int) -> Set<Int> {
        guard let position = tiles.firstIndex(where: { $0.index == index }),
              (0..<25).contains(index), !tiles[position].isFree else { return [] }
        tiles[position].isMarked.toggle()
        let newLines = completedLines.subtracting(awardedLines)
        awardedLines.formUnion(newLines)
        if !newLines.isEmpty { hasWon = true }
        return newLines
    }

    private static func stableSeed(_ key: String) -> UInt64 {
        // FNV-1a is deliberately independent of Swift's per-process randomized hashing.
        key.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }
}

private struct SeededGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        // SplitMix64 also supports zero as a seed without a degenerate sequence.
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

struct GameStatistics: Codable, Equatable {
    var boardsPlayed: Int = 0
    var boardsWon: Int = 0
    var totalLines: Int = 0
    var bestSeconds: Double? = nil

    mutating func recordStart() {
        boardsPlayed += 1
    }

    mutating func record(newLines: Set<Int>, firstWin: Bool, seconds: Double) {
        totalLines += newLines.count
        guard firstWin else { return }
        boardsWon += 1
        guard seconds.isFinite, seconds >= 0 else { return }
        bestSeconds = min(bestSeconds ?? seconds, seconds)
    }
}
