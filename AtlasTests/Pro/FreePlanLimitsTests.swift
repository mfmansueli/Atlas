//
//  FreePlanLimitsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Free's limits beyond the all-at-once actions (README — Monetization):
/// 3 templates on iPhone and iPad, and one App Store Connect account.
@MainActor
@Suite("Free plan limits")
struct FreePlanLimitsTests {
    private static func free() -> ProGate {
        ProGate(entitlements: Entitlements(store: FakeProStore()))
    }

    private static func pro() -> ProGate {
        ProGate(entitlements: Entitlements(store: FakeProStore(), override: true))
    }

    @Test func freeHasTheThreeSimpleTemplates() {
        #expect(FreePlanLimits.templates.count == Entitlements.freeTemplateLimit)
        #expect(FreePlanLimits.templates == [.above, .band, .panorama])
        #expect(TemplateStarter.allCases.count { FreePlanLimits.includes($0) } == 3)
    }

    @Test func freeTemplatesLayOutIPhoneAndIPadOnly() {
        #expect(FreePlanLimits.displays == [.iPhone, .iPad])
        for display in [ScreenshotDisplayType.iPhoneDuo, .mac, .watch, .visionPro] {
            #expect(!FreePlanLimits.includes(display))
        }
    }

    @Test func inFreeTheOtherTemplatesNeedPro() {
        let gate = Self.free()
        #expect(gate.mayUse(.band))
        #expect(!gate.mayUse(.cinema))
        #expect(!gate.mayUse(.arcade))
    }

    @Test func theTemplateInUseIsNeverLocked() {
        let gate = Self.free()
        #expect(gate.mayUse(.cinema, inUse: .cinema), "What a person already made stays usable")
        #expect(!gate.mayUse(.poster, inUse: .cinema))
    }

    @Test func proUsesEveryTemplateAndDevice() {
        let gate = Self.pro()
        #expect(TemplateStarter.allCases.allSatisfy { gate.mayUse($0) })
        #expect(ScreenshotDisplayType.studio.allSatisfy { gate.mayShow($0) })
    }

    @Test func inFreeTheEditorShowsIPhoneAndIPad() {
        let gate = Self.free()
        #expect(gate.mayShow(.iPhone))
        #expect(gate.mayShow(.iPad))
        #expect(!gate.mayShow(.iPhoneDuo))
        #expect(!gate.mayShow(.mac))
    }

    @Test func noGateIsLikePro() {
        let gate: ProGate? = nil
        #expect(gate.mayUse(.cinema))
        #expect(gate.mayShow(.mac))
        #expect(gate.mayAddAccount(accountCount: 4))
    }

    @Test func aTemplateDeviceOpensThePaywallForAllTemplates() {
        let gate = Self.free()
        var shown = 0
        gate.require(.templateDevice("iPhone Duo")) { shown += 1 }
        #expect(shown == 0)
        #expect(gate.paywall?.context.feature == .allTemplates)
        #expect(gate.paywall?.context.title == "Templates on iPhone Duo are part of Pro")
        #expect(gate.paywall?.context.continueTitle == "Show iPhone Duo")
    }

    @Test func theFirstKeyIsFreeAndASecondNeedsPro() {
        let gate = Self.free()
        #expect(gate.mayAddAccount(accountCount: 0))
        #expect(!gate.mayAddAccount(accountCount: 1))
        #expect(Self.pro().mayAddAccount(accountCount: 3))
    }

    @Test func aSecondKeyOpensThePaywallAndAddsItAfterBuying() async throws {
        let gate = Self.free()
        var added = 0
        gate.requireNewAccount(accountCount: 0) { added += 1 }
        #expect(added == 1, "With no key saved, the sheet opens")
        gate.requireNewAccount(accountCount: 1) { added += 1 }
        #expect(added == 1)
        let paywall = try #require(gate.paywall)
        #expect(paywall.context == .secondAccount)
        #expect(paywall.context.feature == .multipleApps)
        #expect(paywall.context.title == "More than one account is part of Pro")
        #expect(paywall.context.continueTitle == "Add the Key…")
        await paywall.load()
        await paywall.buy()
        gate.finish(paywall, continues: true)
        #expect(added == 2)
    }

    @Test func fromSettingsThePaywallOpensOnItsWindow() {
        let gate = Self.free()
        var added = 0
        gate.requireNewAccount(accountCount: 1, inSettings: true) { added += 1 }
        #expect(added == 0)
        #expect(gate.paywall == nil)
        #expect(gate.settingsPaywall?.context == .secondAccount)
    }
}
