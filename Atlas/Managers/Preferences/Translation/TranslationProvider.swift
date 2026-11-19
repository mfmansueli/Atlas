//
//  TranslationProvider.swift
//  Atlas
//

import Foundation

/// Settings → Translation → Provider: who translates missing store text.
enum TranslationProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Apple's Translation framework, on this Mac.
    case appleTranslation
    /// An AI provider with the person's own API key.
    case aiProvider
    /// The AI assistant connected through MCP (Settings → AI Assistants).
    case assistant

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleTranslation: String(localized: "Apple Translation · on this Mac")
        case .aiProvider: String(localized: "AI provider")
        case .assistant: String(localized: "Your AI assistant · MCP")
        }
    }

    var summary: String {
        switch self {
        case .appleTranslation: String(localized: "Free and private. No keyword optimization.")
        case .aiProvider: String(localized: "App Store-optimized keywords and natural What’s New.")
        case .assistant: String(localized: "Uses the assistant connected in AI Assistants, on its own plan. No API key here.")
        }
    }

    /// Settings → AI Assistants → "Where suggestions come from" (board 48).
    var sourceTitle: String {
        switch self {
        case .assistant: String(localized: "Your AI assistant")
        case .aiProvider: String(localized: "An API key")
        case .appleTranslation: String(localized: "Built-in only")
        }
    }

    var sourceDetail: String {
        switch self {
        case .assistant: String(localized: "Claude Code or another assistant that speaks MCP, on its own plan. No API key here.")
        case .aiProvider: String(localized: "Atlas asks the provider directly from this Mac. You pay the provider for what you use.")
        case .appleTranslation: String(localized: "Atlas’s own checks, and Apple’s translation on this Mac. Free and private; no keyword work.")
        }
    }
}
