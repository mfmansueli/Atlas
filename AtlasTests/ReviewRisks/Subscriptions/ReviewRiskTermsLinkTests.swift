//
//  ReviewRiskTermsLinkTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Which URLs in a description work as its Terms of Use link.
@Suite("Review risks · Terms of Use link")
struct ReviewRiskTermsLinkTests {
    @Test func wordsRightBeforeAURLCount() {
        #expect(ReviewRiskTermsLink.urls(in: "Terms of Use: https://lumen.example.com/l/42") == ["https://lumen.example.com/l/42"])
        #expect(ReviewRiskTermsLink.has(in: "Termos de Uso: https://lumen.example.com.br/x"))
        #expect(ReviewRiskTermsLink.has(in: "Conditions d’utilisation : https://lumen.example.fr/c"))
        #expect(ReviewRiskTermsLink.has(in: "使用条款：https://lumen.example.cn/t"))
    }

    @Test func anAddressThatNamesTermsCounts() {
        #expect(ReviewRiskTermsLink.has(in: "More at https://lumen.example.com/terms-of-use"))
        #expect(ReviewRiskTermsLink.has(in: "EULA \(ReviewRiskTermsLink.standardEULA)"))
    }

    @Test func wordsWithoutAURLDontCount() {
        #expect(!ReviewRiskTermsLink.has(in: "By subscribing you agree to our Terms of Use and Privacy Policy."))
    }

    @Test func aPrivacyLinkNearTermsDoesntCount() {
        #expect(!ReviewRiskTermsLink.has(in: "Subscription terms apply. Privacy: https://lumen.example.com/privacy"))
    }

    @Test func aURLFarFromTheWordsDoesntCount() {
        let filler = String(repeating: "Write every day and see your moods change. ", count: 6)
        #expect(!ReviewRiskTermsLink.has(in: "Terms of Use apply. \(filler)Website: https://lumen.example.com"))
    }

    /// A short word inside another ("tos" in "photos") isn't one.
    @Test func shortWordsMustStandAlone() {
        #expect(!ReviewRiskTermsLink.has(in: "Photos agbook cgunit: https://lumen.example.com/p"))
    }

    @Test func emailsArentLinks() {
        #expect(!ReviewRiskTermsLink.has(in: "Terms of Use: write to terms-help@lumen.example.com"))
    }
}
