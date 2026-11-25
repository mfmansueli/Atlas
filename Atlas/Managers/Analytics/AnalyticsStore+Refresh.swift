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
            let copy = AppleErrorCopy(String(localized: "Apple wasn’t asked for reports.", comment: "kind:error"), error: error)
            setActivity(.failed(copy.text), for: appID)
        }
    }

    /// "Stop Asking Apple for Reports".
    func stop(for appID: StoreApp.ID, services: any AnalyticsServices) async -> String? {
        do {
            try await services.stopReports(appID: appID)
            turnOff(appID)
            return nil
        } catch {
            return AppleErrorCopy(String(localized: "Reports weren’t stopped.", comment: "kind:error"), error: error).text
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
                // The newer reports come with the same request. One that
                // fails doesn't keep the funnel from showing.
                do {
                    let reports = try await services.downloadReports(appID: appID, known: reports(for: appID).instanceIDs)
                    apply(reports, to: appID)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    reportsError = AppleErrorCopy(String(localized: "Some reports didn’t load.", comment: "kind:error"), error: error).text
                }
                if let setting = try? await services.gracePeriod(appID: appID) { setGracePeriod(setting, for: appID) }
            } else if record(for: appID).askedOn != nil {
                // Apple stops requests nobody reads for a long time.
                turnOff(appID)
            }
            setActivity(.loading(finished: 1), for: appID)
            await refreshSales(services: services)
            update(appID) { $0.lastChecked = now() }
            setActivity(.idle, for: appID)
        } catch {
            let copy = AppleErrorCopy(String(localized: "Analytics didn’t load.", comment: "kind:error"), error: error)
            setActivity(.failed(copy.text), for: appID)
        }
    }

    /// "Turn On Billing Grace Period…", once the person confirmed it.
    func turnOnGracePeriod(for appID: StoreApp.ID, duration: GracePeriodSetting.Duration, services: any AnalyticsServices) async throws {
        let setting: GracePeriodSetting? = if let known = gracePeriods[appID] { known } else { try await services.gracePeriod(appID: appID) }
        guard let setting else { throw AnalyticsActionError.noGracePeriodSetting }
        try await services.turnOnGracePeriod(setting, duration: duration)
        setGracePeriod(GracePeriodSetting(id: setting.id, isOn: true, duration: duration), for: appID)
    }

    /// Reads the days of Sales and Trends this Mac doesn't have yet.
    func refreshSales(services: any AnalyticsServices) async {
        let vendorNumber = settings.vendorNumber
        guard !vendorNumber.isEmpty else { return }
        askedForSalesThisLaunch = true
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
            setSalesProblem(keyCannotRead: false, error: Self.salesProblem(in: download))
        } catch AppStoreConnectError.forbidden {
            setSalesProblem(keyCannotRead: true, error: nil)
        } catch let error as SalesVendorNumberError {
            setSalesProblem(keyCannotRead: settings.keyCannotReadSales, error: error.localizedDescription)
        } catch {
            let copy = AppleErrorCopy(String(localized: "Sales didn’t load.", comment: "kind:error"), error: error)
            setSalesProblem(keyCannotRead: settings.keyCannotReadSales, error: copy.text)
        }
    }

    /// "Sales for 12 days didn’t load…" with Apple's words in Details, when
    /// some days failed; the days that loaded are already kept.
    static func salesProblem(in download: SalesDownload) -> String? {
        let count = download.failedDays.count
        guard count > 0 else { return nil }
        let what = count == 1
            ? String(localized: "Sales for one day didn’t load. Atlas asks again at the next check.", comment: "kind:error")
            : String(localized: "Sales for \(count) days didn’t load. Atlas asks again at the next check.", comment: "kind:error")
        return AppleErrorCopy(summary: what, details: download.failure?.details).text
    }

    /// A vendor number with not one day of sales read, not asked for yet
    /// since launch: a failed first read shouldn't wait a whole day.
    var hasNeverReadSales: Bool {
        !settings.vendorNumber.isEmpty && sales.days.isEmpty && !settings.keyCannotReadSales && !askedForSalesThisLaunch
    }

    /// Whether `appID`'s reports should be checked now: never checked, or
    /// not yet today.
    func isDue(_ appID: StoreApp.ID) -> Bool {
        guard record(for: appID).askedOn != nil else { return false }
        if hasNeverReadSales { return true }
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
