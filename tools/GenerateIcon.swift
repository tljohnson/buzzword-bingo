import AppKit

// Reproducible original artwork, rendered with macOS system frameworks only.
let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
NSColor(red: 0.97, green: 0.96, blue: 0.92, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
let ink = NSColor(red: 0.14, green: 0.19, blue: 0.17, alpha: 1)
let coral = NSColor(red: 0.89, green: 0.24, blue: 0.18, alpha: 1)
let mint = NSColor(red: 0.72, green: 0.90, blue: 0.72, alpha: 1)
let heading: NSString = "BINGO."
heading.draw(at: NSPoint(x: 115, y: 740), withAttributes: [.font: NSFont.systemFont(ofSize: 155, weight: .black), .foregroundColor: ink, .kern: -7])
for row in 0..<3 {
    for column in 0..<3 {
        let rect = NSRect(x: 123 + column * 265, y: 122 + row * 190, width: 246, height: 171)
        let selected = row == column
        (selected ? coral : mint).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 36, yRadius: 36).fill()
        if selected {
            let check = NSBezierPath()
            check.move(to: NSPoint(x: rect.minX + 77, y: rect.minY + 88))
            check.line(to: NSPoint(x: rect.minX + 110, y: rect.minY + 55))
            check.line(to: NSPoint(x: rect.minX + 172, y: rect.minY + 119))
            check.lineWidth = 18
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            NSColor.white.setStroke()
            check.stroke()
        }
    }
}
image.unlockFocus()
let source = NSBitmapImageRep(data: image.tiffRepresentation!)!.cgImage!
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.draw(source, in: CGRect(x: 0, y: 0, width: size, height: size))
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
let destination = CommandLine.arguments.dropFirst().first ?? "BuzzwordBingo/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination))
