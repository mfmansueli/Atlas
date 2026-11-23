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
- **Show suggestions** recommends a price per country from what people there can afford and how your app sells.

Raising a price that people already pay asks them to agree. Atlas says how many before you push.

## Offers

A subscription’s **Offers** tab lists its offers in App Store Connect and the ones waiting in Review & Push. Each offer is a free period, pay as you go (a lower price each period) or pay up front (one lower price). You set the price in the United States, and every other country or region gets the equalized price unless you give it its own.

- **Add Introductory Offer…**: a free trial or a lower price for new subscribers.
- **New Offer** > **Promotional Offer…**: for people who subscribe now or did before. Your app offers it with StoreKit, by the identifier its code uses. **Change Prices…** gives it new prices, and countries or regions priced apart keep theirs until you change them; **Delete…** removes it.
- **New Offer** > **Win-Back Offer…**: Apple shows it to people who used to subscribe, chosen by how long they paid and when they left. You can also let Apple promote it on the App Store, and give it to one payment plan only. **Edit…** changes who gets it, its dates and its priority.
- **New Offer** > **Offer Code…**: people redeem it with a code. A **custom code** is one word they type, such as PODCAST30. **One-time codes** are unique codes Apple makes. Once Apple has made them, **Save Codes…** saves them as a CSV file. **Deactivate…** turns off a code for good.

A new subscription waiting in Review & Push takes offers too, from its **…** menu: each waits for the subscription, goes out after it when you push, and is discarded with it.

An in-app purchase’s **Offers** tab lists its offer codes. **New Offer Code…** makes one: who can redeem it (people who never bought, buy now or stopped buying), a free or lower price, and where. It can come with a custom code and one-time codes. **Add Custom Code…**, **Add One-Time Codes…**, **Save Codes…** and **Deactivate…** work as they do for a subscription.

Your assistant can propose all of these too, and you review them in Review & Push. Nothing reaches App Store Connect until you push.

## Review screenshots

App Review needs a picture of each subscription’s and purchase’s purchase screen. Until a product has one, it stays in Missing Metadata. A card that needs one says so:

- **Use This Capture** uses the paywall Screenshots already captured; **Use for All** uses it for every product that still needs one.
- **Make Review Screenshots…** (in the banner, or Autopilot’s menu in Pricing) asks your assistant to open the app in the Simulator, open the paywall and capture each plan with its price showing. It never buys anything. Each image arrives on its card to **Accept** or **Dismiss**.
- **Review Screenshot…** chooses a file yourself.

Nothing uploads until you push, and **Undo** takes any of them back. If your assistant can’t find the paywall, tell it where it is and click **Try Again**. If the paywall shows no prices in the Simulator, it can add a StoreKit configuration to your Xcode project first.

> Setting any price yourself is free. Recommended prices for every country are part of Atlas Pro.
