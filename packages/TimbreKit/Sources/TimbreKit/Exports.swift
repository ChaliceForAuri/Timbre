// The Library and the types the app reads through `DictationController` —
// `Correction`, `Acronym`, `Todo` — live in TimbreCore (ADR-0013). Re-exported
// so the app shell imports TimbreKit alone and the Xcode project need not
// change.
@_exported import TimbreCore
