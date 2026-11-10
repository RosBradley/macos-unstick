import AppKit

/// The menu bar icon: the app icon's restart arrows above a row of four
/// colored dots, its Dock apps. The arrows follow the menu bar's light or dark
/// appearance; the dots keep the app icon's colors.
enum MenuBarIcon {
    static let dotColors = [
        NSColor(srgbRed: 1.00, green: 0.45, blue: 0.35, alpha: 1),
        NSColor(srgbRed: 1.00, green: 0.75, blue: 0.20, alpha: 1),
        NSColor(srgbRed: 0.30, green: 0.80, blue: 0.45, alpha: 1),
        NSColor(srgbRed: 0.55, green: 0.40, blue: 0.95, alpha: 1),
    ]

    static func make() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let symbol = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 11.5, weight: .semibold))

        // The drawing handler runs each time the icon is drawn, with the menu
        // bar's current appearance, so labelColor resolves to black or white.
        let image = NSImage(size: size, flipped: false) { rect in
            if let symbol {
                let s = symbol.size
                let arrows = NSImage(size: s, flipped: false) { r in
                    symbol.draw(in: r)
                    NSColor.labelColor.set()
                    r.fill(using: .sourceAtop)
                    return true
                }
                arrows.draw(in: NSRect(
                    x: (rect.width - s.width) / 2, y: rect.height - s.height - 0.5,
                    width: s.width, height: s.height))
            }

            let dot = 2.8, gap = 1.6
            let rowWidth = dot * 4 + gap * 3
            for (i, color) in dotColors.enumerated() {
                color.setFill()
                let x = (rect.width - rowWidth) / 2 + Double(i) * (dot + gap)
                NSBezierPath(roundedRect: NSRect(x: x, y: 0.8, width: dot, height: dot),
                             xRadius: 0.8, yRadius: 0.8).fill()
            }
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = AppInfo.name
        return image
    }
}
