//
//  ICPFilingNumber.swift
//  Atlas
//

import Foundation

/// China mainland's ICP Filing Number as the Ministry of Industry and
/// Information Technology writes it: a province's character, `ICP备`,
/// eight to ten digits, `号`, and for an app a suffix like `-1A`.
enum ICPFilingNumber {
    static let example = "京ICP备2024000000号-1A"

    private static let pattern = #"^[一-龥]ICP备[0-9]{8,10}号(-[0-9]+[A-Z]?)?$"#

    /// Without the spaces a copied number comes with.
    static func normalized(_ text: String) -> String {
        text.filter { !$0.isWhitespace }
    }

    /// Whether `text` reads like a filing number. Only the format: nothing
    /// here can tell that the number was issued.
    static func isValid(_ text: String) -> Bool {
        normalized(text).range(of: pattern, options: .regularExpression) != nil
    }
}
