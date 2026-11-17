//
//  AnalyticsStore+Refresh.swift
//  Atlas
//

import Foundation

/// Asking Apple, stopping, and the download every view starts from.
extension AnalyticsStore {
    /// Days of sales read the first time: 90 days against the 90 before.
    static let salesHistoryDays = 180
    /// The newest days are read again each time: Apple fills them in late.
    static let salesRereadDays = 3
    /// Older than this, the data is "older than expected".
    static let staleAfterDays = 4

    /// "Ask Apple for Reports". A refusal for the key's role is remembered
    /// and shown as its own state, not as an error.
    func ask(for appID: StoreApp.ID, services: any AnalyticsServices) async {
        setActivity(.loading(finished: 0), for: appID)
        do {
            try await services.askForReports(appID: appID)
            update(appID) { record in
                record.askedOn = now()
                record.keyCannotAsk = false
            }
            setActivity(.idle, for: appID)
        } catch AppStoreConnectError.forbidden {
            update(appID) { $0.keyCannotAsk = true }
            setActivity(.idle, for: appID)
        } catch {
            setActivity(.failed(error.localizedDescription), for: appID)
        }
    }

    /// "Stop Asking Apple for Reports".
    func stop(for appID: StoreApp.ID, services: any AnalyticsServices) async -> String? {
        do {
            try await services.stopReports(appID: appID)
            turnOff(appID)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Checks what Apple has and downloads what's new: the app's report
    /// instances, then the vendor's sales.
    func refresh(_ appID: StoreApp.ID, services: any AnalyticsServices) async {
        guard !activity(for: appID).isLoading else { return }
        setActivity(.loading(finished: 0), for: appID)
        do {
            let status = try await services.requestStatus(appID: appID)
            if status.isOn {
                // A request made elsewhere (or on another Mac) counts as asked.
                if record(for: appID).askedOn == nil { update(appID) { $0.askedOn = now() } }
                update(appID) { $0.keyCannotAsk = false }
                let batches = try await services.downloadEngagement(appID: appID, known: archive(for: appID).instanceIDs)
                apply(batches, to: appID)
            } else if record(for: appID).askedOn != nil {
                // Apple stops requests nobody reads for a long time.
                turnOff(appID)
            }
            setActivity(.loading(finished: 1), for: appID)
            await refreshSales(services: services)
            update(appID) { $0.lastChecked = now() }
            setActivity(.idle, for: appID)
        } catch {
            setActivity(.failed(error.localizedDescription), for: appID)
        }
    }

    /// Reads the days of Sales and Trends this Mac doesn't have yet.
    func refreshSales(services: any AnalyticsServices) async {
        let vendorNumber = settings.vendorNumber
        guard !vendorNumber.isEmpty else { return }
        let yesterday = AnalyticsDay(now()).adding(-1)
        let reread = Set((0..<Self.salesRereadDays).map { yesterday.adding(-$0).number })
        let days = (0..<Self.salesHistoryDays)
            .map { yesterday.adding(-$0) }
            .filter { reread.contains($0.number) || !sales.days.contains($0.number) }
        // Active subscriptions now, and a period earlier for each period.
        let activeDays = [0, 7, 28, 90].map { yesterday.adding(-$0) }.filter { $0 == yesterday || !sales.activeDays.contains($0.number) }
        do {
            let download = try await services.downloadSales(vendorNumber: vendorNumber, days: days, activeDays: activeDays)
            apply(download)
            setSalesProblem(keyCannotRead: false, error: nil)
        } catch AppStoreConnectError.forbidden {
            setSalesProblem(keyCannotRead: true, error: nil)
        } catch {
            setSalesProblem(keyCannotRead: settings.keyCannotReadSales, error: error.localizedDescription)
        }
    }

    /// Whether `appID`'s reports should be checked now: never checked, or
    /// not yet today.
    func isDue(_ appID: StoreApp.ID) -> Bool {
        guard record(for: appID).askedOn != nil else { return false }
        guard let last = record(for: appID).lastChecked else { return true }
        return AnalyticsDay(last) < AnalyticsDay(now())
    }

    /// How many days behind today the newest data is, when that's more
    /// than Apple's usual 1 to 2.
    func staleDays(through: AnalyticsDay?) -> Int? {
        guard let through else { return nil }
        let behind = AnalyticsDay(now()).number - through.number
        return behind >= Self.staleAfterDays ? behind : nil
    }
}
