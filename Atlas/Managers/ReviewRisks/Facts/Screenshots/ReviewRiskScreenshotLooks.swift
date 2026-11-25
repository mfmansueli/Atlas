//
//  ReviewRiskScreenshotLooks.swift
//  Atlas
//

import Foundation

/// Whether a live screenshot shows something other than the app in use
/// (2.3.3: screenshots “should not be merely title art, login page, or
/// splash screen”), from what Vision read in it: an iOS permission alert,
/// a sign-in screen, or a screen that is mostly one flat area. Lines are
/// compared whole, so a caption like “Sign in with Apple in one tap” isn't
/// a sign-in button.
enum ReviewRiskScreenshotLooks {
    /// At or above this share of flat area, with little text, a screen is
    /// mostly blank (`CaptureBlankness`: real screens stayed under 0.40).
    static let mostlyBlank = CaptureBlankness.mostlyBlank
    /// More lines than this is a screen with content, however flat.
    static let blankLineLimit = 5
    /// A sign-in screen has few lines; more is a screen that mentions it.
    static let signInLineLimit = 15

    /// Apple Watch faces and Mac desktops are often one flat colour, and
    /// say nothing about the app.
    static func judgesBlankness(on display: ScreenshotDisplayType) -> Bool {
        display == .iPhone || display == .iPhoneDuo || display == .iPad
    }

    static func isMostlyBlank(_ reading: ReviewRiskScreenshotReading, on display: ScreenshotDisplayType) -> Bool {
        guard judgesBlankness(on: display), let share = reading.blankShare else { return false }
        return share >= mostlyBlank && reading.lines.count <= blankLineLimit
    }

    /// The alert's line when the screenshot shows an iOS permission alert:
    /// the app's name in quotes with one of the alert's buttons, or a
    /// button only system alerts have.
    static func systemAlertLine(in lines: [String], appName: String) -> String? {
        let normalized = lines.map(normalize)
        if normalized.contains(where: { systemOnlyButtons.contains($0) }) {
            return lines.first { CaptureTextAnalyzer.quotesName(in: $0, appName: appName) }
                ?? lines[normalized.firstIndex { systemOnlyButtons.contains($0) } ?? 0]
        }
        guard normalized.contains(where: { alertButtons.contains($0) }) else { return nil }
        return lines.first { CaptureTextAnalyzer.quotesName(in: $0, appName: appName) }
    }

    /// The lines that make it a sign-in screen: a sign-in button with a
    /// password or email field, or two ways to sign in.
    static func signInLines(in lines: [String]) -> [String] {
        guard !lines.isEmpty, lines.count <= signInLineLimit else { return [] }
        let actions = lines.filter { signInActions.contains(normalize($0)) }
        let fields = lines.filter { signInFields.contains(normalize($0)) }
        let distinctActions = Set(actions.map(normalize))
        guard (!actions.isEmpty && !fields.isEmpty) || distinctActions.count >= 2 else { return [] }
        return actions + fields
    }

    /// Lowercased, apostrophes straightened, without the spaces and
    /// punctuation around it.
    static func normalize(_ line: String) -> String {
        line.lowercased()
            .replacingOccurrences(of: "[’‘`´ʼ]", with: "'", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters).union(.symbols))
    }

    /// Buttons of iOS permission alerts, in the App Store's main languages.
    static let alertButtons: Set<String> = [
        "allow", "don't allow", "allow once", "allow while using app", "allow full access", "allow access to all photos",
        "ask app not to track", "erlauben", "nicht erlauben", "einmal erlauben", "beim verwenden der app erlauben", "permitir",
        "no permitir", "não permitir", "permitir uma vez", "autoriser", "ne pas autoriser", "autoriser une fois", "consenti",
        "non consentire", "consenti una volta", "toestaan", "sta niet toe", "許可", "許可しない", "1度だけ許可", "允许", "不允许",
        "允許", "不允許", "허용", "허용 안 함", "한 번 허용",
    ]

    /// Buttons no app draws itself.
    static let systemOnlyButtons: Set<String> = [
        "allow while using app", "ask app not to track", "beim verwenden der app erlauben", "app bitten, kein tracking durchzuführen",
        "permitir al usar la app", "permitir durante o uso do app", "autoriser pendant l'utilisation de l'app",
        "consenti quando usi l'app", "appの使用中は許可",
    ]

    /// Buttons that sign in or make an account.
    static let signInActions: Set<String> = [
        "sign in", "log in", "login", "sign up", "create account", "create an account", "sign in with apple", "continue with apple",
        "sign in with google", "continue with google", "continue with email", "continue with facebook", "sign in with email",
        "anmelden", "registrieren", "konto erstellen", "mit apple anmelden", "iniciar sesión", "registrarse", "crear cuenta",
        "iniciar sessão", "entrar", "criar conta", "se connecter", "connexion", "créer un compte", "accedi", "registrati",
        "crea account", "inloggen", "ログイン", "新規登録", "登录", "注册", "登入", "로그인", "회원가입",
    ]

    /// Fields a sign-in screen asks for.
    static let signInFields: Set<String> = [
        "password", "forgot password", "forgot your password", "email", "email address", "username", "e-mail", "passwort",
        "passwort vergessen", "e-mail-adresse", "contraseña", "olvidaste tu contraseña", "correo electrónico", "senha",
        "esqueceu a senha", "mot de passe", "mot de passe oublié", "adresse e-mail", "wachtwoord", "パスワード", "メールアドレス",
        "密码", "密碼", "电子邮件", "비밀번호", "이메일",
    ]
}
