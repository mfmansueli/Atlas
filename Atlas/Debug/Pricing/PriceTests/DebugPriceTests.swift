//
//  DebugPriceTests.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Board 76's sample numbers for Lumen Plus Annual's price tests.
enum DebugPriceTests {
    /// The scenes' today: day 9 of a test pushed on Nov 17.
    static let today = PricingSampleData.date("2026-11-25")
    static let runningStart = PricingSampleData.date("2026-11-17")
    static let finishedStart = PricingSampleData.date("2026-10-20")

    /// Each country's last 28 days, by region: Europe 2,140 page views and
    /// 96 starts, Asia Pacific 2,200 and 88, the Americas without the US
    /// 2,600 and 88, Africa & Middle East 400 and 12 (too few).
    static let signals: [String: SalesSignal] = [
        "DEU": signal(900, 40, 1180), "FRA": signal(520, 24, 700), "ESP": signal(380, 18, 470), "ITA": signal(340, 14, 380),
        "JPN": signal(1100, 44, 1250), "AUS": signal(600, 26, 760), "KOR": signal(300, 12, 300), "IND": signal(200, 6, 60),
        "BRA": signal(1200, 40, 600), "MEX": signal(500, 18, 300), "CAN": signal(900, 30, 900),
        "ZAF": signal(160, 6, 90), "ARE": signal(140, 4, 120), "SAU": signal(100, 2, 60),
    ]

    /// The finished test's 28 days before and during, for each verdict.
    static func windows(_ verdict: ResultVerdict) -> PriceTestWindows {
        let before = SalesSignal(pageViews: 2140, starts: 96, proceeds: 2730)
        let controlBefore = SalesSignal(pageViews: 2200, starts: 88, proceeds: 2370)
        let controlDuring = SalesSignal(pageViews: 2180, starts: 88, proceeds: 2350)
        let during = switch verdict {
        case .better: SalesSignal(pageViews: 2210, starts: 140, proceeds: 3020)
        case .worse: SalesSignal(pageViews: 2160, starts: 58, proceeds: 2100)
        case .aboutTheSame: SalesSignal(pageViews: 2150, starts: 100, proceeds: 2280)
        case .tooLittleData: SalesSignal(pageViews: 380, starts: 14, proceeds: 300)
        }
        let tooFewBefore = SalesSignal(pageViews: 400, starts: 12, proceeds: 270)
        return PriceTestWindows(
            testBefore: verdict == .tooLittleData ? tooFewBefore : before,
            testDuring: during,
            controlBefore: controlBefore,
            controlDuring: controlDuring,
            readOn: today
        )
    }

    /// The assistant's card (`pt-cc`).
    static func suggestion(productID: String) -> PriceTestSuggestion {
        PriceTestSuggestion(
            id: "pts-debug", productID: productID, region: .asiaPacific, step: .suggested,
            title: String(localized: "Test suggested prices in Asia Pacific", comment: "kind:suggestion-title"),
            why: String(localized: "7 countries there feel over 2× the US price. A test would make their suggestions sure.", comment: "kind:suggestion-why"),
            layers: SuggestionLayers(confidence: .fairlySure),
            source: "Claude Code",
            receivedAt: today
        )
    }

    private static func signal(_ views: Int, _ starts: Int, _ proceeds: Decimal) -> SalesSignal {
        SalesSignal(pageViews: views, starts: starts, proceeds: proceeds)
    }
}
#endif
