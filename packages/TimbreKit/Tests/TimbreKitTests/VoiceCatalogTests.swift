import Testing

@testable import TimbreKit

@Suite("VoiceCatalog")
struct VoiceCatalogTests {

    private let compactUS = VoiceCatalog.Option(
        identifier: "us.compact", name: "Samantha", language: "en-US", qualityRank: 1)
    private let premiumUS = VoiceCatalog.Option(
        identifier: "us.premium", name: "Ava", language: "en-US", qualityRank: 3)
    private let enhancedGB = VoiceCatalog.Option(
        identifier: "gb.enhanced", name: "Daniel", language: "en-GB", qualityRank: 2)
    private let compactFR = VoiceCatalog.Option(
        identifier: "fr.compact", name: "Thomas", language: "fr-FR", qualityRank: 1)

    @Test("Higher quality wins within the same language")
    func prefersQuality() {
        let choice = VoiceCatalog.choose(from: [compactUS, premiumUS], preferring: "en-US")
        #expect(choice == premiumUS)
    }

    /// Region before quality: a Premium American voice reading British
    /// English mispronounces its way through the text, and that is what a
    /// listener notices — not the codec.
    @Test("An exact region match beats a higher-quality foreign region")
    func prefersRegionOverQuality() {
        let choice = VoiceCatalog.choose(from: [premiumUS, enhancedGB], preferring: "en-GB")
        #expect(choice == enhancedGB)
    }

    @Test("Falls back to the same language, then to anything")
    func fallsBack() {
        // No en-AU voice installed: any English one will do.
        #expect(VoiceCatalog.choose(from: [premiumUS, enhancedGB], preferring: "en-AU") == premiumUS)
        // No English at all: better something than silence.
        #expect(VoiceCatalog.choose(from: [compactFR], preferring: "en-US") == compactFR)
        #expect(VoiceCatalog.choose(from: [], preferring: "en-US") == nil)
    }

    @Test("Choice is stable when quality ties")
    func stableTiebreak() {
        let a = VoiceCatalog.Option(
            identifier: "a", name: "A", language: "en-US", qualityRank: 1)
        let b = VoiceCatalog.Option(
            identifier: "b", name: "B", language: "en-US", qualityRank: 1)
        #expect(
            VoiceCatalog.choose(from: [a, b], preferring: "en-US")
                == VoiceCatalog.choose(from: [b, a], preferring: "en-US")
        )
    }

    @Test("Compact voices are not high quality")
    func qualityFlag() {
        #expect(!compactUS.isHighQuality)
        #expect(enhancedGB.isHighQuality)
        #expect(premiumUS.isHighQuality)
    }
}
