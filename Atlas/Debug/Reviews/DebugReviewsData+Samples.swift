//
//  DebugReviewsData+Samples.swift
//  Atlas
//

#if DEBUG
import Foundation

// The nine reviews the design's board 38 writes out, newest first.
extension DebugReviewsData {
    static let samples: [DebugReviewSample] = [
        DebugReviewSample(
            id: "r-de1", territory: "DE", language: "de", rating: 1, title: "Sync seit 1.3 kaputt",
            body: "Seit dem Update auf 1.3 synchronisiert iCloud nicht mehr zwischen iPhone und iPad. Zwei Einträge sind einfach weg.",
            titleEN: "Sync broken since 1.3",
            bodyEN: "Since the update to 1.3, iCloud no longer syncs between iPhone and iPad. Two entries are just gone.",
            day: 15,
            reply: """
            Danke, dass du das meldest, und entschuldige bitte. Version 1.4 repariert die iCloud-Synchronisierung und erscheint in den \
            nächsten Tagen. Deine Einträge sind nicht verloren: Schreib uns an help@lumen.app, dann holen wir sie zusammen zurück.
            """,
            replyEN: """
            Thanks for reporting this, and sorry. Version 1.4 fixes iCloud sync and comes out in the next few days. Your entries \
            aren’t lost: write to help@lumen.app and we’ll get them back together.
            """
        ),
        DebugReviewSample(
            id: "r-jp1", territory: "JP", language: "ja", rating: 2, title: "年額が高すぎる",
            body: "日記アプリとしてはとても使いやすいです。でも年額プランしかないと思っていて、少し高く感じます。月額があれば続けたいです。",
            titleEN: "The yearly price is too high",
            bodyEN: "As a journal it’s very easy to use. But I thought there was only a yearly plan, and it feels a bit expensive. "
                + "I’d keep going if there were a monthly one.",
            day: 14,
            reply: "あたたかいレビューをありがとうございます。月額プランもご用意しています。「設定」→「Lumen Pro」からお選びいただけます。",
            replyEN: "Thank you for the kind review. There is a monthly plan too: you can choose it in Settings → Lumen Pro."
        ),
        DebugReviewSample(
            id: "r-br1", territory: "BR", language: "pt", rating: 4, title: "Ótimo, mas e o widget escuro?",
            body: "Uso todo dia. Só falta o widget acompanhar o modo escuro, fica muito claro à noite.",
            titleEN: "Great, but what about a dark widget?",
            bodyEN: "I use it every day. The widget just needs to follow dark mode; it’s very bright at night.",
            day: 14,
            reply: "Que bom que o Lumen faz parte do seu dia! O widget escuro está na nossa lista, e avisamos aqui quando chegar.",
            replyEN: "So glad Lumen is part of your day! A dark widget is on our list, and we’ll tell you here when it arrives."
        ),
        DebugReviewSample(
            id: "r-us1", territory: "US", language: "en", rating: 5, title: "My nightly ritual",
            body: "Three lines every night before bed. The prompts are gentle and the year view makes me smile.",
            day: 13,
            reply: "Thank you! Three lines a night is exactly what we hoped Lumen would be for people."
        ),
        DebugReviewSample(
            id: "r-fr1", territory: "FR", language: "fr", rating: 2, title: "Les rappels ne marchent plus",
            body: "Je ne reçois plus le rappel du soir depuis la mise à jour d’iOS.",
            titleEN: "Reminders stopped working",
            bodyEN: "I no longer get the evening reminder since the iOS update.",
            day: 12,
            reply: """
            Merci pour votre message. Vérifiez Réglages → Notifications → Lumen : la mise à jour d’iOS désactive parfois les rappels. \
            Si cela continue, écrivez-nous à help@lumen.app.
            """,
            replyEN: """
            Thanks for your message. Check Settings → Notifications → Lumen: the iOS update sometimes turns reminders off. If it \
            keeps happening, write to help@lumen.app.
            """
        ),
        DebugReviewSample(
            id: "r-jp2", territory: "JP", language: "ja", rating: 1, title: "同期されない",
            body: "iPadで書いた日記がiPhoneに出てきません。",
            titleEN: "It doesn’t sync",
            bodyEN: "Entries I write on iPad don’t show up on my iPhone.",
            day: 12,
            reply: "ご不便をおかけして申し訳ありません。iCloudの同期はバージョン1.4で修正され、数日中に公開されます。日記は失われていませんので、help@lumen.app までご連絡ください。",
            replyEN: "We’re sorry for the trouble. iCloud sync is fixed in version 1.4, out in the next few days. Your entries "
                + "aren’t lost: please write to help@lumen.app."
        ),
        DebugReviewSample(
            id: "r-us2", territory: "US", language: "en", rating: 3, title: "Prompts repeat",
            body: "After two months the same prompts come back every week. Still love the app.",
            day: 11,
            reply: "Thanks for sticking with Lumen! 1.4 adds 120 new prompts, and the same one won’t come back for at least 60 days."
        ),
        DebugReviewSample(
            id: "r-kr1", territory: "KR", language: "ko", rating: 5, title: "최고의 일기 앱",
            body: "광고도 없고 디자인이 정말 예뻐요.",
            titleEN: "Best journaling app",
            bodyEN: "No ads, and the design is really beautiful.",
            day: 10,
            reply: "따뜻한 리뷰 감사합니다! 앞으로도 광고 없이 예쁘게 만들게요.",
            replyEN: "Thank you for the kind review! We’ll keep it ad-free and beautiful."
        ),
        DebugReviewSample(
            id: "r-gb1", territory: "GB", language: "en", rating: 4, title: "Lovely, one wish",
            body: "Would love to export my year to PDF.",
            day: 9,
            reply: "Thanks! PDF export is coming in 1.5.",
            isReplied: true
        ),
    ]

    /// Reply to All's messages about iCloud sync, one per language.
    static let syncReplies: [ReviewThemeReply] = [
        ReviewThemeReply(
            languageCode: "de",
            text: "Danke, dass du das meldest. Version 1.4 repariert die iCloud-Synchronisierung und erscheint in den nächsten "
                + "Tagen. Deine Einträge sind nicht verloren."
        ),
        ReviewThemeReply(languageCode: "ja", text: "ご不便をおかけしました。iCloudの同期はバージョン1.4で修正され、数日中に公開されます。日記は失われていません。"),
        ReviewThemeReply(
            languageCode: "en",
            text: "Thanks for telling us. Version 1.4 fixes iCloud sync and comes out in the next few days. Your entries aren’t lost."
        ),
        ReviewThemeReply(
            languageCode: "fr",
            text: "Merci de nous l’avoir signalé. La version 1.4 corrige la synchronisation iCloud et sort dans quelques jours. "
                + "Vos entrées ne sont pas perdues."
        ),
        ReviewThemeReply(
            languageCode: "nl",
            text: "Bedankt voor je melding. Versie 1.4 herstelt de iCloud-synchronisatie en verschijnt over een paar dagen. Je notities zijn niet verloren."
        ),
        ReviewThemeReply(
            languageCode: "it",
            text: "Grazie della segnalazione. La versione 1.4 risolve la sincronizzazione iCloud ed esce tra pochi giorni. Le tue note non sono perse."
        ),
        ReviewThemeReply(
            languageCode: "sv",
            text: "Tack för att du hör av dig. Version 1.4 lagar iCloud-synkningen och kommer om några dagar. Dina anteckningar är inte borta."
        ),
    ]

    /// Reply to All's messages about the evening reminder.
    static let reminderReplies: [ReviewThemeReply] = [
        ReviewThemeReply(languageCode: "fr", text: "Merci. Vérifiez Réglages → Notifications → Lumen : iOS 26.1 désactive parfois les rappels."),
        ReviewThemeReply(languageCode: "en", text: "Thanks. Check Settings → Notifications → Lumen: iOS 26.1 sometimes turns reminders off."),
        ReviewThemeReply(languageCode: "it", text: "Grazie. Controlla Impostazioni → Notifiche → Lumen: iOS 26.1 a volte disattiva i promemoria."),
    ]

    /// Subject and language → title, text, and both in English, for the
    /// reviews made up around the written-out ones.
    static let texts: [String: [String: [String]]] = [
        "sync": [
            "de": [
                "Sync geht nicht mehr", "Seit 1.3 kommen meine Einträge nicht mehr auf dem iPad an.",
                "Sync stopped working", "Since 1.3 my entries no longer arrive on the iPad.",
            ],
            "ja": ["同期できません", "アップデート後、iCloudで同期されなくなりました。", "Can’t sync", "After the update, it stopped syncing with iCloud."],
            "en": ["Sync is broken", "Entries stopped syncing between my devices after 1.3."],
            "fr": [
                "La synchronisation ne marche plus", "Depuis la 1.3, mes notes ne se synchronisent plus.",
                "Sync no longer works", "Since 1.3 my notes no longer sync.",
            ],
            "nl": [
                "Synchronisatie werkt niet", "Sinds 1.3 worden mijn notities niet meer gesynchroniseerd.",
                "Sync doesn’t work", "Since 1.3 my notes are no longer synced.",
            ],
            "it": [
                "La sincronizzazione non funziona", "Dalla 1.3 le mie note non si sincronizzano più.",
                "Sync doesn’t work", "Since 1.3 my notes no longer sync.",
            ],
            "sv": ["Synken fungerar inte", "Sedan 1.3 synkas inte mina anteckningar längre.", "Sync doesn’t work", "Since 1.3 my notes no longer sync."],
        ],
        "price": [
            "ja": ["年額しかない？", "月額プランがあれば続けたいです。年額は高いです。", "Only yearly?", "I’d keep going with a monthly plan. Yearly is expensive."],
            "pt": [
                "Caro demais", "Gosto do app, mas o plano anual pesa no bolso.",
                "Too expensive", "I like the app, but the yearly plan is heavy on the wallet.",
            ],
            "ko": ["가격이 부담돼요", "연간 요금제만 있는 줄 알았어요. 조금 비싸요.", "The price is a burden", "I thought there was only a yearly plan. It’s a bit expensive."],
            "es": ["Un poco caro", "Me gustaría un plan mensual más barato.", "A bit expensive", "I’d like a cheaper monthly plan."],
            "it": ["Prezzo alto", "Bella app, ma l’abbonamento annuale costa troppo.", "High price", "Nice app, but the yearly subscription costs too much."],
        ],
        "remind": [
            "fr": [
                "Plus de rappel", "Le rappel du soir n’arrive plus depuis iOS 26.1.",
                "No more reminder", "The evening reminder no longer arrives since iOS 26.1.",
            ],
            "en": ["Reminder stopped", "The evening reminder doesn’t show up anymore."],
            "it": ["Promemoria sparito", "Il promemoria serale non arriva più.", "Reminder gone", "The evening reminder no longer arrives."],
        ],
        "widget": [
            "pt": ["Widget escuro, por favor", "O widget fica claro demais à noite.", "Dark widget, please", "The widget is too bright at night."],
            "en": ["Dark widget please", "Love it. A dark widget would make it perfect."],
            "de": [
                "Dunkles Widget fehlt", "Tolle App, aber das Widget blendet nachts.",
                "Dark widget missing", "Great app, but the widget is glaring at night.",
            ],
        ],
        "love": [
            "en": ["Calm and private", "No ads, beautiful design, gentle prompts."],
            "de": ["Wunderschön", "Keine Werbung und ein ruhiges Design.", "Beautiful", "No ads and a calm design."],
            "ja": ["毎晩使っています", "広告がなくて、デザインがきれいです。", "I use it every night", "No ads, and the design is beautiful."],
            "fr": ["Très apaisant", "Pas de pub, de jolies questions chaque soir.", "Very calming", "No ads, lovely questions every evening."],
            "ko": ["예쁘고 조용해요", "광고가 없어서 좋아요.", "Pretty and quiet", "I like that there are no ads."],
            "pt": ["Adoro", "Sem anúncios e muito bonito.", "Love it", "No ads and very pretty."],
        ],
        "export": [
            "en": ["Wish it exported", "A PDF of my year would be lovely."],
            "de": ["Export fehlt", "Ich würde mein Jahr gern als PDF sichern.", "Export missing", "I’d like to save my year as a PDF."],
        ],
    ]
}
#endif
