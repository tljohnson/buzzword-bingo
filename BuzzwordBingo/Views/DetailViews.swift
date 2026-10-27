import SwiftUI

struct SettingsView: View {
    @Bindable var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: Binding(get: { store.settings.sound }, set: { store.updateSettings(sound: $0) })) {
                        Label("Satisfying pops", systemImage: "speaker.wave.2")
                    }
                    Toggle(isOn: Binding(get: { store.settings.haptics }, set: { store.updateSettings(haptics: $0) })) {
                        Label("Tiny high fives", systemImage: "hand.tap")
                    }
                } header: { Text("Make it feel good") }
                footer: { Text("Sound respects your iPhone's silent mode. Haptics are available on supported iPhones. For stealth mode, turn both off.") }

                Section("Just you and the buzzwords") {
                    Label("Works completely offline", systemImage: "wifi.slash")
                    Label("No accounts. No ads. No tracking.", systemImage: "hand.raised")
                    Text("Your boards and stats stay on this iPhone. Deleting the app removes them.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Meeting Buzzword Bingo").font(.headline)
                        Text("Built at Novacoast.\nA little levity for your next all-hands.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }.padding(.vertical, 5)
                }
            }
            .navigationTitle("Your preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct StatisticsView: View {
    let statistics: GameStatistics
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    Image(systemName: "trophy.fill").font(.system(size: 48)).foregroundStyle(BingoStyle.coral)
                    Text("Now that's\nmeasurable impact.")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                    Text("Your lifetime meeting highlights. No performance review required.")
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        stat("\(statistics.boardsPlayed)", label: "Boards started", icon: "square.grid.3x3")
                        stat("\(statistics.boardsWon)", label: "Boards with bingo", icon: "seal")
                        stat("\(statistics.totalLines)", label: "Lines celebrated", icon: "sparkles")
                        stat(bestTime, label: "Fastest first bingo", icon: "stopwatch")
                    }
                    Text("Each line counts once per board. Your best time includes only time spent with the app active.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(24)
            }
            .navigationTitle("The highlight reel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var bestTime: String {
        guard let seconds = statistics.bestSeconds, seconds.isFinite, seconds >= 0 else { return "Not yet" }
        let total = Int(min(seconds, 359_999))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func stat(_ value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).foregroundStyle(BingoStyle.coral)
            Text(value).font(.system(size: 31, weight: .black, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .padding(16)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

struct InstructionsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    Text("Let's circle back\nto having fun.")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                    rule("01", title: "Pick your meeting flavor.", detail: "Choose a phrase pack in Free play, or try today's shared daily board. There's a new one every day.")
                    rule("02", title: "Listen for the buzzwords.", detail: "Tap a phrase when someone says it. Tap again to undo. The center square is on the house.")
                    rule("03", title: "Five in a line. Instant glory.", detail: "Complete any row, column, or diagonal for bingo and a confetti break. Keep going for all 12 lines!")
                    rule("04", title: "New meeting? Fresh board.", detail: "Shuffle as often as you like in Free play. Your daily board stays saved separately, and your stats stay with you.")
                    Text("Pro tip: Silent mode is your friend during the CEO's opening remarks.")
                        .font(.subheadline.weight(.semibold)).padding(18)
                        .background(BingoStyle.mint.opacity(0.25), in: RoundedRectangle(cornerRadius: 18))
                }.padding(24)
            }
            .navigationTitle("The very short playbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Let's play") { dismiss() } } }
        }
    }

    private func rule(_ number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Text(number).font(.system(.headline, design: .monospaced)).foregroundStyle(BingoStyle.coral)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
