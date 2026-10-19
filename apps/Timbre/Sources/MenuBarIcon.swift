import AppKit
import TimbreKit

/// The menu bar item is the mark: the four bars of the favicon and the app
/// icon, without their tile, which GDR-0021 keeps for the Dock. The bars
/// carry the controller's state, so the one glyph says what Timbre is doing:
///
/// - setting up — the bars, dimmed
/// - ready — the bars, in the menu bar's own ink
/// - listening — the bars in the retro colours: the mark lit, the mic open
/// - cleaning up — the colours fading, the mic closed, the paste on its way
/// - error — every bar coral, the identity's colour for "must stop"
///   (GDR-0017), until the next gesture or the grant that fixes it
///
/// The ink states are template images, so the system draws them in the
/// menu bar's colour, inverted under the open menu and right in both
/// appearances. The coloured ones are plain images: a template would
/// flatten them to one tint. Nothing here badges an update — GDR-0013
/// keeps that to the menu, where the user comes looking.
///
/// Drawn in code from the favicon's 32-unit grid, the same numbers as
/// `tools/app-icon.swift`, so a change to the mark is a change in two
/// places and never a stale PNG.
enum MenuBarIcon {

    static func image(for status: DictationController.Status) -> NSImage {
        switch status {
        case .settingUp:
            draw(Array(repeating: dim, count: 4), template: true, "Timbre: setting up")
        case .idle:
            draw(Array(repeating: .black, count: 4), template: true, "Timbre: ready")
        case .listening:
            draw(rainbow, template: false, "Timbre: listening")
        case .polishing:
            draw(rainbow.map { $0.withAlphaComponent(0.45) }, template: false, "Timbre: cleaning up")
        case .error(let message):
            draw(Array(repeating: coral, count: 4), template: false, "Timbre: \(message)")
        }
    }

    // The favicon's grid: four bars at these centres and lengths, stroke 3 of
    // 32 units, round caps. Scaled so the stroke is 2.5 pt — five pixels on a
    // Retina menu bar — which puts the tallest bar at 14 pt, the height of
    // the system's own symbols up there.
    private static let centres: [Double] = [8, 13.3, 18.6, 24]
    private static let lengths: [Double] = [6, 14, 9, 3]
    private static let stroke = 2.5
    private static let unit = stroke / 3
    private static let side = 18.0

    // GDR-0017's accents, the values `tools/app-icon.swift` draws with.
    private static let rainbow = [rgb(228, 87, 63), rgb(240, 200, 70), rgb(80, 200, 160), rgb(80, 170, 220)]
    private static let coral = rgb(228, 87, 63)
    private static let dim = NSColor.black.withAlphaComponent(0.35)

    private static func rgb(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
        NSColor(srgbRed: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, alpha: 1)
    }

    private static func draw(_ colours: [NSColor], template: Bool, _ description: String) -> NSImage {
        // Round caps extend a stroke by half its width at each end, so a bar
        // is its length plus the stroke. The geometry is worked out here, and
        // the handler — which the system calls at each screen's scale, so
        // the bars are crisp on any display — only fills it.
        let span = (centres[3] - centres[0]) * unit + stroke
        let left = (side - span) / 2
        let bars: [(NSRect, NSColor)] = centres.enumerated().map { index, centre in
            let height = lengths[index] * unit + stroke
            let rect = NSRect(
                x: left + (centre - centres[0]) * unit, y: (side - height) / 2, width: stroke, height: height)
            return (rect, colours[index])
        }
        let radius = stroke / 2
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            for (rect, colour) in bars {
                colour.setFill()
                NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            }
            return true
        }
        image.isTemplate = template
        image.accessibilityDescription = description
        return image
    }
}
