//
//  SettingsOptionsTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

@MainActor
@Suite("Settings options")
struct SettingsOptionsTests {
    @Test func fallbackChainOffersTheOtherIndicesThenTheRegionMedian() {
        #expect(FallbackChainEditor.optionalSteps(chosen: .worldBank) == [.index(.bigMac), .index(.imf), .regionMedian])
        #expect(FallbackChainEditor.optionalSteps(chosen: .bigMac) == [.index(.worldBank), .index(.imf), .regionMedian])
    }

    @Test func commissionTitlesNameTheProgram() {
        #expect(PricingSettingsPane.commissionRates == [0.15, 0.30])
        #expect(PricingSettingsPane.title(forCommission: 0.15) == "15% · Small Business Program")
        #expect(PricingSettingsPane.title(forCommission: 0.30) == "30% · Standard")
    }

    @Test func roundingTitlesSpellTheChoiceOut() {
        #expect(PricingSettingsPane.title(for: .auto) == "Each currency’s usual ending")
        #expect(PricingSettingsPane.title(for: .ninetyNine) == "Always .99")
    }

    @Test func providersExplainThemselves() {
        #expect(TranslationProvider.allCases.count == 3)
        #expect(TranslationProvider.appleTranslation.summary.contains("private"))
        #expect(AIProviderVendor.anthropic.secretName == "translation.anthropic.apiKey")
    }
}
