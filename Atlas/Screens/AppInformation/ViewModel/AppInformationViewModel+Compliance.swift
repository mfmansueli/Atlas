//
//  AppInformationViewModel+Compliance.swift
//  Atlas
//

import Foundation

// App Compliance: what each regulation asks is worked out from where the
// app is sold, its categories and its age rating as shown (queued changes
// on top), so it's checked again whenever one of them changes. The
// person's answers are kept on this Mac, since Apple's API takes none of
// them; only "Stop selling in China mainland" is a change in Review &
// Push. Assistants may suggest answers (`+ComplianceSuggestions`), but
// nothing is ever accepted for the person, not even by Accept All.
extension AppInformationViewModel {
    /// The page worked out; nil until the pages and the app's countries
    /// have loaded.
    var complianceReport: ComplianceReport? {
        guard let content = compliance.value, let general, let ageRating else { return nil }
        return ComplianceReport(
            appName: app.name,
            content: content,
            general: general,
            ageRating: ageRating.answers,
            answers: notes.compliance,
            stopsSellingInChina: builder.stopsSelling(in: ComplianceRegion.chinaMainland, with: queue.changes(for: app.id)),
            sellsInApp: sellsInApp
        )
    }

    /// App Store Connect's page for the app, where App Compliance is in
    /// the sidebar under General.
    var appStoreConnectComplianceURL: URL {
        URL(string: "https://appstoreconnect.apple.com/apps/\(app.id)/distribution/info") ?? URL(filePath: "/")
    }

    // MARK: - Digital Services Act

    /// The trader details as edited, else prepared from what's known: the
    /// team's name and App Review's contact. Apple's API doesn't share the
    /// address.
    var traderDetails: TraderDetails {
        notes.compliance.traderDetails ?? TraderDetails(
            name: sellerName ?? "",
            phone: content?.review.phone ?? "",
            email: content?.review.email ?? ""
        )
    }

    func setTraderDetail(_ text: String, for field: TraderDetailField) {
        var details = traderDetails
        guard details[field] != text else { return }
        details[field] = text
        notes.compliance.traderDetails = details
    }

    /// "I’m a Trader" or "Stay a Non-Trader". The details shown become the
    /// person's own.
    func decideTrader(_ decision: TraderDecision) {
        var answers = notes.compliance
        answers.trader = decision
        if decision == .trader { answers.traderDetails = traderDetails }
        notes.compliance = answers
        isEditingTrader = false
        toast = switch decision {
        case .trader: String(localized: "Trader, with these details. Enter them in App Store Connect: Apple’s API doesn’t take them.")
        case .nonTrader: String(localized: "Non-trader. Declare it in App Store Connect: Apple’s API doesn’t take it.")
        }
    }

    /// Change: back to the question.
    func reopenTrader() {
        notes.compliance.trader = nil
    }

    // MARK: - ICP Filing Number

    /// The chosen answer; "Stop selling" is the change in Review & Push,
    /// so discarding it there takes the choice back.
    var icpChoice: ICPChoice? {
        if complianceReport?.stopsSellingInChina == true { return .stopSelling }
        return notes.compliance.addsICPNumber ? .addNumber : nil
    }

    func chooseICP(_ choice: ICPChoice) {
        guard icpChoice != choice else { return }
        switch choice {
        case .addNumber:
            keepSellingInChina()
            notes.compliance.addsICPNumber = true
        case .stopSelling:
            stopSellingInChina(source: .you)
        }
    }

    func setICPNumber(_ text: String) {
        guard notes.compliance.icpNumber != text else { return }
        notes.compliance.icpNumber = text
    }

    // MARK: - Declared in App Store Connect

    /// "Mark as Declared" and its Change, for the rules Apple's API can't
    /// show: the Vietnam license, the medical device declaration and China
    /// mainland's Security Assessment and AI content.
    func setDeclared(_ isDeclared: Bool, for rule: ComplianceRule) {
        if isDeclared {
            notes.compliance.declared.insert(rule)
        } else {
            notes.compliance.declared.remove(rule)
        }
    }
}
