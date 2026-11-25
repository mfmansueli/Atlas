//
//  PriceCalculator+Limits.swift
//  Atlas
//

import Foundation

extension PriceCalculator {
    /// The target after discount only, the floor, the ceiling, minimum
    /// proceeds and never raise, with one step each.
    struct LimitedTarget {
        var value: Decimal
        var adjustment: PriceAdjustment
        var steps: [String]
        var floor: Decimal
        var minimum: Decimal?
        var raisedToFloor = false
    }

    /// The price point a limited target lands on, and the last step.
    struct SnappedPrice {
        var point: PricePoint
        var step: String
    }

    private static let epsilon = Decimal(1) / 1000

    func applyLimits(to target: Decimal, input: PriceCalculationInput, strategy: PricingStrategy) -> LimitedTarget {
        let money = CurrencyFormat.forCurrency(input.territory.currencyCode)
        let toLocal = input.basePrice * input.equalizationMultiplier
        var value = target
        var adjustment: PriceAdjustment?
        var steps: [String] = []
        if strategy.discountOnly, value > input.equalizedPrice + Self.epsilon {
            value = input.equalizedPrice
            steps.append(String(localized: "Discount only → capped at the equalized price", comment: "kind:description"))
            adjustment = .cappedAtEqualized
        }
        let floor = strategy.floor * toLocal
        let floorText = String(localized: "\(strategy.floor.percentText)% of base = \(money.format(floor))", comment: "kind:other")
        let raisedToFloor = value < floor
        if raisedToFloor {
            value = floor
            steps.append(String(localized: "Below the floor (\(floorText)) → raised to the floor", comment: "kind:section-title"))
            adjustment = .raisedToFloor
        } else {
            steps.append(String(localized: "Above the floor (\(floorText))", comment: "kind:section-title"))
            adjustment = adjustment ?? .aboveFloor
        }
        let ceiling = strategy.ceiling * toLocal
        if !strategy.discountOnly, value > ceiling {
            value = ceiling
            let ceilingText = strategy.ceiling.percentText
            steps.append(String(localized: "Above the ceiling (\(ceilingText)% of base) → lowered to \(money.format(ceiling))", comment: "kind:section-title"))
            adjustment = .loweredToCeiling
        }
        var minimum: Decimal?
        if let proceeds = strategy.minimumProceeds, proceeds > 0 {
            let local = minimumPrice(forProceeds: proceeds * input.equalizationMultiplier, input: input)
            minimum = local
            if value < local {
                value = local
                steps.append(String(localized: "Raised so proceeds stay at least \(baseFormat(strategy).format(proceeds))", comment: "kind:description"))
                adjustment = .minimumProceeds
            }
        }
        if strategy.neverRaise, let current = input.currentPrice, value > current + Self.epsilon {
            value = current
            steps.append(String(localized: "Never raise → kept at the current price", comment: "kind:description"))
            adjustment = .neverRaise
        }
        return LimitedTarget(
            value: value, adjustment: adjustment ?? .aboveFloor, steps: steps, floor: floor, minimum: minimum, raisedToFloor: raisedToFloor
        )
    }

    /// The lowest local price that earns `proceeds` (local currency): on
    /// Apple's own ladder, the cheapest point whose proceeds reach it;
    /// otherwise worked out from the tax rate and commission.
    func minimumPrice(forProceeds proceeds: Decimal, input: PriceCalculationInput) -> Decimal {
        if input.hasRealLadder, let point = input.ladder.lowest(withProceedsAtLeast: proceeds) {
            return point.customerPrice
        }
        return commission.customerPrice(forProceeds: proceeds, taxRate: input.territory.taxRate)
    }

    /// Nearest point with the preferred ending. A price raised to the floor
    /// (or to the minimum proceeds) goes up to the nearest point at or above
    /// it instead of rounding back under.
    func snap(_ limited: LimitedTarget, input: PriceCalculationInput, strategy: PricingStrategy) -> SnappedPrice {
        let money = CurrencyFormat.forCurrency(input.territory.currencyCode)
        let ladder = input.ladder
        let rounding = strategy.rounding
        let nearest = ladder.nearest(to: limited.value, rounding: rounding) ?? offLadderPoint(limited.value, territory: input.territory)
        let bound: (value: Decimal, name: String)? = switch limited.adjustment {
        case .raisedToFloor: (limited.floor, String(localized: "the floor", comment: "kind:other"))
        case .minimumProceeds: limited.minimum.map { ($0, String(localized: "the minimum proceeds", comment: "kind:other")) }
        default: nil
        }
        if let bound, nearest.customerPrice < bound.value - Self.epsilon,
           let raised = ladder.lowest(atOrAbove: bound.value, rounding: rounding)
        {
            let price = money.format(raised.customerPrice)
            return SnappedPrice(
                point: raised, step: String(localized: "Nearest price point at or above \(bound.name) → \(price)", comment: "kind:description")
            )
        }
        let price = money.format(nearest.customerPrice)
        return SnappedPrice(point: nearest, step: String(localized: "Nearest price point → \(price)", comment: "kind:section-title"))
    }
}
