//
//  PushProcessingTests.swift
//  AtlasTests
//

import Foundation
import Synchronization
import Testing
@testable import Atlas

/// An upload Apple is processing gives its place to the next change: the
/// event art says when Apple takes over, and checks back less often the
/// more uploads are processing, within the hourly budget.
@MainActor
@Suite("Push · not waiting for Apple's processing")
struct PushProcessingTests {
    private static let file = Data((0..<200).map { UInt8($0 % 251) })

    @Test func aProcessingUploadFreesItsPlaceUpToALimit() {
        let places = PushSchedule.concurrentChanges
        #expect(!PushSchedule.hasRoom(running: places, waitingOnApple: 0))
        #expect(PushSchedule.hasRoom(running: places, waitingOnApple: 1))
        let full = places + PushSchedule.processingAtOnce
        #expect(!PushSchedule.hasRoom(running: full, waitingOnApple: PushSchedule.processingAtOnce))
    }

    @Test func checksSpreadOutTheMoreAreProcessing() {
        #expect(PushSchedule.pollInterval(waitingOnApple: 0) == .seconds(2))
        #expect(PushSchedule.pollInterval(waitingOnApple: 1) == .seconds(2))
        #expect(PushSchedule.pollInterval(waitingOnApple: 6) == .seconds(12))
        // About one check every 2 s in all, whatever the count: 1,800 an hour at most.
        let count = PushSchedule.processingAtOnce
        let perSecond = Double(count) / Double(PushSchedule.pollInterval(waitingOnApple: count).components.seconds)
        #expect(perSecond <= 0.5)
    }

    @Test func theArtSaysWhenAppleTakesOverAndWaitsAsLongAsItIsTold() async throws {
        let transport = FakeEventArtworkTransport(.init(processingChecks: 2))
        let push = InAppEventArtworkPush(
            localizationID: "loc-de", kind: .details, isVideo: true, fileName: "loop.mov", fileSize: Self.file.count, path: "/tmp/loop.mov",
            previewFrameTimeCode: "00:00:01:15"
        )
        let handedOver = Mutex(0)
        let pauses = Mutex<[Duration]>([])

        _ = try await push.send(
            via: transport,
            readFile: { _ in Self.file },
            sleep: { pause in pauses.withLock { $0.append(pause) } },
            processing: { handedOver.withLock { $0 += 1 } },
            pollInterval: { .seconds(7) }
        )

        #expect(handedOver.withLock { $0 } == 1)
        #expect(pauses.withLock { $0 } == [.seconds(7), .seconds(7)])
        let log = transport.log
        let commit = try #require(log.firstIndex { $0.hasPrefix("commit") })
        #expect(log[(commit + 1)...].allSatisfy { $0.hasPrefix("status") })
    }
}
