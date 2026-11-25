//
//  MCPPriceBulkRequest.swift
//  Atlas
//

import Foundation

/// A `propose_prices` call that works on countries as a selection: one
/// action over `territories` (and `except`), or `acceptSuggestions` or
/// `withdraw` for one `territory`.
struct MCPPriceBulkRequest: Hashable, Sendable {
    var selection: MCPCountrySelection
    var action: MCPPriceBulkAction
    /// `territories` was sent: the result is a batch's.
    var isBatch: Bool

    /// The request, or nil for a call that sends `territory` and a price
    /// (or automatic), or `prices`.
    static func parse(_ arguments: MCPToolArguments) throws -> MCPPriceBulkRequest? {
        if let selection = try MCPCountrySelection.parse(arguments) {
            if arguments.values["prices"] != nil || arguments.values["territory"] != nil {
                throw MCPToolError.invalidArgument(name: "territories", expected: String(localized: "territories without territory or prices"))
            }
            return try MCPPriceBulkRequest(selection: selection, action: MCPPriceBulkAction.parse(arguments), isBatch: true)
        }
        let isSelectionAction = try arguments.optionalBool("acceptSuggestions") == true || arguments.optionalBool("withdraw") == true
        guard isSelectionAction, arguments.values["prices"] == nil else { return nil }
        let territory = try arguments.string("territory")
        let selection = MCPCountrySelection(items: [.territory(territory)])
        return try MCPPriceBulkRequest(selection: selection, action: MCPPriceBulkAction.parse(arguments), isBatch: false)
    }
}
