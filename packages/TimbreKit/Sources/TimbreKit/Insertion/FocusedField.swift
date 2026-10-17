import AppKit
import ApplicationServices
import os

/// The text field the user is typing into, through the Accessibility API —
/// enough of it to type live and to replace the typed run afterwards
/// (GDR-0018).
///
/// Probed once when a dictation starts, and again at release to make sure
/// focus never moved. Every call is a synchronous IPC round-trip into the
/// other app, so there are exactly as many as the flow needs: three at the
/// start, three at the end.
final class FocusedField {

    private static let logger = Logger(subsystem: "dev.hugopretorius.Timbre", category: "insertion")

    let element: AXUIElement
    /// Where the caret was when the hold began — the start of the run Timbre
    /// types. A selection at that moment starts the run at its beginning,
    /// since the first typed character replaces it.
    let start: Int
    /// The character just before the caret when the hold began, read once,
    /// so the first typed words can carry the space the user would have.
    let characterBefore: Character?

    /// What the last probe found — the role and whether it typed live, or
    /// why not — one line for the capture log, so an app that never types
    /// live says what it withheld.
    nonisolated(unsafe) private(set) static var lastNote = ""

    private init(element: AXUIElement, start: Int, characterBefore: Character?) {
        self.element = element
        self.start = start
        self.characterBefore = characterBefore
    }

    /// The focused element, if it is an editable text field Timbre can both
    /// type into and read back. Nil for secure fields, terminals, and any
    /// element that hides its text — those keep the pill-then-paste flow.
    static func probe() -> FocusedField? {
        guard let (element, how) = AccessibilityFocus.focusedElement() else {
            lastNote = "no focused element"
            logger.log("field: no focused element")
            return nil
        }
        let role = string(attribute: kAXRoleAttribute, of: element) ?? "?"

        // kAXSecureTextFieldRole is a CFSTR macro the headers do not export to Swift.
        if role == "AXSecureTextField" {
            lastNote = "secure text field"
            logger.log("field: secure text field, typing nothing live")
            return nil
        }

        var settable = DarwinBoolean(false)
        let settableResult = AXUIElementIsAttributeSettable(
            element, kAXSelectedTextRangeAttribute as CFString, &settable)
        guard settableResult == .success, settable.boolValue, let range = selectedRange(of: element) else {
            lastNote = "\(role): selection not settable (\(settableResult.rawValue))"
            logger.log("field: \(lastNote, privacy: .public)")
            return nil
        }

        lastNote = "\(role) · live" + (how.map { " · \($0)" } ?? "")
        return FocusedField(
            element: element, start: range.location,
            characterBefore: characterBefore(range.location, in: element))
    }

    /// The character before `location`, for the leading-space rule.
    private static func characterBefore(_ location: Int, in element: AXUIElement) -> Character? {
        guard location > 0 else { return nil }
        var cfRange = CFRange(location: location - 1, length: 1)
        guard let rangeValue = AXValueCreate(.cfRange, &cfRange) else { return nil }
        var textRef: CFTypeRef?
        guard
            AXUIElementCopyParameterizedAttributeValue(
                element, kAXStringForRangeParameterizedAttribute as CFString, rangeValue, &textRef)
                == .success,
            let text = textRef as? String
        else { return nil }
        return text.last
    }

    /// True while the same element still has focus.
    func isStillFocused() -> Bool {
        guard let (focused, _) = AccessibilityFocus.focusedElement() else { return false }
        return CFEqual(focused, element)
    }

    /// Where the caret is now, in UTF-16 units from the start of the field.
    func caretLocation() -> Int? {
        Self.selectedRange(of: element).map { $0.location + $0.length }
    }

    /// The field's text in `range`, read back from the app.
    func text(in range: NSRange) -> String? {
        var cfRange = CFRange(location: range.location, length: range.length)
        guard let rangeValue = AXValueCreate(.cfRange, &cfRange) else { return nil }
        var textRef: CFTypeRef?
        guard
            AXUIElementCopyParameterizedAttributeValue(
                element,
                kAXStringForRangeParameterizedAttribute as CFString,
                rangeValue,
                &textRef
            ) == .success,
            let text = textRef as? String
        else { return nil }
        return text
    }

    /// Selects `range`, so the next paste replaces it.
    @discardableResult
    func select(_ range: NSRange) -> Bool {
        var cfRange = CFRange(location: range.location, length: range.length)
        guard let rangeValue = AXValueCreate(.cfRange, &cfRange) else { return false }
        return AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, rangeValue)
            == .success
    }

    private static func selectedRange(of element: AXUIElement) -> NSRange? {
        var rangeRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef)
                == .success,
            let rangeRef,
            CFGetTypeID(rangeRef) == AXValueGetTypeID()
        else { return nil }
        var range = CFRange()
        guard AXValueGetValue(unsafeDowncast(rangeRef, to: AXValue.self), .cfRange, &range) else {
            return nil
        }
        return NSRange(location: range.location, length: range.length)
    }

    private static func string(attribute: String, of element: AXUIElement) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success else {
            return nil
        }
        return ref as? String
    }
}
