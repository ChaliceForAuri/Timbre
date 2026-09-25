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

    private init(element: AXUIElement, start: Int) {
        self.element = element
        self.start = start
    }

    /// The focused element, if it is an editable text field Timbre can both
    /// type into and read back. Nil for secure fields, terminals, and any
    /// element that hides its text — those keep the pill-then-paste flow.
    static func probe() -> FocusedField? {
        var focusedRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                AXUIElementCreateSystemWide(),
                kAXFocusedUIElementAttribute as CFString,
                &focusedRef
            ) == .success,
            let focusedRef,
            CFGetTypeID(focusedRef) == AXUIElementGetTypeID()
        else {
            logger.log("field: no focused element")
            return nil
        }
        let element = unsafeDowncast(focusedRef, to: AXUIElement.self)

        // kAXSecureTextFieldRole is a CFSTR macro the headers do not export to Swift.
        if let role = string(attribute: kAXRoleAttribute, of: element), role == "AXSecureTextField" {
            logger.log("field: secure text field, typing nothing live")
            return nil
        }

        var settable = DarwinBoolean(false)
        guard
            AXUIElementIsAttributeSettable(element, kAXSelectedTextRangeAttribute as CFString, &settable)
                == .success,
            settable.boolValue,
            let range = selectedRange(of: element)
        else {
            logger.log("field: focused element does not expose a settable selection")
            return nil
        }

        return FocusedField(element: element, start: range.location)
    }

    /// True while the same element still has focus.
    func isStillFocused() -> Bool {
        var focusedRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                AXUIElementCreateSystemWide(),
                kAXFocusedUIElementAttribute as CFString,
                &focusedRef
            ) == .success,
            let focusedRef,
            CFGetTypeID(focusedRef) == AXUIElementGetTypeID()
        else { return false }
        return CFEqual(focusedRef, element)
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
