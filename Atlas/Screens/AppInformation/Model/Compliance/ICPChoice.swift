//
//  ICPChoice.swift
//  Atlas
//

import Foundation

/// The two ways to answer China mainland's ICP Filing Number.
enum ICPChoice: String, CaseIterable, Identifiable, Hashable, Sendable {
    /// Add the number. Apple's API doesn't take it, so it's entered in
    /// App Store Connect.
    case addNumber
    /// Take the app off sale in China mainland, through Review & Push.
    case stopSelling

    var id: String { rawValue }

    var title: String {
        switch self {
        case .addNumber: String(localized: "Add an ICP Filing Number")
        case .stopSelling: String(localized: "Stop selling in China mainland")
        }
    }

    func detail(appName: String) -> String {
        switch self {
        case .addNumber:
            String(localized: "Only China’s MIIT issues it, through a local hosting provider. Atlas checks the format.")
        case .stopSelling:
            String(localized: "\(appName) stays everywhere else. The change waits in Review & Push.")
        }
    }
}
