//
//  AppInformationViewModel+ChinaDeclarations.swift
//  Atlas
//

import Foundation

// China mainland's Security Assessment and AI-generated content
// declarations (App Store Connect, November 2026), asked of every app, sold
// there or not. Apple's API neither shows nor takes them, so Yes and No are
// kept on this Mac until the person enters them in App Store Connect and
// marks them as declared; an app not sold there starts at No. "Stop selling
// in China mainland" is the one answer Apple's API takes: the same change
// in Review & Push as the ICP Filing Number's, after which both are No.
extension AppInformationViewModel {
    /// The chosen answer: stopping sales when that change waits in Review
    /// & Push, else the answer kept here, else No when the app isn't sold
    /// in China mainland.
    func chinaChoice(for rule: ComplianceRule) -> ChinaDeclarationChoice? {
        guard let report = complianceReport else { return nil }
        if report.stopsSellingInChina { return .stopSelling }
        let answer: Bool? = switch rule {
        case .securityAssessment: report.securityAssessmentAnswer
        case .aiGeneratedContent: report.aiContentAnswer?.offersAI
        default: nil
        }
        return answer.map { $0 ? .yes : .no }
    }

    /// Stopping sales is offered only while it's sold in China mainland.
    var chinaChoices: [ChinaDeclarationChoice] {
        ChinaDeclarationChoice.choices(isSoldThere: complianceReport?.chinaDeclarations.isSoldThere ?? false)
    }

    func chooseChina(_ choice: ChinaDeclarationChoice, for rule: ComplianceRule) {
        guard chinaChoice(for: rule) != choice else { return }
        switch choice {
        case .stopSelling:
            stopSellingInChina(source: .you)
            return
        case .yes, .no:
            // Answering keeps the app on sale in China mainland.
            keepSellingInChina()
        }
        let offers = choice == .yes
        switch rule {
        case .securityAssessment:
            notes.compliance.needsSecurityAssessment = offers
        case .aiGeneratedContent:
            var answer = notes.compliance.aiContent ?? AIContentAnswer(offersAI: offers)
            answer.offersAI = offers
            notes.compliance.aiContent = answer
        default:
            break
        }
    }

    /// The AI filing as typed; it starts empty.
    var aiFiling: AIFilingDetails {
        notes.compliance.aiContent?.filing ?? AIFilingDetails()
    }

    func setAIFiling(_ filing: AIFilingDetails) {
        var answer = notes.compliance.aiContent ?? AIContentAnswer(offersAI: true)
        guard answer.filing != filing else { return }
        answer.filing = filing
        notes.compliance.aiContent = answer
    }

    /// Takes China mainland off the app's availability, through Review &
    /// Push: Apple's API takes that, unlike the declarations.
    func stopSellingInChina(source: ChangeSource) {
        guard let china = compliance.value?.territory(ComplianceRegion.chinaMainland) else { return }
        notes.compliance.addsICPNumber = false
        queue.discard(id: builder.legacyStopSellingChangeID(ComplianceRegion.chinaMainland))
        apply(builder.stopSellingChange(china, source: source), id: builder.stopSellingChangeID(ComplianceRegion.chinaMainland))
    }

    /// Discards a queued "stop selling in China mainland", App
    /// Compliance's or Pricing's (`propose_availability`), and nothing that
    /// puts it on sale.
    func keepSellingInChina() {
        queue.discard(ids: builder.stopSellingChangeIDs(ComplianceRegion.chinaMainland, in: queue.changes(for: app.id)))
    }
}
