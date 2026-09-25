// Draws the site's Open Graph image — the card LinkedIn, Slack and iMessage
// show when the link is shared — in the site's retro identity: keycap grey,
// charcoal ink, the rainbow stripe, and the three keys Timbre owns.
//
//   swift tools/og-image.swift web/static/og.png
//
// Drawn rather than screenshotted so it stays sharp at 2× and never goes
// stale against a real window. Fonts are system ones (Helvetica Neue's
// condensed black is the closest installed cousin of the site's Archivo).

import AppKit

let out = CommandLine.arguments.dropFirst().first ?? "og.png"
let width = 1200.0
let height = 630.0
let scale = 2.0

func rgb(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
    NSColor(srgbRed: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, alpha: 1)
}
let paper = rgb(242, 241, 237)
let ink = rgb(36, 35, 34)
let muted = rgb(118, 116, 110)
let capTop = rgb(236, 234, 229)
let capSide = rgb(196, 193, 186)
let caseColor = rgb(46, 45, 43)

extension NSBezierPath {
    func fill(with color: NSColor) {
        color.setFill()
        fill()
    }
}
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
let stripeHeight = 14.0
let stripeWidth = width / Double(rainbow.count)
for (i, color) in rainbow.enumerated() {
    color.setFill()
    NSRect(x: Double(i) * stripeWidth, y: height - stripeHeight, width: stripeWidth + 1, height: stripeHeight).fill()
}

func font(_ name: String, _ size: Double, fallbackWeight: NSFont.Weight = .bold) -> NSFont {
    NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size, weight: fallbackWeight)
}
let display = font("HelveticaNeue-CondensedBlack", 168)
let tagline = font("HelveticaNeue-Bold", 46)
let mono = font("Menlo-Regular", 21, fallbackWeight: .regular)

func draw(_ text: String, at point: NSPoint, font: NSFont, color: NSColor, kern: Double = 0) {
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .kern: kern]
    NSAttributedString(string: text, attributes: attributes).draw(at: point)
}
func size(of text: String, font: NSFont, kern: Double = 0) -> NSSize {
    NSAttributedString(string: text, attributes: [.font: font, .kern: kern]).size()
}

// The mark: the favicon's four bars on a charcoal tile, beside the wordmark.
let markSide = 150.0
let markX = 80.0
let markY = 412.0
NSBezierPath(roundedRect: NSRect(x: markX, y: markY, width: markSide, height: markSide), xRadius: markSide * 7 / 32, yRadius: markSide * 7 / 32).fill(with: caseColor)
let grid = markSide / 32
let barWidth = 2.6 * grid
for (i, cx) in [8.0, 13.3, 18.6, 24.0].enumerated() {
    let h = [6.0, 14.0, 9.0, 3.0][i] * grid + barWidth
    [rainbow[0], rainbow[2], rainbow[3], rainbow[4]][i].setFill()
    NSBezierPath(roundedRect: NSRect(x: markX + cx * grid - barWidth / 2, y: markY + markSide / 2 - h / 2, width: barWidth, height: h), xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
}
draw("Timbre", at: NSPoint(x: markX + markSide + 26, y: 400), font: display, color: ink, kern: -4)
draw("Dictation that never leaves your Mac.", at: NSPoint(x: 80, y: 336), font: tagline, color: ink, kern: -0.5)

// The rainbow under "never".
let neverStart = 80 + size(of: "Dictation that ", font: tagline, kern: -0.5).width
let neverWidth = size(of: "never", font: tagline, kern: -0.5).width
let underlineWidth = neverWidth / Double(rainbow.count)
for (i, color) in rainbow.enumerated() {
    color.setFill()
    NSRect(x: neverStart + Double(i) * underlineWidth, y: 334, width: underlineWidth + 0.5, height: 6).fill()
}

draw("Zero network requests*   ·   No account   ·   Free   ·   Open source", at: NSPoint(x: 82, y: 290), font: mono, color: muted)

// A keyboard peeking up from the bottom: charcoal case, grey caps, the
// three keys in their colours. Unit is 88 pt; the space bar is 5.1 units.
struct Key { let legend: String; let width: Double; let color: NSColor?; let sub: String? }
let keys: [Key] = [
    Key(legend: "fn", width: 1, color: nil, sub: nil),
    Key(legend: "⌃", width: 1, color: nil, sub: nil),
    Key(legend: "⌥", width: 1, color: rainbow[2], sub: "read"),
    Key(legend: "⌘", width: 1.25, color: nil, sub: nil),
    Key(legend: "", width: 5.1, color: nil, sub: nil),
    Key(legend: "⌘", width: 1.25, color: rainbow[1], sub: "command"),
    Key(legend: "⌥", width: 1, color: rainbow[3], sub: "dictate"),
    Key(legend: "◀", width: 1, color: nil, sub: nil),
    Key(legend: "▶", width: 1, color: nil, sub: nil),
]
let unit = 76.0
let gap = 11.0
let boardPadding = 26.0
let rowWidth = keys.reduce(0) { $0 + $1.width * unit } + Double(keys.count - 1) * gap
let boardX = (width - rowWidth) / 2 - boardPadding
let boardY = -40.0
let boardHeight = unit * 2 + gap + boardPadding * 2 + 40
let board = NSBezierPath(roundedRect: NSRect(x: boardX, y: boardY, width: rowWidth + boardPadding * 2, height: boardHeight), xRadius: 26, yRadius: 26)
caseColor.setFill()
board.fill()

func drawKey(_ key: Key, x: Double, y: Double) {
    let w = key.width * unit + (key.width - 1) * gap
    let side = key.color.map { $0.blended(withFraction: 0.32, of: .black) ?? $0 } ?? capSide
    let top = key.color ?? capTop
    side.setFill()
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: unit), xRadius: 14, yRadius: 14).fill()
    let face = NSRect(x: x + 5, y: y + 14, width: w - 10, height: unit - 18)
    let gradient = NSGradient(starting: top, ending: top.blended(withFraction: 0.08, of: .white) ?? top)!
    gradient.draw(in: NSBezierPath(roundedRect: face, xRadius: 11, yRadius: 11), angle: 90)
    let legendFont = font("HelveticaNeue-Medium", key.sub == nil ? 30 : 26)
    let legendSize = size(of: key.legend, font: legendFont)
    let subFont = font("Menlo-Regular", 11, fallbackWeight: .regular)
    let subSize = key.sub.map { size(of: $0, font: subFont) } ?? .zero
    let total = legendSize.height + (key.sub == nil ? 0 : subSize.height)
    let baseline = face.midY - total / 2
    draw(key.legend, at: NSPoint(x: face.midX - legendSize.width / 2, y: baseline + (key.sub == nil ? 0 : subSize.height - 2)), font: legendFont, color: ink)
    if let sub = key.sub {
        draw(sub.uppercased(), at: NSPoint(x: face.midX - subSize.width / 2, y: baseline - 4), font: subFont, color: ink, kern: 1)
    }
}

// Second row (the top of the case): a stretch of plain caps for depth.
let topRow: [Double] = [2.35, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.35]
var x = boardX + boardPadding
let topY = boardY + boardPadding + unit + gap + 40
for w in topRow {
    drawKey(Key(legend: "", width: w, color: nil, sub: nil), x: x, y: topY)
    x += w * unit + (w - 1) * gap + gap
}
x = boardX + boardPadding
let bottomY = boardY + boardPadding + 40
for key in keys {
    drawKey(key, x: x, y: bottomY)
    x += key.width * unit + (key.width - 1) * gap + gap
}

// The address, on its own line under the claims.
draw("timbre.hugopretorius.dev", at: NSPoint(x: 82, y: 244), font: mono, color: ink)

NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("no png") }
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out) (\(Int(width))×\(Int(height)) at \(Int(scale))×)")
