//
//  EnvironmentValues+AskCenter.swift
//  Atlas
//

import SwiftUI

extension EnvironmentValues {
    /// The requests sent from asking buttons, when a test or DEBUG scene
    /// gives its own; nil is `AssistantAskCenter.shared`.
    @Entry var askCenterOverride: AssistantAskCenter?
}
