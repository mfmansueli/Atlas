//
//  DebugReleaseData.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Canned release data for Lumen Journal 1.4, as on the design's board 39:
/// builds 212 and 211 ready and 213 still processing, What's New written
/// in every language but Italian (Claude Code suggested it), the Mood
/// Calendar event going with the version. "Today" is Nov 16, 2026.
enum DebugReleaseData {
    typealias AppIDs = DebugFixtures.AppID

    static let today = DebugReviewsData.today
    static let versionID = DebugStorePageContent.editableVersionID
    static let versionString = "1.4"
    static let submissionID = "submission-1.4"
    static let phasedID = "phased-1.4"
    /// The language whose What's New is missing.
    static let missingLocale = StoreLocale.italian

    static func date(day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        Calendar.gmtGregorian.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute)) ?? .now
    }

    static let builds: [ReleaseBuild] = [
        ReleaseBuild(id: "build-213", number: "213", uploaded: today.addingTimeInterval(-12 * 60), processing: .processing),
        ReleaseBuild(id: "build-212", number: "212", uploaded: date(day: 15), processing: .valid),
        ReleaseBuild(id: "build-211", number: "211", uploaded: date(day: 13), processing: .valid, usesNonExemptEncryption: false),
    ]

    /// Lumen 1.4 in `phase`.
    static func status(_ phase: DebugReleasePhase) -> ReleaseStatus {
        var status = ReleaseStatus(
            version: ReleaseVersion(id: versionID, versionString: versionString, platform: "IOS", state: phase.state, timing: .manual),
            builds: builds, attachedBuildID: "build-212"
        )
        switch phase {
        case .prepare, .live:
            break
        case .waiting, .review, .pending:
            status.submission = VersionSubmission(
                id: submissionID, state: phase == .waiting ? "WAITING_FOR_REVIEW" : "IN_REVIEW", submitted: date(day: 16, hour: 10, minute: 42),
                versionID: versionID, eventIDs: [DebugInAppEventsData.moodID]
            )
        case .rejected:
            status.submission = VersionSubmission(
                id: submissionID, state: "UNRESOLVED_ISSUES", submitted: date(day: 16, hour: 10, minute: 42), versionID: versionID,
                eventIDs: [DebugInAppEventsData.moodID]
            )
        case .phased, .paused:
            status.phased = PhasedRelease(id: phasedID, state: phase == .paused ? .paused : .active, day: 3, startDate: date(day: 14))
        }
        if phase == .pending { status.phased = PhasedRelease(id: phasedID, state: .inactive, day: 0) }
        return status
    }

    /// Another sample app: its released version, on the App Store.
    static func released(_ app: StoreApp) -> ReleaseStatus {
        let version = DebugSummaries.storePage(for: app.id).versionString ?? "1.0"
        return ReleaseStatus(version: ReleaseVersion(
            id: "version-\(version)", versionString: version, platform: "IOS", state: "READY_FOR_DISTRIBUTION", timing: .afterApproval
        ))
    }

    /// What's New for 1.4, in every language of Lumen's page but one.
    static let whatsNew: [StoreLocale: String] = {
        let texts: [StoreLocale: String] = [
            .englishUS: "iCloud sync works again, and the new Mood Calendar shows your month in color.",
            .englishUK: "iCloud sync works again, and the new Mood Calendar shows your month in colour.",
            .german: "Die iCloud-Synchronisierung funktioniert wieder, und der neue Stimmungskalender zeigt deinen Monat in Farbe.",
            .french: "La synchronisation iCloud fonctionne à nouveau, et le nouveau calendrier d’humeur montre votre mois en couleurs.",
            .spanishSpain: "La sincronización con iCloud vuelve a funcionar, y el nuevo calendario de ánimo muestra tu mes en color.",
            .spanishMexico: "La sincronización con iCloud funciona de nuevo, y el nuevo calendario de ánimo muestra tu mes a color.",
            .portugueseBrazil: "A sincronização com o iCloud voltou a funcionar, e o novo Calendário de Humor mostra seu mês em cores.",
            .japanese: "iCloudの同期が再び動作するようになりました。新しい気分カレンダーで、ひと月を色で振り返れます。",
            .arabic: "عادت مزامنة iCloud للعمل، وتقويم المزاج الجديد يعرض شهرك بالألوان.",
        ]
        var all = texts
        all[missingLocale] = ""
        return all
    }()

    static let suggestedWhatsNew = "La sincronizzazione con iCloud funziona di nuovo, e il nuovo Calendario dell’umore mostra il tuo mese a colori."

    /// Claude Code's suggestion for the missing What's New.
    @MainActor
    static func suggestions() -> FieldSuggestionStore {
        let store = FieldSuggestionStore()
        store.add(
            appID: AppIDs.lumen, target: .storePage(missingLocale, .whatsNew), value: suggestedWhatsNew,
            reason: "Translated from English, in the voice of your Italian store page.", source: .assistant(client: DebugReviewsData.client)
        )
        return store
    }

    /// A store that saw each step when the design's board says.
    @MainActor
    static func store(_ phase: DebugReleasePhase) -> ReleaseStore {
        let store = ReleaseStore()
        store.now = { today }
        store.setEventIDs([DebugInAppEventsData.moodID], for: AppIDs.lumen)
        guard phase != .prepare else { return store }
        store.setDate(date(day: 16, hour: 10, minute: 42), of: "waiting", versionID: versionID)
        for key in ["review", "rejected", "pending", "approved"] {
            store.setDate(date(day: 17), of: key, versionID: versionID)
        }
        if [.phased, .paused, .live].contains(phase) { store.setDate(date(day: 14), of: "phased", versionID: versionID) }
        return store
    }
}
#endif
