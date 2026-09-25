// Draws the disk image background in the site's identity (GDR-0017): keycap
// grey, the rainbow stripe along the top, an arrow from the app to
// Applications in the dictation key's mint, one line of instruction. Drawn in
// code so it matches the palette and never goes stale as a binary asset.
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 660, height: 400)
let image = NSImage(size: size)
image.lockFocus()

NSColor(srgbRed: 0.949, green: 0.945, blue: 0.929, alpha: 1).setFill()
NSRect(origin: .zero, size: size).fill()

// The stripe, along the top.
let rainbow: [(CGFloat, CGFloat, CGFloat)] = [(228, 87, 63), (240, 140, 60), (240, 200, 70), (80, 200, 160), (80, 170, 220), (160, 120, 220)]
let band = size.width / CGFloat(rainbow.count)
for (i, c) in rainbow.enumerated() {
    NSColor(srgbRed: c.0 / 255, green: c.1 / 255, blue: c.2 / 255, alpha: 1).setFill()
    NSRect(x: CGFloat(i) * band, y: size.height - 6, width: band + 1, height: 6).fill()
}

let petrol = NSColor(srgbRed: 80 / 255, green: 200 / 255, blue: 160 / 255, alpha: 1)
let arrow = NSBezierPath()
// Finder places the icons 190 pt from the top; AppKit draws from the bottom.
let y: CGFloat = 400 - 190
arrow.move(to: NSPoint(x: 265, y: y)); arrow.line(to: NSPoint(x: 395, y: y))
arrow.move(to: NSPoint(x: 380, y: y + 10)); arrow.line(to: NSPoint(x: 395, y: y)); arrow.line(to: NSPoint(x: 380, y: y - 10))
arrow.lineWidth = 3; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
petrol.setStroke(); arrow.stroke()

let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
let title: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 15, weight: .medium), .foregroundColor: NSColor(srgbRed: 0.14, green: 0.137, blue: 0.133, alpha: 1), .paragraphStyle: paragraph,
]
let sub: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor(srgbRed: 0.46, green: 0.455, blue: 0.43, alpha: 1), .paragraphStyle: paragraph,
]
NSAttributedString(string: "Drag Timbre to Applications", attributes: title).draw(in: NSRect(x: 0, y: 92, width: 660, height: 24))
NSAttributedString(string: "Then launch it from the menu bar. Nothing you say ever leaves your Mac.", attributes: sub)
    .draw(in: NSRect(x: 0, y: 68, width: 660, height: 20))
image.unlockFocus()

let tiff = image.tiffRepresentation!
let png = NSBitmapImageRep(data: tiff)!.representation(using: .png, properties: [:])!
try! png.write(to: out)
