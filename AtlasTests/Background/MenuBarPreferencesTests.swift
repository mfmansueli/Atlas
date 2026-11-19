//
//  MenuBarPreferencesTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@MainActor
@Suite("AppPreferences · menu bar and Dock")
struct MenuBarPreferencesTests {
    private func defaults() -> UserDefaults {
        let name = "MenuBarPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func defaultsFromTheDesign() {
        let preferences = AppPreferences(defaults: nil)
        #expect(preferences.showsMenuBarIcon)
        #expect(preferences.keepsRunning)
        #expect(preferences.dockVisibility == .whileWindowOpen)
        #expect(preferences.animatesMenuBarIcon)
        #expect(preferences.checkInterval == .everyHour)
        #expect(!preferences.hasSeenStillRunningNote)
        #expect(preferences.staysOpenWhenClosed)
    }

    @Test func hidingTheIconTurnsOffKeepRunning() {
        let preferences = AppPreferences(defaults: nil)
        preferences.showsMenuBarIcon = false
        #expect(!preferences.keepsRunning)
        #expect(!preferences.staysOpenWhenClosed)
        // Showing it again doesn't turn it back on by itself.
        preferences.showsMenuBarIcon = true
        #expect(!preferences.keepsRunning)
    }

    @Test func keepRunningOffClosesForReal() {
        let preferences = AppPreferences(defaults: nil)
        preferences.keepsRunning = false
        #expect(preferences.showsMenuBarIcon)
        #expect(!preferences.staysOpenWhenClosed)
    }

    @Test func choicesAreRemembered() {
        let defaults = defaults()
        let first = AppPreferences(defaults: defaults)
        first.dockVisibility = .always
        first.animatesMenuBarIcon = false
        first.checkInterval = .every15Minutes
        first.hasSeenStillRunningNote = true
        first.keepsRunning = false

        let relaunched = AppPreferences(defaults: defaults)
        #expect(relaunched.dockVisibility == .always)
        #expect(!relaunched.animatesMenuBarIcon)
        #expect(relaunched.checkInterval == .every15Minutes)
        #expect(relaunched.hasSeenStillRunningNote)
        #expect(!relaunched.keepsRunning)
        #expect(relaunched.showsMenuBarIcon)
    }

    @Test func withoutTheIconKeepRunningStaysOffAfterRelaunch() {
        let defaults = defaults()
        defaults.set(false, forKey: "showsMenuBarIcon")
        defaults.set(true, forKey: "keepsRunningWhenClosed")
        #expect(!AppPreferences(defaults: defaults).keepsRunning)
    }

    @Test func aPretendLoginItemTurnsOnAndOff() {
        let item = LoginItem.inMemory()
        #expect(!item.isEnabled)
        item.setEnabled(true)
        #expect(item.isEnabled)
        #expect(item.problem == nil)
        item.setEnabled(false)
        #expect(!item.isEnabled)
    }
}
