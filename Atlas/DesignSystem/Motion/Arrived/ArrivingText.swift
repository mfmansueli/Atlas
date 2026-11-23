//
//  ArrivingText.swift
//  Atlas
//

import SwiftUI

/// Effect 3 · Arrived, the text version (README — Design System §7, v2):
/// an assistant's words come in one by one, each over 0.28 s and 35 ms
/// after the one before, from a 2 pt blur and 2 pt lower, with a caret after
/// the newest word that leaves once the last one is in (streamed suggestion
/// text, the assistant's first hello). With Reduce Motion the whole text
/// fades in over 0.2 s. It plays when the text first appears and again when
/// the text changes; VoiceOver reads the text at once.
struct ArrivingText: View {
    let text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var elapsed: TimeInterval = 0
    @State private var isShown = false

    nonisolated static let wordDuration: TimeInterval = 0.28
    nonisolated static let wordDelay: TimeInterval = 0.035
    static let reducedDuration: TimeInterval = 0.2
    /// How long the caret takes to leave after the last word.
    nonisolated static let caretFade: TimeInterval = 0.2

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
                    .textRenderer(Renderer(elapsed: elapsed, total: Self.duration(wordCount: Self.words(in: text).count)))
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
        let total = Self.duration(wordCount: Self.words(in: text).count) + Self.caretFade
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
    nonisolated static func progress(ofWord index: Int, at elapsed: TimeInterval) -> Double {
        let linear = min(max((elapsed - Double(index) * wordDelay) / wordDuration, 0), 1)
        return 1 - pow(1 - linear, 3)
    }

    /// The caret's opacity at `elapsed`: there while the words arrive, gone
    /// `caretFade` after the last one is in (`total`).
    nonisolated static func caretOpacity(at elapsed: TimeInterval, total: TimeInterval) -> Double {
        guard elapsed > 0 else { return 0 }
        guard elapsed > total else { return 1 }
        return max(0, 1 - (elapsed - total) / caretFade)
    }

    private struct Word: TextAttribute {
        var index: Int
    }

    /// Draws each word at its own point of arriving, and the caret after
    /// the newest.
    private struct Renderer: TextRenderer, Animatable {
        var elapsed: TimeInterval
        /// When the last word is in.
        let total: TimeInterval

        var animatableData: Double {
            get { elapsed }
            set { elapsed = newValue }
        }

        func draw(layout: Text.Layout, in context: inout GraphicsContext) {
            var newest: CGRect?
            for line in layout {
                for run in line {
                    guard let word = run[Word.self] else {
                        context.draw(run)
                        continue
                    }
                    let progress = ArrivingText.progress(ofWord: word.index, at: elapsed)
                    guard progress > 0 else { continue }
                    newest = run.typographicBounds.rect
                    var copy = context
                    copy.opacity = progress
                    if progress < 1 {
                        copy.addFilter(.blur(radius: 2 * (1 - progress)))
                        copy.translateBy(x: 0, y: 2 * (1 - progress))
                    }
                    copy.draw(run)
                }
            }
            drawCaret(after: newest, in: &context)
        }

        private func drawCaret(after word: CGRect?, in context: inout GraphicsContext) {
            let opacity = ArrivingText.caretOpacity(at: elapsed, total: total)
            guard let word, opacity > 0 else { return }
            var copy = context
            copy.opacity = opacity
            let caret = CGRect(x: word.maxX + 1, y: word.minY, width: 1.5, height: word.height)
            copy.fill(Path(caret), with: .color(Palette.aiFill))
        }
    }
}

#Preview {
    ArrivingText("Hi! I’m connected to Atlas and I can see Lumen Journal: version 1.4, 12 languages, 3 subscriptions.")
        .frame(width: 360)
        .padding()
}
