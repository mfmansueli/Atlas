//
//  PushProgressNote+Live.swift
//  Atlas
//

import Foundation

/// The notes of the pushes going now: the extras run's pause, cancel and
/// room for the next upload, the screenshot run's pause or what it did to
/// the live sets, and why extras couldn't be noted in their set.
@MainActor
extension PushProgressNote {
    static func notes(for push: PushController, subtitle: String) -> [PushProgressNote] {
        var notes: [PushProgressNote] = []
        let extras = push.screenshots.extras
        if let run = extras.run {
            if let pause = run.pauseTitle {
                notes.append(PushProgressNote(identifier: "review.extras.progress.pause", text: pause, systemImage: "pause.circle", tone: .warning))
            } else if let cancelling = run.cancellingTitle {
                notes.append(PushProgressNote(identifier: "review.extras.progress.cancelling", text: cancelling, systemImage: "stop.circle"))
            } else if let room = run.roomTitle {
                notes.append(PushProgressNote(identifier: "review.extras.progress.room", text: room, systemImage: "hourglass"))
            }
            if run.phase == .finished, let reason = run.stopReason {
                notes.append(PushProgressNote(identifier: "push.note.extras", text: reason, systemImage: "info.circle"))
            }
        }
        if let run = push.screenshots.run {
            if run.isRunning, run.pausedUntil != nil {
                notes.append(PushProgressNote(identifier: "push.note.shots", text: run.subtitle, systemImage: "pause.circle", tone: .warning))
            } else if run.phase == .finished, run.subtitle != subtitle {
                notes.append(PushProgressNote(identifier: "push.note.shots", text: run.subtitle, systemImage: "photo.on.rectangle"))
            }
        }
        if let error = extras.recordError {
            notes.append(PushProgressNote(identifier: "push.note.extrasRecord", text: error, systemImage: "exclamationmark.triangle", tone: .danger))
        }
        return notes
    }
}
