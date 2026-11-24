//
//  AppPreferencesTests.swift
//  AtlasTests
//

import Foundation
import SwiftUI
import Testing
@testable import Atlas

@MainActor
@Suite("AppPreferences")
struct AppPreferencesTests {
    private func defaults() -> UserDefaults {
        let name = "AppPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func startsWithTheDesignsDefaults() {
        let preferences = AppPreferences(defaults: nil)
        #expect(preferences.defaultPricingMode == .showSuggestions)
        #expect(preferences.usesSalesData)
        #expect(preferences.pricingDefaults == .recommended)
        #expect(preferences.commissionRate == 0.15)
        #expect(preferences.pushConfirmation == .overFifty)
        #expect(preferences.confirmsPriceIncreases)
        #expect(preferences.confirmsDiscarding)
        #expect(preferences.autoplaysMotion)
    }

    @Test func movingArtworkStaysStillOnceTurnedOff() {
        let defaults = defaults()
        let preferences = AppPreferences(defaults: defaults)
        #expect(preferences.autoplaysMotion)
        preferences.autoplaysMotion = false
        #expect(!AppPreferences(defaults: defaults).autoplaysMotion)
        // Reduce Motion keeps it still whatever the setting.
        #expect(AutoplayingLoop<EmptyView>.plays(setting: true, reduceMotion: false))
        #expect(!AutoplayingLoop<EmptyView>.plays(setting: false, reduceMotion: false))
        #expect(!AutoplayingLoop<EmptyView>.plays(setting: true, reduceMotion: true))
    }

    @Test func everySettingSurvivesARelaunch() {
        let defaults = defaults()
        let preferences = AppPreferences(defaults: defaults)
        preferences.defaultPricingMode = .keepPrices
        preferences.usesSalesData = false
        preferences.pricingDefaults.customize { $0.indexSource = .bigMac }
        preferences.pricingDefaults.baseTerritoryID = "DEU"
        preferences.commissionRate = 0.30
        preferences.pushConfirmation = .always
        preferences.confirmsPriceIncreases = false
        preferences.confirmsDiscarding = false

        let relaunched = AppPreferences(defaults: defaults)
        #expect(relaunched.defaultPricingMode == .keepPrices)
        #expect(!relaunched.usesSalesData)
        #expect(relaunched.pricingDefaults.indexSource == .bigMac)
        #expect(relaunched.pricingDefaults.isCustom)
        #expect(relaunched.pricingDefaults.baseTerritoryID == "DEU")
        #expect(relaunched.commissionRate == 0.30)
        #expect(relaunched.pushConfirmation == .always)
        #expect(!relaunched.confirmsPriceIncreases)
        #expect(!relaunched.confirmsDiscarding)
    }

    /// The Guided/Classic choice is retired: a Mac that chose Classic
    /// forgets it, and the guided Autopilot is the only one.
    @Test func theRetiredAutopilotChoiceIsForgotten() {
        let defaults = defaults()
        defaults.set("classic", forKey: "autopilotFront")
        _ = AppPreferences(defaults: defaults)
        #expect(defaults.string(forKey: "autopilotFront") == nil)
    }

    @Test func unreadablePricingDefaultsFallBackToRecommended() {
        let defaults = defaults()
        defaults.set(Data("not json".utf8), forKey: "pricingDefaults")
        #expect(AppPreferences(defaults: defaults).pricingDefaults == .recommended)
    }

    @Test func inMemoryPreferencesTouchNoDefaults() {
        let preferences = AppPreferences(defaults: nil)
        preferences.commissionRate = 0.30
        #expect(AppPreferences(defaults: nil).commissionRate == 0.15)
    }
}
