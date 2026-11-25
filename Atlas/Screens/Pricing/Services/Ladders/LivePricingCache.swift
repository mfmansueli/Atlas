//
//  LivePricingCache.swift
//  Atlas
//

import Foundation

/// Apple's price point ladders, per product, commission and territory: in
/// memory, and on this Mac (`PriceLadderDiskStore`) outside unit tests and
/// DEBUG scenes. A product's ladders take about 21 requests (175
/// territories in batches of 25, a few pages each) of the 3,600 an hour,
/// and Apple changes its points only a few times a year, with tax and
/// exchange-rate updates it announces days ahead. So a ladder is kept for
/// 7 days, and a push that changes a product's prices drops what was read
/// before it (`forget(productID:fetchedBefore:)`): the next suggestions
/// then stand on points read after Apple took the new prices, and a point
/// Apple retired since can't be proposed again.
///
/// One product is read once at a time (`serialized`): a second caller
/// waits for the read under way and finds its ladders here.
@MainActor
final class LivePricingCache {
    /// How long a fetched ladder is used.
    static let maxAge: TimeInterval = 7 * 24 * 60 * 60

    /// Application Support outside unit tests and DEBUG scenes, which keep
    /// ladders in memory only.
    static var defaultDirectory: URL? {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return nil }
        #endif
        return PriceLadderDiskStore.defaultDirectory
    }

    private struct Entry {
        var ladder: PricePointLadder
        var fetchedAt: Date
    }

    /// By product, commission, then territory.
    private var entries: [String: [Commission: [String: Entry]]] = [:]
    private var diskReads: [String: Task<StoredPriceLadders?, Never>] = [:]
    /// Products whose file has been merged into `entries`.
    private var mergedProductIDs: Set<String> = []
    private var diskWrites: [String: Task<Void, Never>] = [:]
    private var readingProductIDs: Set<String> = []
    private var waiting: [String: [CheckedContinuation<Void, Never>]] = [:]
    private let store: PriceLadderDiskStore?
    let maxAge: TimeInterval
    var now: () -> Date

    init(directory: URL? = LivePricingCache.defaultDirectory, maxAge: TimeInterval = LivePricingCache.maxAge, now: @escaping () -> Date = { .now }) {
        store = directory.map(PriceLadderDiskStore.init(directory:))
        self.maxAge = maxAge
        self.now = now
    }

    // MARK: - Reading

    /// The territories' ladders read in the last `maxAge`, from memory or
    /// this Mac.
    func ladders(for productID: String, commission: Commission, territoryIDs: some Sequence<String>) async -> [String: PricePointLadder] {
        await loadFromDisk(productID)
        let kept = entries[productID]?[commission] ?? [:]
        let oldest = now().addingTimeInterval(-maxAge)
        var result: [String: PricePointLadder] = [:]
        for territoryID in territoryIDs {
            guard let entry = kept[territoryID], entry.fetchedAt > oldest else { continue }
            result[territoryID] = entry.ladder
        }
        return result
    }

    /// When the territory's kept ladder was read; nil when none is kept.
    func fetchDate(productID: String, commission: Commission, territoryID: String) -> Date? {
        entries[productID]?[commission]?[territoryID]?.fetchedAt
    }

    /// When each of the product's kept ladders was read, by territory.
    func fetchDates(productID: String, commission: Commission) -> [String: Date] {
        (entries[productID]?[commission] ?? [:]).mapValues(\.fetchedAt)
    }

    // MARK: - Writing

    /// Keeps ladders Apple just sent, dated now, and writes the product's
    /// file.
    func store(_ ladders: [String: PricePointLadder], for productID: String, commission: Commission) {
        guard !ladders.isEmpty else { return }
        let date = now()
        for (territoryID, ladder) in ladders where !ladder.isEmpty {
            entries[productID, default: [:]][commission, default: [:]][territoryID] = Entry(ladder: ladder, fetchedAt: date)
        }
        persist(productID)
    }

    /// Drops the product's ladders read before `date`, in memory and on
    /// disk: after a push that changed its prices. Ladders read after it
    /// stay, so calling it again for the same push reads nothing again.
    func forget(productID: String, fetchedBefore date: Date) async {
        await loadFromDisk(productID)
        guard var byCommission = entries[productID] else { return }
        var changed = false
        for (commission, territories) in byCommission {
            let kept = territories.filter { $0.value.fetchedAt >= date }
            if kept.count != territories.count { changed = true }
            byCommission[commission] = kept
        }
        guard changed else { return }
        entries[productID] = byCommission
        persist(productID)
    }

    /// Everything, in memory and on disk.
    func removeAll() {
        let productIDs = Array(entries.keys)
        entries = [:]
        for productID in productIDs { persist(productID) }
    }

    // MARK: - One read at a time

    /// Runs `read` once no other read of the same product is under way.
    func serialized<T>(productID: String, _ read: () async throws -> T) async rethrows -> T {
        while readingProductIDs.contains(productID) {
            await withCheckedContinuation { continuation in
                waiting[productID, default: []].append(continuation)
            }
        }
        readingProductIDs.insert(productID)
        defer {
            readingProductIDs.remove(productID)
            let continuations = waiting.removeValue(forKey: productID) ?? []
            for continuation in continuations { continuation.resume() }
        }
        return try await read()
    }

    /// Whether a read of the product is under way, for tests.
    func isReading(_ productID: String) -> Bool {
        readingProductIDs.contains(productID)
    }

    // MARK: - Private

    /// Reads the product's file once, off the main actor; memory keeps
    /// anything newer.
    private func loadFromDisk(_ productID: String) async {
        guard let store else { return }
        let read: Task<StoredPriceLadders?, Never>
        if let existing = diskReads[productID] {
            read = existing
        } else {
            read = Task.detached(priority: .utility) { store.read(productID: productID) }
            diskReads[productID] = read
        }
        guard let stored = await read.value else { return }
        // Merged once: later calls find the same task and nothing new.
        guard !mergedProductIDs.contains(productID) else { return }
        mergedProductIDs.insert(productID)
        for (rawCommission, territories) in stored.ladders {
            guard let commission = Commission(rawValue: rawCommission) else { continue }
            for (territoryID, ladder) in territories {
                if let kept = entries[productID]?[commission]?[territoryID], kept.fetchedAt >= ladder.fetchedAt { continue }
                let entry = Entry(ladder: StoredPriceLadders.pricePointLadder(ladder, territoryID: territoryID), fetchedAt: ladder.fetchedAt)
                entries[productID, default: [:]][commission, default: [:]][territoryID] = entry
            }
        }
    }

    /// Writes the product's ladders, after any write of it still under way.
    private func persist(_ productID: String) {
        guard let store else { return }
        var stored = StoredPriceLadders(productID: productID)
        for (commission, territories) in entries[productID] ?? [:] {
            stored.ladders[commission.rawValue] = territories.mapValues { StoredPriceLadders.ladder($0.ladder, fetchedAt: $0.fetchedAt) }
        }
        let previous = diskWrites[productID]
        diskWrites[productID] = Task.detached(priority: .utility) {
            await previous?.value
            store.write(stored)
        }
    }

    /// Waits for every file write under way, for tests.
    func finishWriting() async {
        for write in diskWrites.values { await write.value }
    }
}
