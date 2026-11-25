//
//  TranslationMarketNotes.swift
//  Atlas
//

import Foundation

/// What a native App Store copywriter for one locale knows that a
/// translator working from English might not: the market's own variant of
/// the language (pt-BR against pt-PT, es-MX against es-ES, zh-Hans against
/// zh-Hant), how formal store copy usually is there, its typography, and how
/// many bytes its letters take in the 100-byte keywords field.
/// `get_translation_brief` carries them as `market` and `keywordRules`.
nonisolated enum TranslationMarketNotes {
    /// The note for one locale; every App Store locale has its own.
    static func note(for locale: StoreLocale) -> String {
        notes[locale.code] ?? "Write \(locale.name) the way people who read it every day write it, not the way a translator would."
    }

    /// How many UTF-8 bytes most of the language's letters take: 1 for
    /// Latin scripts (accented letters take 2), 2 for Cyrillic, Greek,
    /// Arabic and Hebrew, 3 for Chinese, Japanese, Korean, Thai and
    /// Devanagari.
    static func bytesPerLetter(_ locale: StoreLocale) -> Int {
        switch locale.languageCode {
        case "ru", "uk", "el", "ar", "he": 2
        case "zh", "ja", "ko", "th", "hi": 3
        default: 1
        }
    }

    /// The keywords field's rules, with what its 100 bytes hold in this
    /// language.
    static func keywordRules(for locale: StoreLocale) -> String {
        let common = """
        Keywords: at most 100 bytes in UTF-8, terms separated by commas with no space after a comma, no repeats, \
        nothing already in the name or subtitle, and no other apps' names. Pick the words people in this market type \
        in App Store search, not translations of the source's keywords.
        """
        let bytes = switch bytesPerLetter(locale) {
        case 2: "\(locale.name) letters take 2 bytes each, so about 50 letters fit."
        case 3: "Each \(locale.name) character takes 3 bytes, so about 33 characters fit."
        default: "Plain letters take 1 byte and accented ones 2."
        }
        return "\(common) \(bytes)"
    }

    /// By App Store Connect locale code.
    private static let notes: [String: String] = [
        "en-US": "American English: US spelling (color, organize) and vocabulary (cell phone, vacation).",
        "en-GB": """
        British English: UK spelling (colour, organise, travelled) and vocabulary (mobile, holiday). Change what \
        a UK reader would notice in US copy.
        """,
        "en-AU": "Australian English: UK spelling (colour, organise) and Australian vocabulary (mobile, holiday); a relaxed, direct tone reads well.",
        "en-CA": "Canadian English: colour and favourite, but organize; US vocabulary (cell phone, vacation).",
        "fr-FR": """
        French for France: vous or neutral infinitives, as French apps usually write; a space before : ; ? ! and \
        « guillemets »; French words over anglicisms where French people use them.
        """,
        "fr-CA": """
        Canadian French: Québec vocabulary (courriel, cellulaire, magasiner), tu or vous as the app's own strings \
        use; a space before the colon only. Not a copy of fr-FR.
        """,
        "es-ES": "Spanish for Spain: tú (vosotros for groups) and Spain's vocabulary (móvil, ordenador). Not a copy of es-MX.",
        "es-MX": """
        Spanish for Mexico and Latin America: tú and ustedes, never vosotros; Latin American vocabulary (celular, \
        computadora). Not a copy of es-ES.
        """,
        "pt-BR": "Brazilian Portuguese: você, and Brazil's vocabulary and spelling (celular, tela, arquivo, usuário, equipe). Never European forms.",
        "pt-PT": """
        European Portuguese: tu or neutral forms (você can read cold), Portugal's vocabulary and spelling \
        (telemóvel, ecrã, ficheiro, utilizador, equipa) and “estar a fazer”, not the gerund. Never Brazilian \
        forms.
        """,
        "zh-Hans": """
        Simplified Chinese for mainland China: mainland vocabulary (软件, 视频, 信息, 质量), full-width punctuation \
        (，。：！), no spaces between characters; short, concrete phrases.
        """,
        "zh-Hant": """
        Traditional Chinese for Taiwan and Hong Kong: Taiwan vocabulary (軟體, 影片, 資訊, 品質), full-width punctuation \
        and 「」. Write it, don't convert Simplified Chinese character by character.
        """,
        "ja": """
        Japanese: です・ます in the description and What’s New, short noun phrases in the subtitle; katakana for \
        loanwords people already use; full-width punctuation (、。「」).
        """,
        "ko": "Korean: friendly 해요체, the same throughout; noun-ending phrases in the subtitle; spacing between words as Korean spelling rules ask.",
        "de-DE": """
        German: du or Sie as the app's own strings use (consumer apps usually say du); long compounds fill 30 \
        characters fast, so pick shorter words rather than cutting meaning; „Anführungszeichen“.
        """,
        "it": "Italian: tu, as Italian apps usually write; Italian words over anglicisms, except the ones Italians use (app, smartphone).",
        "nl-NL": "Dutch for the Netherlands: je and jij, direct and informal; compounds written as one word.",
        "ru": "Russian: вы in lower case or a neutral imperative; Russian phrasing, not calques from English; «ёлочки».",
        "uk": "Ukrainian: Ukrainian vocabulary and spelling, never Russian words or forms; ви or neutral forms; «лапки».",
        "pl": "Polish: a friendly ty or impersonal forms, as Polish apps usually write; Polish word order and „cudzysłów”.",
        "cs": "Czech: ty or vy as the app's own strings use; „uvozovky“.",
        "sk": "Slovak: Slovak words, not Czech ones; ty or vy as the app's own strings use.",
        "hu": "Hungarian: te forms for consumer apps; Hungarian word order and suffixes, not English order.",
        "ro": "Romanian: tu or dumneavoastră as the app's own strings use; ș and ț with a comma below, never a cedilla.",
        "hr": "Croatian: Croatian vocabulary, not Serbian or Bosnian; ti or vi as the app's own strings use.",
        "el": "Greek: εσύ or εσείς as the app's own strings use; the Greek question mark is ;.",
        "ca": "Catalan: tu, and Catalan phrasing rather than Spanish word order or calques.",
        "sv": "Swedish: du, short and plain; compounds as one word.",
        "da": "Danish: du, short and plain; compounds as one word.",
        "no": "Norwegian Bokmål: du, short and plain; compounds as one word.",
        "fi": "Finnish: friendly and plain; case endings change words, so keywords are the forms people search for, usually the basic form.",
        "tr": "Turkish: sen or a neutral imperative, as Turkish apps usually write; suffixes join a brand name with an apostrophe (Lumen'i).",
        "ar-SA": """
        Arabic for Saudi Arabia and the Gulf: Modern Standard Arabic, plain and warm; right to left, with Latin \
        brand names kept as they are.
        """,
        "he": """
        Hebrew: plain modern Hebrew; avoid forms that assume the reader's gender where you can (plural or \
        infinitive); right to left, brand names in Latin letters.
        """,
        "hi": "Hindi in Devanagari, with the English words Indians use in apps (app, notification) where they read more natural than pure Hindi.",
        "th": "Thai: polite and friendly, without ending particles (ครับ, ค่ะ) in store copy; no spaces between words, a space between phrases.",
        "vi": "Vietnamese: bạn; every diacritic matters, since it changes the word.",
        "id": "Indonesian: kamu for friendly apps, Anda for formal ones, as the app's own strings use; Indonesian words where people use them.",
        "ms": "Malay for Malaysia: Malaysian vocabulary and spelling, not Indonesian; anda or awak as the app's own strings use.",
    ]
}
