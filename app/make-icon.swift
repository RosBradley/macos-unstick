// Draws the 1024x1024 app icon: white restart arrows above a Dock shelf of
// four colored apps, on a blue rounded square.
// Usage: make-icon <output.png>
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let side = 1024

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}

func rounded(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double) -> NSBezierPath {
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: r, yRadius: r)
}

func withShadow(blur: Double, dy: Double, alpha: Double, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: dy)
    shadow.shadowColor = rgb(0, 0, 0, alpha)
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Apple's icon grid leaves a 100 px margin around an 824 px rounded square.
let tile = rounded(100, 100, 824, 824, 185)
withShadow(blur: 28, dy: -12, alpha: 0.35) { rgb(0, 0, 0).setFill(); tile.fill() }
NSGradient(colors: [rgb(0.20, 0.78, 0.95), rgb(0.05, 0.36, 0.80)])!.draw(in: tile, angle: -90)

NSGraphicsContext.saveGraphicsState()
tile.addClip()

// Soft glow behind the arrows.
let center = NSPoint(x: 512, y: 600)
NSGradient(colors: [rgb(1, 1, 1, 0.35), rgb(1, 1, 1, 0)])!
    .draw(fromCenter: center, radius: 0, toCenter: center, radius: 360, options: [])

// White restart arrows.
let config = NSImage.SymbolConfiguration(pointSize: 330, weight: .semibold)
if let symbol = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)?
    .withSymbolConfiguration(config)
{
    let size = symbol.size
    let white = NSImage(size: size, flipped: false) { rect in
        symbol.draw(in: rect)
        NSColor.white.set()
        rect.fill(using: .sourceAtop)
        return true
    }
    withShadow(blur: 20, dy: -10, alpha: 0.25) {
        white.draw(in: NSRect(
            x: center.x - size.width / 2, y: center.y - size.height / 2,
            width: size.width, height: size.height))
    }
}

// Dock shelf with four apps.
let shelf = rounded(190, 190, 644, 130, 50)
withShadow(blur: 16, dy: -6, alpha: 0.25) { rgb(1, 1, 1, 0.92).setFill(); shelf.fill() }
let apps = [rgb(1.0, 0.45, 0.35), rgb(1.0, 0.75, 0.20), rgb(0.30, 0.80, 0.45), rgb(0.55, 0.40, 0.95)]
for (i, color) in apps.enumerated() {
    color.setFill()
    rounded(252.5 + Double(i) * 145, 213, 84, 84, 22).fill()
}

NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: output)
