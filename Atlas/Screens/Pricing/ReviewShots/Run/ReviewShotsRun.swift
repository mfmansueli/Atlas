//
//  ReviewShotsRun.swift
//  Atlas
//

import Foundation

/// One Make Review Screenshots… run for an app: the assistant opens the
/// app in Simulator, opens the paywall and captures each product missing a
/// review screenshot with its plan selected, in the paywall's order. It
/// reports each step (`report_review_screenshot_run`) and each image
/// arrives as a suggestion (`propose_purchase_review_screenshot`).
struct ReviewShotsRun: Hashable, Sendable, Identifiable {
    enum Phase: Hashable, Sendable {
        case working
        /// It found no way to the paywall; `tried` is what it tried.
        case paywallNotFound(tried: String)
        /// The paywall opened without prices; `saw` is what it saw.
        case noPrices(saw: String)
        /// It ended with images waiting for Accept.
        case ready
    }

    /// A product the run captures.
    struct Product: Hashable, Sendable, Identifiable {
        var productID: String
        /// “Monthly”: the plan to select on the paywall.
        var plan: String
        var id: String { productID }
    }

    var id = UUID()
    var client: String
    var products: [Product]
    var phase: Phase = .working
    /// The product being captured.
    var current: String?
    /// What it already did: “Opened Lumen in Simulator · iPhone 17 Pro”.
    var steps: [String] = []
    /// What it does now: “Selecting Annual and waiting for its price”.
    var step: String?
    /// Products whose image arrived.
    var arrived: Set<String> = []
    var startedAt: Date = .now

    /// The product being captured, else the first still to come.
    var currentProduct: Product? {
        products.first { $0.productID == current } ?? products.first { !arrived.contains($0.productID) }
    }

    /// 1 for the first product.
    var currentNumber: Int {
        guard let product = currentProduct, let index = products.firstIndex(of: product) else { return products.count }
        return index + 1
    }

    /// “Capturing Annual · 2 of 3”, for the toolbar while it works.
    var toolbarText: String {
        guard current != nil, let product = currentProduct else { return String(localized: "Making review screenshots") }
        return String(localized: "Capturing \(product.plan) · \(currentNumber) of \(products.count)")
    }

    /// “Making review screenshots · capturing Annual, 2 of 3”, for the menu.
    var menuText: String {
        guard current != nil, let product = currentProduct else { return String(localized: "Making review screenshots") }
        return String(localized: "Making review screenshots · capturing \(product.plan), \(currentNumber) of \(products.count)")
    }

    /// The toolbar's bar: halfway through the product being captured.
    var fraction: Double {
        guard !products.isEmpty else { return 0 }
        let done = Double(arrived.count)
        return min(1, (done + (current == nil ? 0 : 0.5)) / Double(products.count))
    }

    /// What the purple toolbar button says when the run needs the person.
    var needs: String? {
        switch phase {
        case .working: nil
        case .paywallNotFound: String(localized: "Show It the Paywall")
        case .noPrices: String(localized: "Choose How to Continue")
        case .ready: String(localized: "Review Screenshots Ready")
        }
    }

    var isWorking: Bool { phase == .working }

    /// The product being captured, or the first to come before the
    /// assistant names one.
    func isCapturing(_ productID: String) -> Bool {
        isWorking && currentProduct?.productID == productID
    }

    /// The product waits for its turn in the run.
    func isQueued(_ productID: String) -> Bool {
        isWorking && products.contains { $0.productID == productID } && !arrived.contains(productID) && !isCapturing(productID)
    }

    /// “Claude Code captures Lifetime after Annual.”
    func queuedText(for productID: String) -> String {
        guard let product = products.first(where: { $0.productID == productID }),
              let index = products.firstIndex(of: product) else { return "" }
        let before = index > 0 ? products[index - 1].plan : String(localized: "the one before")
        return String(localized: "\(client) captures \(product.plan) after \(before).")
    }
}
