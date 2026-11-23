---
id: pricing
group: listing
title: Pricing by country
summary: What your subscriptions and purchases cost in 175 countries and regions.
keywords: pricing, price, prices, subscription, subscriptions, in-app purchase, country, countries, purchasing power, keep my prices, show suggestions, raise, increase, consent, review screenshot, app review, paywall, missing metadata, make review screenshots, storekit
showMe: section:subscriptionPricing
related: analytics, pro
---
- **Keep my prices** shows what you charge and changes nothing.
- **Show suggestions** recommends a price per country from what people there can afford and how your app sells.

Raising a price that people already pay asks them to agree. Atlas says how many before you push.

## Review screenshots

App Review needs a picture of each subscription’s and purchase’s purchase screen. Until a product has one, it stays in Missing Metadata. A card that needs one says so:

- **Use This Capture** uses the paywall Screenshots already captured; **Use for All** uses it for every product that still needs one.
- **Make Review Screenshots…** (in the banner, or Autopilot’s menu in Pricing) asks your assistant to open the app in the Simulator, open the paywall and capture each plan with its price showing. It never buys anything. Each image arrives on its card to **Accept** or **Dismiss**.
- **Review Screenshot…** chooses a file yourself.

Nothing uploads until you push, and **Undo** takes any of them back. If your assistant can’t find the paywall, tell it where it is and click **Try Again**. If the paywall shows no prices in the Simulator, it can add a StoreKit configuration to your Xcode project first.

> Setting any price yourself is free. Recommended prices for every country are part of Atlas Pro.
