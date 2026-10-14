// Draws the site's Open Graph image — the card LinkedIn, Slack and iMessage
// show when the link is shared — in the site's identity: keycap grey,
// charcoal ink, the rainbow stripe, the mark, and Nunito (GDR-0020), loaded
// from the same file the site serves.
//
//   swift tools/og-image.swift web/static/og.png
//
// Drawn rather than screenshotted so it stays sharp at 2× and never goes
// stale against a real window.

import AppKit

let out = CommandLine.arguments.dropFirst().first ?? "og.png"
let width = 1200.0
let height = 630.0
let scale = 2.0

// Nunito, from the repo, registered for this process only.
let fontFile = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "web/static/fonts/Nunito-Variable.ttf")
CTFontManagerRegisterFontsForURL(fontFile as CFURL, .process, nil)

func rgb(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
    NSColor(srgbRed: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, alpha: 1)
}
let paper = rgb(242, 241, 237)
let ink = rgb(36, 35, 34)
let muted = rgb(118, 116, 110)
let caseColor = rgb(46, 45, 43)
let rainbow = [rgb(228, 87, 63), rgb(240, 140, 60), rgb(240, 200, 70), rgb(80, 200, 160), rgb(80, 170, 220), rgb(160, 120, 220)]

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
else { fatalError("no bitmap") }
rep.size = NSSize(width: width, height: height)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

paper.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()

// The stripe, along the top.
let stripeHeight = 12.0
let stripeWidth = width / Double(rainbow.count)
for (i, color) in rainbow.enumerated() {
    color.setFill()
    NSRect(x: Double(i) * stripeWidth, y: height - stripeHeight, width: stripeWidth + 1, height: stripeHeight).fill()
}

func nunito(_ size: Double, weight: Double) -> NSFont {
    let descriptor = NSFontDescriptor(fontAttributes: [
        .family: "Nunito",
        .variation: [2003265652: weight],  // the 'wght' axis
    ])
    return NSFont(descriptor: descriptor, size: size) ?? NSFont.systemFont(ofSize: size, weight: .bold)
}
let mono = NSFont(name: "Menlo-Regular", size: 21) ?? NSFont.monospacedSystemFont(ofSize: 21, weight: .regular)

func draw(_ text: String, at point: NSPoint, font: NSFont, color: NSColor, kern: Double = 0) {
    NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .kern: kern]).draw(at: point)
}
func size(of text: String, font: NSFont, kern: Double = 0) -> NSSize {
    NSAttributedString(string: text, attributes: [.font: font, .kern: kern]).size()
}

// The mark, large, on the right: the favicon's four bars on a charcoal tile.
func drawMark(x: Double, y: Double, side: Double) {
    caseColor.setFill()
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: side, height: side), xRadius: side * 7 / 32, yRadius: side * 7 / 32).fill()
    let grid = side / 32
    let barWidth = 3.0 * grid
    for (i, cx) in [8.0, 13.3, 18.6, 24.0].enumerated() {
        let h = [6.0, 14.0, 9.0, 3.0][i] * grid + barWidth
        [rainbow[0], rainbow[2], rainbow[3], rainbow[4]][i].setFill()
        NSBezierPath(roundedRect: NSRect(x: x + cx * grid - barWidth / 2, y: y + side / 2 - h / 2, width: barWidth, height: h), xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
    }
}
drawMark(x: 880, y: 200, side: 260)

// The wordmark, as the header shows it: the bare bars beside "timbre".
func drawBars(x: Double, y: Double, height: Double) {
    // The favicon's grid, without the tile: bars span 14 units of height.
    let grid = height / 14
    let barWidth = 3.0 * grid
    for (i, cx) in [0.0, 5.3, 10.6, 16.0].enumerated() {
        let h = [6.0, 14.0, 9.0, 3.0][i] * grid + barWidth
        [rainbow[0], rainbow[2], rainbow[3], rainbow[4]][i].setFill()
        NSBezierPath(roundedRect: NSRect(x: x + cx * grid, y: y + height / 2 - h / 2 + barWidth / 2, width: barWidth, height: h), xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
    }
}
drawBars(x: 84, y: 452, height: 46)
draw("timbre", at: NSPoint(x: 168, y: 430), font: nunito(76, weight: 800), color: ink, kern: -1.5)

// The claim, wrapped by hand, with the rainbow under "never".
let headline = nunito(58, weight: 800)
draw("Dictation that", at: NSPoint(x: 80, y: 318), font: headline, color: ink, kern: -1)
draw("never leaves your Mac.", at: NSPoint(x: 80, y: 250), font: headline, color: ink, kern: -1)
let neverWidth = size(of: "never", font: headline, kern: -1).width
let band = neverWidth / Double(rainbow.count)
NSGraphicsContext.saveGraphicsState()
NSBezierPath(roundedRect: NSRect(x: 80, y: 242, width: neverWidth, height: 8), xRadius: 4, yRadius: 4).addClip()
for (i, color) in rainbow.enumerated() {
    color.setFill()
    NSRect(x: 80 + Double(i) * band, y: 242, width: band + 0.5, height: 8).fill()
}
NSGraphicsContext.restoreGraphicsState()

draw("Zero network requests*   ·   No account   ·   Free   ·   Open source", at: NSPoint(x: 82, y: 170), font: mono, color: muted)
draw("timbre.hugopretorius.dev", at: NSPoint(x: 82, y: 124), font: mono, color: ink)

NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("no png") }
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out) (\(Int(width))×\(Int(height)) at \(Int(scale))×)")
