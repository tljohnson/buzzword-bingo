import SwiftUI

enum BingoStyle {
    static let coral = Color(red: 0.89, green: 0.24, blue: 0.18)
    static let mint = Color(red: 0.72, green: 0.90, blue: 0.72)
    static let ink = Color.primary
}

struct BoardView: View {
    @Bindable var store: GameStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var sheet: BoardSheet?
    @State private var pendingPack: PhrasePack?
    @State private var showReplace = false
    @State private var celebrationDate: Date?
    @State private var showWin = false

    private var background: Color {
        colorScheme == .dark ? Color(red: 0.10, green: 0.12, blue: 0.11)
            : Color(red: 0.97, green: 0.96, blue: 0.92)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 23) {
                    masthead
                    title
                    modePicker
                    packHeader
                    board(width: min(geometry.size.width - 36, 550))
                    progress
                    newBoardButton
                    footer
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 25)
                .frame(maxWidth: 586)
                .frame(maxWidth: .infinity)
            }
            .background(background)
            .overlay(alignment: .top) {
                if showWin { winBanner.padding(.top, 8).transition(.move(edge: .top).combined(with: .opacity)) }
            }
            .overlay {
                if let celebrationDate { CelebrationView(started: celebrationDate, reduceMotion: reduceMotion) }
            }
        }
        .tint(BingoStyle.coral)
        .sheet(item: $sheet) { item in
            switch item {
            case .settings: SettingsView(store: store)
            case .stats: StatisticsView(statistics: store.statistics)
            case .help: InstructionsView()
            }
        }
        .confirmationDialog("Start a fresh board?", isPresented: $showReplace, titleVisibility: .visible) {
            Button("Start New Board", role: .destructive) {
                store.newBoard(pack: pendingPack ?? store.game.pack)
                pendingPack = nil
                showWin = false
            }
            Button("Keep Playing", role: .cancel) { pendingPack = nil }
        } message: {
            Text("Your current quick-play board will be replaced. Lifetime stats and your daily board are kept.")
        }
        .onChange(of: scenePhase) { _, phase in store.setActive(phase == .active) }
        .onAppear { store.setActive(scenePhase == .active) }
        .onChange(of: store.celebration) { _, _ in
            celebrationDate = Date()
            withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) { showWin = true }
        }
        .task(id: store.celebration) {
            guard store.celebration > 0 else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation { showWin = false }
            celebrationDate = nil
        }
        .task {
            // Check rollover even when the app stays open across midnight.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                if scenePhase == .active { store.setActive(true) }
            }
        }
    }

    private var masthead: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.3x3.fill").foregroundStyle(BingoStyle.coral)
                Text("THE MEETING SURVIVAL KIT").font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.1)
            }
            Spacer(minLength: 8)
            Button { sheet = .stats } label: { Image(systemName: "chart.bar.xaxis").frame(width: 40, height: 44) }
                .accessibilityLabel("Lifetime statistics")
                .accessibilityIdentifier("statistics")
            Button { sheet = .settings } label: { Image(systemName: "slider.horizontal.3").frame(width: 40, height: 44) }
                .accessibilityLabel("Sound and haptic settings")
                .accessibilityIdentifier("settings")
        }
        .foregroundStyle(BingoStyle.ink)
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text("Buzzword").foregroundStyle(BingoStyle.ink)
                Text("bingo.").foregroundStyle(BingoStyle.coral)
            }
            .font(.system(size: 43, weight: .black, design: .rounded))
            .tracking(-2)
            .minimumScaleFactor(0.55)
            .lineLimit(1)
            .accessibilityElement(children: .combine)
            Text("Less scrolling. More \"synergy.\"")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var modePicker: some View {
        HStack(spacing: 5) {
            modeButton(.quick, label: "Free play", icon: "shuffle")
            modeButton(.daily, label: "Daily board", icon: "sun.max")
        }
        .padding(5)
        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 18))
    }

    private func modeButton(_ mode: GameMode, label: String, icon: String) -> some View {
        Button {
            store.selectMode(mode)
            showWin = false
        } label: {
            Label(label, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 42)
                .foregroundStyle(store.mode == mode ? (colorScheme == .dark ? Color.black : Color.white) : .primary)
                .background {
                    if store.mode == mode {
                        RoundedRectangle(cornerRadius: 13).fill(colorScheme == .dark ? Color.white : Color(red: 0.14, green: 0.19, blue: 0.17))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(store.mode == mode ? .isSelected : [])
        .accessibilityIdentifier(mode == .quick ? "mode-quick" : "mode-daily")
    }

    private var packHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.mode == .daily ? Date().formatted(.dateTime.month(.wide).day()).uppercased() : "TODAY'S AGENDA")
                    .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(.secondary)
                if store.mode == .quick {
                    Menu {
                        ForEach(PhrasePack.allCases) { pack in
                            Button { requestBoard(pack: pack) } label: {
                                Label(pack.name, systemImage: pack.symbol)
                            }
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Text(store.game.pack.name).font(.headline)
                            Image(systemName: "chevron.down").font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.primary).frame(minHeight: 28)
                    }
                    .accessibilityLabel("Phrase pack: \(store.game.pack.name). Choose a pack")
                } else {
                    Text("The daily stand-up").font(.headline)
                }
            }
            Spacer()
            Text("\(store.game.markedCount)/24\nHEARD")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(BingoStyle.mint.opacity(colorScheme == .dark ? 0.14 : 0.55), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("\(store.game.markedCount) of 24 phrases heard")
                .accessibilityIdentifier("heard-count")
        }
    }

    private func board(width: CGFloat) -> some View {
        let gap: CGFloat = 6
        let tileWidth = max(44, (width - 4 * gap) / 5)
        return VStack(spacing: 8) {
            HStack(spacing: gap) {
                ForEach(Array("BINGO"), id: \.self) { letter in
                    Text(String(letter))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(2).frame(maxWidth: .infinity)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityHidden(true)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: 5), spacing: gap) {
                ForEach(store.game.tiles.sorted { $0.index < $1.index }) { tile in
                    BingoTileView(tile: tile, winning: store.game.winningTileIndices.contains(tile.index),
                                  minimumHeight: tileWidth * 1.18) {
                        let previous = store.celebration
                        withAnimation(reduceMotion ? nil : .spring(duration: 0.25, bounce: 0.25)) { store.toggle(tile.index) }
                        Feedback.shared.tap(settings: store.settings,
                                            marked: store.game.tiles.first(where: { $0.index == tile.index })?.isMarked ?? false,
                                            won: previous != store.celebration)
                    }
                }
            }
        }
    }

    private var progress: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: store.game.completedLines.isEmpty ? "scope" : "seal.fill")
                .font(.title2).foregroundStyle(BingoStyle.coral)
            VStack(alignment: .leading, spacing: 4) {
                Text(store.game.completedLines.isEmpty ? "Keep your ears open." : "That's a bingo. Nice listening!")
                    .font(.subheadline.weight(.bold))
                Text(store.game.completedLines.isEmpty ? "\(5 - store.game.nearestLineCount) more in your closest line." : "\(store.game.completedLines.count) of 12 lines. Why stop now?")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                ForEach(0..<5) { index in
                    Capsule().fill(index < store.game.nearestLineCount ? BingoStyle.coral : Color.primary.opacity(0.12))
                        .frame(width: 5, height: CGFloat(12 + index * 4))
                }
            }
            .accessibilityHidden(true)
        }
    }

    private var newBoardButton: some View {
        Button {
            if store.mode == .daily { store.selectMode(.quick) }
            else { requestBoard(pack: store.game.pack) }
        } label: {
            HStack {
                Image(systemName: store.mode == .daily ? "arrow.uturn.backward" : "arrow.clockwise")
                Text(store.mode == .daily ? "Back to free play" : "Fresh meeting, fresh board")
                Spacer(minLength: 5)
                Image(systemName: "arrow.right")
            }
            .font(.subheadline.weight(.bold))
            .padding(18)
            .foregroundStyle(.white)
            .background(BingoStyle.coral, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("new-board")
    }

    private var footer: some View {
        HStack(spacing: 5) {
            Image(systemName: "ear")
            Text("Hear it. Tap it. Try not to shout bingo.")
            Spacer(minLength: 0)
            Button { sheet = .help } label: { Image(systemName: "questionmark.circle").frame(width: 44, height: 44) }
                .accessibilityLabel("How to play")
        }
        .font(.system(size: 11)).foregroundStyle(.secondary)
    }

    private var winBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles").font(.title)
            VStack(alignment: .leading, spacing: 3) {
                Text(store.game.markedCount == 24 ? "FULL HOUSE!" : "BINGO. YOU'RE ALIGNED.").font(.headline)
                Text(store.lastLineCount > 1 ? "\(store.lastLineCount) lines in one tap. Big synergy energy." : "A little win for a very long meeting.")
                    .font(.caption)
            }
        }
        .foregroundStyle(.black).padding(18)
        .background(BingoStyle.mint, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 15, y: 6)
        .padding(.horizontal, 16)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("bingo-banner")
    }

    private func requestBoard(pack: PhrasePack) {
        if store.snapshot.quick.markedCount > 0 {
            pendingPack = pack
            showReplace = true
        } else {
            store.newBoard(pack: pack)
            showWin = false
        }
    }
}

private enum BoardSheet: String, Identifiable {
    case settings, stats, help
    var id: String { rawValue }
}

private struct BingoTileView: View {
    let tile: BingoTile
    let winning: Bool
    let minimumHeight: CGFloat
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .caption2) private var textSize: CGFloat = 11

    private var fill: Color {
        if tile.isFree { return BingoStyle.coral }
        if winning { return BingoStyle.mint }
        if tile.isMarked { return colorScheme == .dark ? Color(red: 0.22, green: 0.35, blue: 0.30) : Color(red: 0.81, green: 0.88, blue: 0.80) }
        return colorScheme == .dark ? Color.white.opacity(0.055) : Color.white.opacity(0.85)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                if tile.isFree {
                    Image(systemName: "sparkle").font(.system(size: 24, weight: .medium))
                    Text("FREE\nSPACE").font(.system(size: textSize, weight: .heavy, design: .rounded))
                } else {
                    Text(tile.phrase).font(.system(size: phraseSize, weight: .semibold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    if tile.isMarked {
                        Image(systemName: winning ? "star.fill" : "checkmark").font(.system(size: 10, weight: .black))
                    }
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 3).padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: minimumHeight)
            .foregroundStyle(tile.isFree ? Color.white : (winning ? Color.black : Color.primary))
            .background(fill, in: RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(tile.isMarked && !tile.isFree ? Color.primary.opacity(0.15) : Color.primary.opacity(0.07), lineWidth: 1)
            }
        }
        .buttonStyle(TilePressStyle())
        .disabled(tile.isFree)
        .accessibilityLabel(tile.isFree ? "Free space, always marked" : tile.phrase)
        .accessibilityValue(tile.isFree ? "" : (winning ? "Marked, winning line" : (tile.isMarked ? "Marked" : "Not marked")))
        .accessibilityHint(tile.isFree ? "" : "Double tap to \(tile.isMarked ? "unmark" : "mark") phrase")
        .accessibilityAddTraits(tile.isMarked ? .isSelected : [])
        .accessibilityIdentifier("tile-\(tile.index)")
    }

    private var phraseSize: CGFloat {
        let longest = tile.phrase.split(separator: " ").map(\.count).max() ?? 1
        return textSize * max(0.76, min(1, 9.0 / Double(longest)))
    }
}

private struct TilePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.18), value: configuration.isPressed)
    }
}
