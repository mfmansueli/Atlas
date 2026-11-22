//
//  RetentionReport+Lookup.swift
//  Atlas
//

import Foundation

extension RetentionReport {
    /// A message of Pricing → Retention in Apple's report: by its App Store
    /// Connect identifier, else by its reference name.
    func message(id: String, name: String) -> Message? {
        messages.first { !$0.isNoMessage && $0.id == id } ?? messages.first { !$0.isNoMessage && $0.name == name }
    }
}
