//
//  MCPPriceValueTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Prices read from the price tools' arguments: positive amounts, and 0
/// only where a free price is allowed.
struct MCPPriceValueTests {
    @Test func numbersAndTextsAreRead() {
        #expect(MCPPriceValue.decimal(from: .double(109.9)) == Decimal(string: "109.9"))
        #expect(MCPPriceValue.decimal(from: .int(2499)) == 2499)
        #expect(MCPPriceValue.decimal(from: .string("109,90")) == Decimal(string: "109.9"))
    }

    @Test func zeroIsOnlyAPriceWhereFreeIsAllowed() {
        #expect(MCPPriceValue.decimal(from: .int(0)) == nil)
        #expect(MCPPriceValue.decimal(from: .int(0), allowsFree: true) == 0)
        #expect(MCPPriceValue.decimal(from: .double(0), allowsFree: true) == 0)
        #expect(MCPPriceValue.decimal(from: .double(-1), allowsFree: true) == nil)
    }
}
