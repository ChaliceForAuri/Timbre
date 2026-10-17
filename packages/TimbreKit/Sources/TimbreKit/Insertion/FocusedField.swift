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
    /// Whether `AXSelectedTextRange` can be set directly. Web views say no.
    let canSetSelection: Bool

    /// What the last probe found — the role and whether it typed live, or
    /// why not — one line for the capture log, so an app that never types
    /// live says what it withheld.
    nonisolated(unsafe) private(set) static var lastNote = ""

    private init(element: AXUIElement, start: Int, characterBefore: Character?, canSetSelection: Bool) {
        self.element = element
        self.start = start
        self.characterBefore = characterBefore
        self.canSetSelection = canSetSelection
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

        // Readable is the bar: a caret position now, and the text behind it
        // on release, so the typed run can be checked before it is replaced.
        guard let range = selectedRange(of: element) else {
            lastNote = "\(role): no caret position"
            logger.log("field: \(lastNote, privacy: .public)")
            return nil
        }
        let before = characterBefore(range.location, in: element)
        guard range.location == 0 || before != nil else {
            lastNote = "\(role): text not readable"
            logger.log("field: \(lastNote, privacy: .public)")
            return nil
        }

        // Settable is the easy way to select the run; web views say no and
        // take text markers or shift-arrows instead, both verified.
        var settable = DarwinBoolean(false)
        let canSet =
            AXUIElementIsAttributeSettable(element, kAXSelectedTextRangeAttribute as CFString, &settable)
            == .success && settable.boolValue

        lastNote =
            "\(role) · live · \(canSet ? "selection" : "markers or keys")" + (how.map { " · \($0)" } ?? "")
        return FocusedField(
            element: element, start: range.location, characterBefore: before, canSetSelection: canSet)
    }

    /// The character before the caret in the focused field, without the
    /// rest of the probe — for the leading-space rule on the pill path.
    /// `known` is false when the field cannot be read at all.
    static func characterBeforeCaret() -> (known: Bool, character: Character?) {
        guard
            let (element, _) = AccessibilityFocus.focusedElement(),
            let range = selectedRange(of: element)
        else { return (false, nil) }
        if range.location == 0 { return (true, nil) }
        guard let character = characterBefore(range.location, in: element) else { return (false, nil) }
        return (true, character)
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

    /// Selects `range` — whose text is `text`, as just read back — so the
    /// next paste replaces it. Three ways, in order of trust: the selection
    /// attribute; WebKit's text markers; shift-left one character at a time,
    /// which is then read back and must match. Returns false when none
    /// could be verified, and leaves the caret where it was.
    func select(_ range: NSRange, text: String) -> Bool {
        if canSetSelection, setSelectedRange(range) { return true }
        if selectUsingTextMarkers(range), selectedTextMatches(text) { return true }
        return selectUsingKeys(text)
    }

    private func setSelectedRange(_ range: NSRange) -> Bool {
        var cfRange = CFRange(location: range.location, length: range.length)
        guard let rangeValue = AXValueCreate(.cfRange, &cfRange) else { return false }
        return AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, rangeValue)
            == .success
    }

    /// WebKit (Mail, Safari, Notes' web content) exposes its selection as a
    /// range of text markers, the way VoiceOver drives it.
    private func selectUsingTextMarkers(_ range: NSRange) -> Bool {
        guard
            let start = textMarker(at: range.location),
            let end = textMarker(at: range.location + range.length)
        else { return false }
        var markerRangeRef: CFTypeRef?
        let pair = [start, end] as CFArray
        guard
            AXUIElementCopyParameterizedAttributeValue(
                element, "AXTextMarkerRangeForUnorderedTextMarkers" as CFString, pair, &markerRangeRef)
                == .success,
            let markerRange = markerRangeRef
        else { return false }
        return AXUIElementSetAttributeValue(element, "AXSelectedTextMarkerRange" as CFString, markerRange)
            == .success
    }

    private func textMarker(at index: Int) -> CFTypeRef? {
        var markerRef: CFTypeRef?
        guard
            AXUIElementCopyParameterizedAttributeValue(
                element, "AXTextMarkerForIndex" as CFString, index as CFNumber, &markerRef) == .success
        else { return nil }
        return markerRef
    }

    /// Shift-left once per character of the run, then read the selection
    /// back. A field that cannot be read back cannot be trusted this way;
    /// the selection is collapsed again and the words stay as heard.
    private func selectUsingKeys(_ text: String) -> Bool {
        SyntheticKey.press(.leftArrow, modifiers: .maskShift, times: text.count)
        if selectedTextMatches(text) { return true }
        SyntheticKey.press(.rightArrow, modifiers: [])
        return false
    }

    private func selectedTextMatches(_ text: String) -> Bool {
        var ref: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &ref) == .success,
            let selected = ref as? String
        else { return false }
        return selected == text || ReplacementCheck.matches(field: selected, typed: text)
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
