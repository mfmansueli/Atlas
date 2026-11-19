---
id: connect
group: start
title: Connect App Store Connect
summary: Atlas uses an App Store Connect API key to read your apps and to push what you approve.
keywords: key, api key, p8, issuer, issuer id, key id, team key, admin, app manager, account, connect, sign in, login
showMe: settings:accounts
related: privacy, fix
---
## Make the key

1. In App Store Connect, open **Users and Access**, then **Integrations**.
2. Choose **App Store Connect API**, then **Team Keys**, and add a key.
3. Give it the Admin role, or App Manager if you don’t need sales figures.
4. Download the .p8 file. Apple lets you download it once.

## Give it to Atlas

1. Copy the Issuer ID from the top of that page and the Key ID from the key’s row.
2. In Atlas, paste both and drop the .p8 file on the window.
3. Click **Connect**. Atlas reads your apps and changes nothing.

> The key is stored in this Mac’s Keychain. Every request is signed on this Mac and sent straight to Apple.
