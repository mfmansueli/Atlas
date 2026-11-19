//
//  SettingsPreferencesTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What board 48 added to `AppPreferences`: the appearance, the artwork
/// defaults, the repeated-words check and the "Don't ask again" choices.
@MainActor
@Suite("Settings preferences")
struct SettingsPreferencesTests {
    private func defaults() -> UserDefaults {
        let name = "SettingsPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func theDefaults() {
        let preferences = AppPreferences(defaults: nil)
        #expect(preferences.appearance == .system)
        #expect(!preferences.eventArtworkHasWords)
        #expect(!preferences.eventArtworkMakesMotion)
        #expect(preferences.checksRepeatedWords)
    }

    @Test func theyAreKept() {
        let defaults = defaults()
        let preferences = AppPreferences(defaults: defaults)
        preferences.appearance = .dark
        preferences.eventArtworkHasWords = true
        preferences.eventArtworkMakesMotion = true
        preferences.checksRepeatedWords = false
        let read = AppPreferences(defaults: defaults)
        #expect(read.appearance == .dark)
        #expect(read.eventArtworkHasWords)
        #expect(read.eventArtworkMakesMotion)
        #expect(!read.checksRepeatedWords)
    }

    @Test func appearanceTitles() {
        #expect(AppAppearance.allCases.map(\.title) == ["Match System", "Light", "Dark"])
        #expect(AppAppearance.system.nsAppearance == nil)
        #expect(AppAppearance.dark.nsAppearance?.name == .darkAqua)
        #expect(AppAppearance.light.nsAppearance?.name == .aqua)
    }

    @Test func resetTurnsEveryConfirmationBackOn() {
        let preferences = AppPreferences(defaults: nil)
        #expect(preferences.turnedOffConfirmations == 0)
        preferences.acceptsAllWithoutAsking = true
        preferences.confirmsDiscarding = false
        preferences.confirmsPriceIncreases = false
        preferences.pushConfirmation = .never
        #expect(preferences.turnedOffConfirmations == 4)
        preferences.resetConfirmations()
        #expect(preferences.turnedOffConfirmations == 0)
        #expect(!preferences.acceptsAllWithoutAsking)
        #expect(preferences.confirmsDiscarding)
        #expect(preferences.confirmsPriceIncreases)
    }

    /// Off in Settings → Suggestions: the keywords check suggests nothing.
    @Test func theRepeatedWordsCheckCanBeTurnedOff() {
        let listing = StoreListing(appName: "Lumen Journal", version: StorePageFixtures.editableVersion, primaryLocale: .englishUS, locales: [
            LocaleListing(locale: .englishUS, remote: [.name: "Lumen: Journal", .subtitle: "Mood diary", .keywords: "journal,mood,diary,gratitude"]),
        ])
        let checked = StorePageBuiltInSuggestions.suggestions(for: listing, appID: "app")
        let unchecked = StorePageBuiltInSuggestions.suggestions(for: listing, appID: "app", checksKeywords: false)
        #expect(checked.contains { $0.target == .storePage(.englishUS, .keywords) })
        #expect(!unchecked.contains { $0.target == .storePage(.englishUS, .keywords) })
    }
}
