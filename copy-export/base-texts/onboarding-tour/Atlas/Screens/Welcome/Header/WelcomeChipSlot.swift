//
//  WelcomeChipSlot.swift
//  Atlas
//

import Foundation

/// One of the eight places round the globe where chips pop in and lift
/// away, out of step with each other so something is always changing but
/// never all at once. Each drifts 14 points, 6 s each way. The four `far`
/// ones hide below 900 points of width.
struct WelcomeChipSlot: Hashable, Sendable, Identifiable {
    var id: Int
    /// 0…1 of the header's width and height.
    var x: Double
    var y: Double
    var isFar: Bool
    /// Seconds into its drift it starts at.
    var driftDelay: TimeInterval
    var chips: [WelcomeChip]

    static let driftSwing: TimeInterval = 6
    /// Below this header width the far slots hide.
    static let farMinimumWidth: Double = 900

    /// Points up or down, ±7.
    func drift(at time: TimeInterval) -> Double {
        -7 * cos(.pi * (time + driftDelay) / Self.driftSwing)
    }

    /// The eight slots of the design's header, with their chips.
    static let all: [WelcomeChipSlot] = [
        slot(0, x: 0.15, y: 0.24, far: false, drift: 0, [
            (.language(flag: "🇺🇸", name: "English"), 0), (.language(flag: "🇮🇹", name: "Italiano"), 16),
            (.price(currency: "€", amount: "4,99"), 12), (.language(flag: "🇹🇷", name: "Türkçe"), 8),
        ]),
        slot(1, x: 0.83, y: 0.20, far: false, drift: 0.7, [
            (.language(flag: "🇩🇪", name: "Deutsch"), 7.4), (.price(currency: "¥", amount: "800"), 3.4),
            (.language(flag: "🇪🇸", name: "Español"), 19.4), (.language(flag: "🇳🇱", name: "Nederlands"), 15.4),
        ]),
        slot(2, x: 0.12, y: 0.66, far: false, drift: 1.4, [
            (.language(flag: "🇯🇵", name: "日本語"), 14.8), (.language(flag: "🇸🇦", name: "العربية"), 10.8),
            (.language(flag: "🇸🇪", name: "Svenska"), 6.8), (.price(currency: "R$", amount: "24,90"), 2.8),
        ]),
        slot(3, x: 0.88, y: 0.68, far: false, drift: 2.1, [
            (.language(flag: "🇧🇷", name: "Português"), 2.2), (.language(flag: "🇨🇳", name: "简体中文"), 18.2),
            (.price(currency: "£", amount: "4.99"), 14.2), (.language(flag: "🇵🇱", name: "Polski"), 10.2),
        ]),
        slot(4, x: 0.27, y: 0.87, far: true, drift: 2.8, [
            (.price(currency: "₩", amount: "6,600"), 9.6), (.language(flag: "🇫🇷", name: "Français"), 5.6),
            (.language(flag: "🇮🇩", name: "Indonesia"), 1.6), (.language(flag: "🇬🇷", name: "Ελληνικά"), 17.6),
        ]),
        slot(5, x: 0.73, y: 0.89, far: true, drift: 3.5, [
            (.language(flag: "🇰🇷", name: "한국어"), 17), (.language(flag: "🇬🇧", name: "English"), 13),
            (.language(flag: "🇻🇳", name: "Tiếng Việt"), 9), (.price(currency: "₹", amount: "499"), 5),
        ]),
        slot(6, x: 0.31, y: 0.11, far: true, drift: 4.2, [
            (.language(flag: "🇮🇳", name: "हिन्दी"), 4.4), (.price(currency: "$", amount: "4.99"), 0.4),
            (.language(flag: "🇵🇹", name: "Português"), 16.4), (.language(flag: "🇺🇦", name: "Українська"), 12.4),
        ]),
        slot(7, x: 0.68, y: 0.09, far: true, drift: 4.9, [
            (.language(flag: "🇲🇽", name: "Español"), 11.8), (.language(flag: "🇹🇭", name: "ไทย"), 7.8),
            (.language(flag: "🇨🇦", name: "Français"), 3.8), (.price(currency: "kr", amount: "59"), 19.8),
        ]),
    ]

    private static func slot(
        _ id: Int, x: Double, y: Double, far: Bool, drift: TimeInterval, _ chips: [(WelcomeChip.Content, TimeInterval)]
    ) -> WelcomeChipSlot {
        WelcomeChipSlot(id: id, x: x, y: y, isFar: far, driftDelay: drift, chips: chips.map { WelcomeChip(content: $0.0, delay: $0.1) })
    }
}
