import SwiftUI

struct CelebrationView: View {
    let started: Date
    let reduceMotion: Bool
    private let colors: [Color] = [.pink, .orange, .yellow, .mint, .cyan, .purple]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(started)
            if elapsed >= 0 && elapsed < 3.5 && !reduceMotion {
                Canvas { context, size in
                    for index in 0..<130 {
                        let n = Double(index)
                        let velocityX = sin(n * 17.31) * size.width * 0.9
                        let velocityY = -210 - Double(index % 11) * 34
                        let x = size.width / 2 + velocityX * elapsed
                        let y = size.height * 0.4 + velocityY * elapsed + 230 * elapsed * elapsed
                        var particle = context
                        particle.opacity = max(0, min(1, 3.5 - elapsed))
                        particle.translateBy(x: x, y: y)
                        particle.rotate(by: .degrees(n * 29 + elapsed * 220))
                        particle.fill(Path(roundedRect: CGRect(x: -4, y: -7, width: 8, height: 14),
                                           cornerRadius: 2), with: .color(colors[index % colors.count]))
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
