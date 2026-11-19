//
//  PushProgressState+Title.swift
//  Atlas
//

import Foundation

extension PushProgressState {
    /// "Waiting", "Sending", "Pushed", "Failed", "Not sent", for the
    /// viewer's subtitle.
    var title: String {
        switch self {
        case .waiting: String(localized: "Waiting")
        case .sending: String(localized: "Sending")
        case .done: String(localized: "Pushed")
        case .failed: String(localized: "Failed")
        case .notSent: String(localized: "Not sent")
        }
    }
}
