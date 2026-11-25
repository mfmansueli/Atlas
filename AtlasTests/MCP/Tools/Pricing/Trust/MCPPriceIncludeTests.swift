//
//  MCPPriceIncludeTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

@Suite("MCPPriceInclude")
struct MCPPriceIncludeTests {
    @Test func withoutIncludeHowSureAndEvidence() throws {
        #expect(try MCPPriceInclude.parse(MCPToolArguments([:])) == [.howSure, .evidence])
    }

    @Test func allIsEveryGroup() throws {
        #expect(try MCPPriceInclude.parse(MCPToolArguments(["include": ["grid", "ALL"]])) == Set(MCPPriceInclude.allCases))
    }

    @Test func namesIgnoreCase() throws {
        #expect(try MCPPriceInclude.parse(MCPToolArguments(["include": ["Index", "exchangerate"]])) == [.index, .exchangeRate])
    }

    @Test func anEmptyListAddsNothing() throws {
        #expect(try MCPPriceInclude.parse(MCPToolArguments(["include": []])).isEmpty)
    }
}
#endif
