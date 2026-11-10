// Draws the disk image window background: an arrow from the app to the
// Applications folder, and the steps for opening the app the first time.
// Usage: make-dmg-background <output.png> <scale>   (scale 1 or 2)
//
// Finder draws the icon labels itself, white in dark mode and black in light
// mode, so the band behind the icons is a mid blue that keeps both readable.
// Icon centers (set in dmg-settings.py) are app (165, 150), Applications (495, 150).
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let scale = CGFloat(Double(CommandLine.arguments[2]) ?? 1)
let width: CGFloat = 660
let height: CGFloat = 460
let bandHeight: CGFloat = 262

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: width, height: height)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

/// A rectangle measured from the top, like Finder's icon positions.
func box(_ x: CGFloat, _ top: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
    NSRect(x: x, y: height - top - h, width: w, height: h)
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

/// Text with **bold** spans.
func styled(_ text: String, size: CGFloat, color: NSColor, align: NSTextAlignment = .left) -> NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = align
    paragraph.lineSpacing = 2
    let result = NSMutableAttributedString()
    for (i, part) in text.components(separatedBy: "**").enumerated() {
        let font = i % 2 == 1 ? NSFont.systemFont(ofSize: size, weight: .semibold) : NSFont.systemFont(ofSize: size)
        result.append(NSAttributedString(string: part, attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
        ]))
    }
    return result
}

// Blue band behind the icons.
NSGradient(colors: [rgb(78, 140, 240), rgb(46, 104, 222)])!
    .draw(in: box(0, 0, width, bandHeight), angle: -90)

let white = NSColor.white
NSAttributedString(string: "Install macos-dockwake", attributes: [
    .font: NSFont.systemFont(ofSize: 22, weight: .bold), .foregroundColor: white,
    .paragraphStyle: { let p = NSMutableParagraphStyle(); p.alignment = .center; return p }(),
]).draw(in: box(0, 22, width, 30))
styled("Drag the app onto the Applications folder.", size: 14, color: rgb(255, 255, 255, 0.88), align: .center)
    .draw(in: box(0, 54, width, 20))

// Arrow between the two icons.
let arrowY = height - 150
let shaft = NSBezierPath()
shaft.move(to: NSPoint(x: 258, y: arrowY))
shaft.line(to: NSPoint(x: 388, y: arrowY))
shaft.lineWidth = 7
shaft.lineCapStyle = .round
rgb(255, 255, 255, 0.92).setStroke()
shaft.stroke()
let head = NSBezierPath()
head.move(to: NSPoint(x: 410, y: arrowY))
head.line(to: NSPoint(x: 384, y: arrowY + 17))
head.line(to: NSPoint(x: 384, y: arrowY - 17))
head.close()
rgb(255, 255, 255, 0.92).setFill()
head.fill()

// Light panel with the first-launch steps.
rgb(246, 247, 250).setFill()
box(0, bandHeight, width, height - bandHeight).fill()

let dark = rgb(29, 29, 31)
let body = rgb(60, 60, 67)
styled("**The first time you open it**", size: 15, color: dark).draw(in: box(40, bandHeight + 18, 580, 22))

let steps = [
    "macOS says it can't verify the app. Click **Done**.",
    "Open **System Settings > Privacy & Security** and scroll down.",
    "Click **Open Anyway** next to macos-dockwake, then **Open**.",
]
for (i, step) in steps.enumerated() {
    let top = bandHeight + 50 + CGFloat(i) * 28
    let circle = NSBezierPath(ovalIn: box(40, top, 20, 20))
    rgb(46, 104, 222).setFill()
    circle.fill()
    styled("**\(i + 1)**", size: 12, color: white, align: .center).draw(in: box(40, top + 2, 20, 16))
    styled(step, size: 14, color: body).draw(in: box(72, top + 1, 560, 20))
}

styled(
    "You only do this once. macOS asks because macos-dockwake isn't signed with a paid Apple developer account.",
    size: 12, color: rgb(110, 110, 115)
).draw(in: box(40, bandHeight + 142, 580, 36))

NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: output)
