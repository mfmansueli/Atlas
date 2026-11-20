//
//  ProductPagesAskPrompt.swift
//  Atlas
//

import Foundation

/// The run the section's asking buttons start, so each finds its own.
enum ProductPagesAskPrompt {
    static var purpose: ClaudeCodeRunPurpose { .ask(area: String(localized: "Custom Product Pages")) }
}
