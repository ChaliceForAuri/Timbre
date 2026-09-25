// Draws the disk image background: the site's petrol on cool paper, an arrow
// from the app to Applications, one line of instruction. Drawn in code so it
// matches the palette and never goes stale as a binary asset.
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 660, height: 400)
let image = NSImage(size: size)
image.lockFocus()

NSColor(red: 0.972, green: 0.976, blue: 0.980, alpha: 1).setFill()
NSRect(origin: .zero, size: size).fill()

let petrol = NSColor(red: 0.13, green: 0.42, blue: 0.42, alpha: 1)
let arrow = NSBezierPath()
// Finder places the icons 190 pt from the top; AppKit draws from the bottom.
let y: CGFloat = 400 - 190
arrow.move(to: NSPoint(x: 265, y: y)); arrow.line(to: NSPoint(x: 395, y: y))
arrow.move(to: NSPoint(x: 380, y: y + 10)); arrow.line(to: NSPoint(x: 395, y: y)); arrow.line(to: NSPoint(x: 380, y: y - 10))
arrow.lineWidth = 3; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
petrol.setStroke(); arrow.stroke()

let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
let title: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 15, weight: .medium), .foregroundColor: NSColor(white: 0.23, alpha: 1), .paragraphStyle: paragraph,
]
let sub: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor(white: 0.49, alpha: 1), .paragraphStyle: paragraph,
]
NSAttributedString(string: "Drag Timbre to Applications", attributes: title).draw(in: NSRect(x: 0, y: 92, width: 660, height: 24))
NSAttributedString(string: "Then launch it from the menu bar. Nothing you say ever leaves your Mac.", attributes: sub)
    .draw(in: NSRect(x: 0, y: 68, width: 660, height: 20))
image.unlockFocus()

let tiff = image.tiffRepresentation!
let png = NSBitmapImageRep(data: tiff)!.representation(using: .png, properties: [:])!
try! png.write(to: out)
