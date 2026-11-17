//
//  AnalyticsSetupStep.swift
//  Atlas
//

import Foundation

/// One line of a setup state's numbered list.
struct AnalyticsSetupStep: Identifiable {
    enum State { case done, current, upcoming }

    var title: String
    var detail: String
    var state = State.upcoming

    var id: String { title }
}
