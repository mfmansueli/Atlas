//
//  ProductPageTextSuggestion+Evidence.swift
//  Atlas
//

import Foundation

extension ProductPageTextSuggestion {
    /// "Reviews · German reviews": the evidence pill, in the same words as a
    /// suggested page's; nil when the assistant gave none.
    var evidenceTitle: String? {
        guard let evidence, !evidence.isEmpty else { return nil }
        let title = ProductPageSuggestion(id: pageID, name: "", audience: "", reason: reason, evidence: evidence, source: source).evidenceTitle
        return title.isEmpty ? nil : title
    }
}
