// Draws the app icon: the waveform from the site's favicon — four bars, the
// shape of a voice, which is what timbre means — on a rounded tile, in the
// identity's colours (GDR-0017). One master at 1024 pt; tools/make-icon-set.sh
// turns it into the asset catalogue's sizes.
//
//   swift tools/app-icon.swift <variant> <out.png> [size]
//
// Variants: charcoal (rainbow bars on the case colour), mint (ink bars on the
// dictation key), paper (rainbow bars on keycap grey), petrol (the favicon as
// it was). Drawn in code so it never drifts from the palette.

import AppKit

let args = CommandLine.arguments.dropFirst()
let variant = args.first ?? "charcoal"
let out = args.dropFirst().first ?? "AppIcon.png"
let side = Double(args.dropFirst(2).first ?? "1024") ?? 1024

func rgb(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
    NSColor(srgbRed: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, alpha: 1)
}
let ink = rgb(36, 35, 34)
let paper = rgb(242, 241, 237)
let charcoal = rgb(46, 45, 43)
let mint = rgb(80, 200, 160)
let rainbow = [rgb(228, 87, 63), rgb(240, 200, 70), rgb(80, 200, 160), rgb(80, 170, 220)]

let tile: NSColor
let bars: [NSColor]
switch variant {
case "mint": tile = mint; bars = Array(repeating: ink, count: 4)
case "paper": tile = paper; bars = rainbow
case "petrol": tile = rgb(14, 115, 112); bars = Array(repeating: rgb(247, 248, 249), count: 4)
default: tile = charcoal; bars = rainbow
}

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(side), pixelsHigh: Int(side),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
else { fatalError("no bitmap") }
rep.size = NSSize(width: side, height: side)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS icon geometry: the tile sits inside a transparent margin, corner
// radius about 22.4% of the tile — the system draws the shadow.
let unit = side / 1024
let inset = 100 * unit
let tileSide = side - inset * 2
let radius = tileSide * 0.224
tile.setFill()
NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: tileSide, height: tileSide), xRadius: radius, yRadius: radius).fill()

// The favicon's bars, on its 32-unit grid: centres and heights, stroke 2.6.
let grid = tileSide / 32
let centres: [Double] = [8, 13.3, 18.6, 24]
let heights: [Double] = [6, 14, 9, 3]
let width = 2.6 * grid
for (i, cx) in centres.enumerated() {
    let h = heights[i] * grid + width  // round caps extend a stroke by half its width each end
    let x = inset + cx * grid - width / 2
    let y = inset + tileSide / 2 - h / 2
    bars[i].setFill()
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: h), xRadius: width / 2, yRadius: width / 2).fill()
}

NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("no png") }
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out) (\(variant), \(Int(side)) px)")
