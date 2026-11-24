---
id: pricing
group: listing
title: Pricing by country
summary: What your subscriptions and purchases cost in 175 countries and regions.
keywords: pricing, price, prices, subscription, subscriptions, in-app purchase, country, countries, purchasing power, keep my prices, show suggestions, raise, increase, consent, review screenshot, app review, paywall, missing metadata, make review screenshots, storekit, offer, offers, introductory offer, free trial, promotional offer, win-back offer, offer code, custom code, one-time codes, discount
showMe: section:subscriptionPricing
related: analytics, pro
---
- **Keep my prices** shows what you charge and changes nothing.
- **Show suggestions** suggests a price per country from local buying power and your sales.

Raising a price that people already pay asks them to agree. Atlas says how many before you push.

## Offers

A subscription’s **Offers** tab lists its offers, live and in Review & Push. Types: free period, pay as you go (lower price each period), pay up front (one lower price). You set the U.S. price; other countries get Apple’s automatic price unless you set theirs.

- **Add Introductory Offer…**: a free trial or a lower price for new subscribers.
- **New Offer** > **Promotional Offer…**: for current and past subscribers, offered in your app through StoreKit by its identifier. **Change Prices…** reprices it; separately priced countries keep theirs. **Delete…** removes it.
- **New Offer** > **Win-Back Offer…**: for past subscribers, by how long they paid and when they left. Apple can promote it on the App Store; you can limit it to one plan. **Edit…** changes who, when and priority.
- **New Offer** > **Offer Code…**: people redeem it with a code. A **custom code** is one word they type, such as PODCAST30. **One-time codes** are unique codes Apple makes. Once Apple has made them, **Save Codes…** saves them as a CSV file. **Deactivate…** turns off a code for good.

A new subscription in Review & Push takes offers too, from its **…** menu. They push after it and are discarded with it.

An in-app purchase’s **Offers** tab lists its offer codes. **New Offer Code…** sets who can redeem (never bought, buying now, stopped), the free or lower price, where, and custom or one-time codes. **Add Custom Code…**, **Add One-Time Codes…**, **Save Codes…** and **Deactivate…** work as for subscriptions.

Your assistant can suggest all of these too, in Review & Push. Nothing reaches App Store Connect until you push.

## Review screenshots

App Review needs a screenshot of each product’s purchase screen; without one, it stays in Missing Metadata. Cards that need one say so:

- **Use This Capture** uses the paywall Screenshots already captured; **Use for All** uses it for every product that still needs one.
- **Make Review Screenshots…** (banner, or Autopilot’s menu in Pricing): your assistant captures each plan’s paywall with its price in the Simulator, never buying. Each image arrives on its card to **Accept** or **Dismiss**.
- **Review Screenshot…** chooses a file yourself.

Nothing is sent until you push; **Undo** takes any back. Paywall not found? Tell your assistant where, then click **Try Again**. No prices showing? It can add a StoreKit configuration to your Xcode project.

> Setting prices yourself is free. Suggested prices for every country are part of Atlas Pro.
