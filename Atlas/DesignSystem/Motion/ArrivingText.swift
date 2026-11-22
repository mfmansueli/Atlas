//
//  ArrivingText.swift
//  Atlas
//

import SwiftUI

/// AI motion 3, "Text arriving" (README — Design System §7): an
/// assistant's words come in one by one, each over 0.28 s and 35 ms after
/// the one before, from a 2 pt blur and 2 pt lower (streamed suggestion
/// text, the assistant's first hello). With Reduce Motion the whole text
/// fades in over 0.2 s. It plays when the text first appears and again
/// when the text changes; VoiceOver reads the text at once.
struct ArrivingText: View {
    let text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var elapsed: TimeInterval = 0
    @State private var isShown = false

    static let wordDuration: TimeInterval = 0.28
    static let wordDelay: TimeInterval = 0.035
    static let reducedDuration: TimeInterval = 0.2

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Group {
            if reduceMotion {
                Text(text)
                    .opacity(isShown ? 1 : 0)
            } else {
                words
                    .textRenderer(Renderer(elapsed: elapsed))
            }
        }
        .accessibilityLabel(Text(text))
        .task(id: text) { play() }
    }

    /// Each word marked with its place, so the renderer can delay it.
    private var words: Text {
        let parts = Self.words(in: text)
        return parts.enumerated().reduce(Text(verbatim: "")) { sentence, part in
            let piece = Text(verbatim: part.element).customAttribute(Word(index: part.offset))
            return Text("\(sentence)\(piece)")
        }
    }

    private func play() {
        if reduceMotion {
            isShown = false
            withAnimation(.easeOut(duration: Self.reducedDuration)) { isShown = true }
            return
        }
        elapsed = 0
        let total = Self.duration(wordCount: Self.words(in: text).count)
        withAnimation(.linear(duration: total)) { elapsed = total }
    }

    /// How long `wordCount` words take to arrive.
    static func duration(wordCount: Int) -> TimeInterval {
        guard wordCount > 0 else { return 0 }
        return Double(wordCount - 1) * wordDelay + wordDuration
    }

    /// The words with the spaces after them, so the text reads as written.
    static func words(in text: String) -> [String] {
        var words: [String] = []
        var current = ""
        var inSpace = false
        for character in text {
            if character.isWhitespace {
                inSpace = true
            } else if inSpace {
                words.append(current)
                current = ""
                inSpace = false
            }
            current.append(character)
        }
        if !current.isEmpty { words.append(current) }
        return words
    }

    /// How far word `index` has arrived at `elapsed` seconds, eased (0–1).
    static func progress(ofWord index: Int, at elapsed: TimeInterval) -> Double {
        let linear = min(max((elapsed - Double(index) * wordDelay) / wordDuration, 0), 1)
        return 1 - pow(1 - linear, 3)
    }

    private struct Word: TextAttribute {
        var index: Int
    }

    /// Draws each word at its own point of arriving.
    private struct Renderer: TextRenderer, Animatable {
        var elapsed: TimeInterval

        var animatableData: Double {
            get { elapsed }
            set { elapsed = newValue }
        }

        func draw(layout: Text.Layout, in context: inout GraphicsContext) {
            for line in layout {
                for run in line {
                    guard let word = run[Word.self] else {
                        context.draw(run)
                        continue
                    }
                    let progress = ArrivingText.progress(ofWord: word.index, at: elapsed)
                    guard progress > 0 else { continue }
                    var copy = context
                    copy.opacity = progress
                    if progress < 1 {
                        copy.addFilter(.blur(radius: 2 * (1 - progress)))
                        copy.translateBy(x: 0, y: 2 * (1 - progress))
                    }
                    copy.draw(run)
                }
            }
        }
    }
}

#Preview {
    ArrivingText("Hi! I’m connected to Atlas and I can see Lumen Journal: version 1.4, 12 languages, 3 subscriptions.")
        .frame(width: 360)
        .padding()
}
