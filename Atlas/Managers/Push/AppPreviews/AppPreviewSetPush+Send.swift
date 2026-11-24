//
//  AppPreviewSetPush+Send.swift
//  Atlas
//

import Foundation

extension AppPreviewSetPush {
    /// Uploads the new videos, waits for Apple, deletes the live ones that
    /// go and puts the set in order. Returns the set's ID.
    @MainActor
    @discardableResult
    func send(
        via transport: any PushTransport,
        readFile: (String) throws -> Data = { try Data(contentsOf: URL(fileURLWithPath: $0)) },
        sleep: (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        note: (AppStoreConnectRateLimit?) -> Void = { _ in },
        progress: (String) -> Void = { _ in },
        processing: () -> Void = {},
        pollInterval: () -> Duration = { ProductPageScreenshotsPush.pollInterval }
    ) async throws -> String {
        guard let uploads = transport as? any ScreenshotUploadTransport else { throw ProductPageScreenshotsPushError.cannotUpload }
        guard content.slots.count <= Self.media.limit else { throw AppPreviewSetPushError.tooMany(count: content.slots.count) }
        let data = try videos(readFile: readFile)
        var (setID, live) = try await set(via: transport, note: note)
        var deletes = content.deletedIDs.filter(live.contains)
        // A set takes 3: make room first only when the new ones wouldn't fit.
        if live.count + data.count > Self.media.limit {
            try await Self.media.delete(deletes, via: transport, note: note)
            live.removeAll(where: deletes.contains)
            deletes = []
        }
        let uploaded = try await upload(data, into: setID, via: transport, uploads: uploads, note: note, progress: progress)
        if !uploaded.isEmpty {
            progress(String(localized: "Apple is processing the App Previews", comment: "kind:status"))
            processing()
        }
        for (index, id) in uploaded.sorted(by: { $0.key < $1.key }) {
            let fileName = content.slots[index].fileName
            try await Self.media.waitUntilProcessed(id, fileName: fileName, via: transport, sleep: sleep, note: note, interval: pollInterval)
        }
        try await Self.media.delete(deletes, via: transport, note: note)
        live.removeAll(where: deletes.contains)
        let ids = Self.order(content.slots, uploaded: uploaded, live: live)
        if !ids.isEmpty {
            try await note(transport.send(Self.media.reorder(setID: setID, ids: ids)).rateLimit)
        }
        return setID
    }

    /// The set's App Previews in the person's order: each place's upload
    /// or its live one, leaving out a live one that's gone.
    static func order(_ slots: [Slot], uploaded: [Int: String], live: [String]) -> [String] {
        slots.enumerated().compactMap { index, slot in
            if slot.file != nil { return uploaded[index] }
            return slot.liveID.flatMap { live.contains($0) ? $0 : nil }
        }
    }

    /// Each new video's bytes by place, read before anything is sent.
    private func videos(readFile: (String) throws -> Data) throws -> [Int: Data] {
        var data: [Int: Data] = [:]
        for (index, slot) in content.slots.enumerated() {
            guard let file = slot.file else { continue }
            do {
                data[index] = try readFile(file.path)
            } catch {
                throw AppPreviewSetPushError.fileMissing(fileName: file.fileName)
            }
        }
        return data
    }

    /// The localization's set of the device and the App Previews in it, or
    /// a new empty one.
    @MainActor
    private func set(via transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void) async throws -> (String, [String]) {
        let sets = try await transport.fetch(setsPath)
        note(sets.rateLimit)
        if let existing = try Self.media.existingSet(in: sets.data, displayType: content.displayType) {
            return (existing.id, existing.itemIDs)
        }
        let created = try await transport.send(createSet)
        note(created.rateLimit)
        return try (ScreenshotUploadRequests.createdID(in: created.data), [])
    }

    /// Reserves, uploads and commits each video in order; their IDs by place.
    @MainActor
    private func upload(
        _ data: [Int: Data], into setID: String, via transport: any PushTransport, uploads: any ScreenshotUploadTransport,
        note: (AppStoreConnectRateLimit?) -> Void, progress: (String) -> Void
    ) async throws -> [Int: String] {
        var uploaded: [Int: String] = [:]
        let order = data.keys.sorted()
        for (step, index) in order.enumerated() {
            guard let file = content.slots[index].file, let bytes = data[index] else { continue }
            progress(String(localized: "Pushing App Preview \(step + 1) of \(order.count)", comment: "kind:status"))
            let reserve = try await transport.send(Self.media.reserve(file, fileSize: bytes.count, setID: setID))
            note(reserve.rateLimit)
            let reservation = try ScreenshotUploadRequests.reservation(in: reserve.data)
            for operation in reservation.operations {
                try await uploads.upload(operation, data: bytes) { _ in }
            }
            try await note(transport.send(Self.media.commit(id: reservation.id, checksum: ScreenshotPNG.checksum(bytes))).rateLimit)
            uploaded[index] = reservation.id
        }
        return uploaded
    }
}
