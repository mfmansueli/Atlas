//
//  WelcomeChipTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("WelcomeChip and its places")
struct WelcomeChipTests {
    private let chip = WelcomeChip(content: .language(flag: "🇩🇪", name: "Deutsch"), delay: 0)

    @Test func popsInStaysThreeSecondsAndLiftsAway() {
        let start = chip.appearance(at: 0)
        #expect(start.opacity == 0)
        #expect(start.offset == 8)
        #expect(start.scale == 0.82)
        let shown = chip.appearance(at: 2)
        #expect(shown == WelcomeChip.Appearance(opacity: 1, offset: 0, scale: 1))
        // Out from 3.4 s to 3.9 s of the 20.
        let leaving = chip.appearance(at: 3.65)
        #expect(abs(leaving.opacity - 0.5) < 1e-9)
        #expect(leaving.offset < 0)
        #expect(chip.appearance(at: 10).opacity == 0)
        #expect(chip.appearance(at: 22) == chip.appearance(at: 2))
    }

    @Test func readingDoublesThePace() {
        #expect(chip.appearance(at: 1, pace: 2) == chip.appearance(at: 2))
    }

    @Test func eightPlacesFourChipsEachFourFar() {
        let slots = WelcomeChipSlot.all
        #expect(slots.count == 8)
        #expect(slots.allSatisfy { $0.chips.count == 4 })
        #expect(slots.count(where: \.isFar) == 4)
        #expect(Set(slots.map(\.id)).count == 8)
    }

    @Test func oneInFourIsAPrice() {
        let chips = WelcomeChipSlot.all.flatMap(\.chips)
        let prices = chips.filter { if case .price = $0.content { true } else { false } }
        #expect(prices.count == 8)
        #expect(WelcomeChipSlot.all.allSatisfy { slot in
            slot.chips.count { if case .price = $0.content { true } else { false } } == 1
        })
    }

    @Test func aPlaceShowsOneChipAtATime() {
        for slot in WelcomeChipSlot.all {
            for time in stride(from: 0.0, to: 20, by: 0.25) {
                let visible = slot.chips.filter { $0.appearance(at: time).opacity > 0 }
                #expect(visible.count <= 1, "slot \(slot.id) at \(time)")
            }
        }
    }

    @Test func placesDriftFourteenPoints() {
        let slot = WelcomeChipSlot.all[0]
        #expect(abs(slot.drift(at: 0) + 7) < 1e-9)
        #expect(abs(slot.drift(at: 6) - 7) < 1e-9)
    }

    @Test func flagsAreStorefrontLanguages() {
        let names = WelcomeChipSlot.all.flatMap(\.chips).compactMap { chip -> String? in
            if case let .language(flag, name) = chip.content { "\(flag) \(name)" } else { nil }
        }
        // Portuguese, Spanish and French each under two storefronts' flags.
        #expect(names.contains("🇧🇷 Português"))
        #expect(names.contains("🇵🇹 Português"))
        #expect(names.contains("🇪🇸 Español"))
        #expect(names.contains("🇲🇽 Español"))
        #expect(names.contains("🇫🇷 Français"))
        #expect(names.contains("🇨🇦 Français"))
    }
}
