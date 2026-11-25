//
//  AssistantChatProgressTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The chat's loading states (board 69, 24 Nov): sending before the first
/// step, the steps counted with the answer still to write, then writing
/// the answer. Real units, never time.
@Suite("Chat · how far the answer has come")
struct AssistantChatProgressTests {
    private func item(_ id: Int, _ kind: ClaudeCodeActivity.Kind, _ text: String) -> ClaudeCodeActivity {
        ClaudeCodeActivity(id: id, date: .now, kind: kind, text: text)
    }

    @Test func beforeTheFirstStepItSendsWithNothingToCount() {
        for activity in [[], [item(1, .started, "Claude Code 2.1 started")]] {
            let progress = AssistantChatProgress.make(activity: activity)
            #expect(progress.stage == .sending)
            #expect(progress.current == nil)
            #expect(progress.countLabel == nil)
            #expect(progress.fraction == nil)
            #expect(progress.text(client: "Claude Code") == "Sending to Claude Code…")
            #expect(progress.accessibilityLabel(client: "Claude Code") == "Claude Code: Sending to Claude Code…")
        }
    }

    @Test func eachStepCountsWithTheAnswerStillToWrite() {
        let one = AssistantChatProgress.make(activity: [item(1, .started, "started"), item(2, .atlas, "get_apps")])
        #expect(one.stage == .working)
        #expect(one.countLabel == "1 of 2")
        // The first step shows a sliver: the work began.
        #expect(one.fraction == AssistantChatProgress.firstStepShare)
        #expect(one.text(client: "Claude Code") == "Read apps…")

        let two = AssistantChatProgress.make(activity: [item(1, .atlas, "get_apps"), item(2, .atlas, "get_prices")])
        #expect(two.countLabel == "2 of 3")
        #expect(two.fraction == 1.0 / 3)
        #expect(two.accessibilityLabel(client: "Claude Code") == "Claude Code: Read prices…, 2 of 3")
    }

    @Test func wordsAfterTheLastStepWriteTheAnswer() {
        let activity = [item(1, .atlas, "get_apps"), item(2, .atlas, "get_prices"), item(3, .said, "Brazil, India and Mexico.")]
        let progress = AssistantChatProgress.make(activity: activity)
        #expect(progress.stage == .writing)
        #expect(progress.countLabel == "3 of 3")
        #expect(progress.fraction == 2.0 / 3)
        #expect(progress.text(client: "Claude Code") == "Writing the answer…")
        // A failed step's note doesn't stop the writing.
        #expect(AssistantChatProgress.make(activity: activity + [item(4, .problem, "x failed")]).stage == .writing)
    }

    @Test func theResultIsWritingToo() {
        let progress = AssistantChatProgress.make(activity: [item(1, .atlas, "get_apps")], hasResult: true)
        #expect(progress.stage == .writing)
        #expect(progress.countLabel == "2 of 2")
    }

    @Test func aStepAfterWordsIsWorkAgain() {
        let activity = [item(1, .atlas, "get_apps"), item(2, .said, "Let me read the prices."), item(3, .atlas, "get_prices")]
        let progress = AssistantChatProgress.make(activity: activity)
        #expect(progress.stage == .working)
        #expect(progress.countLabel == "2 of 3")
    }

    @Test func theCountNeverGoesBackWhileStepsCome() {
        var activity: [ClaudeCodeActivity] = []
        var last = 0.0
        for index in 1...8 {
            activity.append(item(index, .file, "File \(index).swift"))
            let fraction = AssistantChatProgress.make(activity: activity).fraction ?? 0
            #expect(fraction >= last)
            last = fraction
        }
        activity.append(item(9, .said, "Done."))
        #expect((AssistantChatProgress.make(activity: activity).fraction ?? 0) > last)
    }
}
