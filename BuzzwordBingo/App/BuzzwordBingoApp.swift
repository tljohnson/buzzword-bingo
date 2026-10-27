import SwiftUI

@main
struct BuzzwordBingoApp: App {
    @State private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            BoardView(store: store)
        }
    }
}
