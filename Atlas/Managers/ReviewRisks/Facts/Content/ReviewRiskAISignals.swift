//
//  ReviewRiskAISignals.swift
//  Atlas
//

import Foundation

/// Signs that an app offers AI generation or synthetic content: words
/// like "AI", "chatbot", "image generator", "人工智能" in the store texts,
/// a model provider named in App Review's notes, and AI packages and
/// modules in the project (OpenAI, Anthropic, Google's generative AI,
/// DeepSeek, Qwen, MLX, Foundation Models, Image Playground).
struct ReviewRiskAISignals: Hashable, Sendable {
    var signals: [ReviewRiskSignal]

    init(signals: [ReviewRiskSignal]) {
        self.signals = signals
    }

    init(_ facts: ReviewRiskFacts) {
        signals = ReviewRiskSignalScanner.scan([.aiGeneration, .aiCreation, .usAIProvider, .otherAIProvider], in: facts)
    }

    var isEmpty: Bool { signals.isEmpty }

    /// Models from OpenAI, Anthropic or Google: none has a filing with the
    /// Cyberspace Administration of China.
    var usProviders: [ReviewRiskSignal] { signals.filter { $0.topic == .usAIProvider } }

    /// What it generates, from the words and Apple's AI frameworks (not a
    /// provider's name alone).
    var generation: [ReviewRiskSignal] { signals.filter { $0.topic == .aiGeneration || $0.topic == .aiCreation } }

    /// Images, videos, voices, faces or avatars made with AI.
    var creation: [ReviewRiskSignal] { signals.filter { $0.topic == .aiCreation } }

    /// The first words found: "“AI chat” and “OpenAI”".
    var terms: String { ReviewRiskSignal.terms(signals) }
}
