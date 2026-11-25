//
//  ReviewRiskCodePatterns.swift
//  Atlas
//

import Foundation

// swiftlint:disable line_length

/// What Atlas looks for in the app's Swift code: the APIs that need a
/// permission text, and the signs of accounts, deleting them and signing in
/// with Apple or another company. Each is found by its line, so evidence
/// says file and line. APIs that need no permission (PhotosPicker,
/// PHPickerViewController, CNContactPickerViewController) aren't here.
enum ReviewRiskCodePatterns {
    static let all: [ReviewRiskCodePattern] = permissions + accounts + signIns

    // MARK: - Permissions

    static let permissions: [ReviewRiskCodePattern] = [
        // Camera: a capture device or session for video, the document
        // camera, the data scanner, an image picker on the camera.
        use(.camera, "AVCaptureDevice", "AVCaptureDevice", #"AVCaptureDevice\s*\.\s*(requestAccess|authorizationStatus)\s*\(\s*for:\s*\.video"#),
        use(.camera, "AVCaptureDevice", "AVCaptureDevice", #"AVCaptureDevice\s*\.\s*(default|DiscoverySession)\b.*(\.video\b|Camera\b)"#),
        use(.camera, "AVCapturePhotoOutput", "AVCapturePhotoOutput", #"\bAVCapturePhotoOutput\s*\("#),
        use(.camera, "AVCaptureVideoDataOutput", "AVCaptureVideoDataOutput", #"\bAVCaptureVideoDataOutput\s*\("#),
        use(.camera, "VNDocumentCameraViewController", "VNDocumentCameraViewController", #"\bVNDocumentCameraViewController\s*\("#),
        use(.camera, "DataScannerViewController", "DataScannerViewController", #"\bDataScannerViewController\s*\("#),
        use(.camera, "UIImagePickerController camera", ".camera", #"sourceType\s*[:=]\s*\.camera\b"#),
        // Microphone.
        use(.microphone, "AVCaptureDevice audio", "AVCaptureDevice", #"AVCaptureDevice\s*\.\s*(requestAccess|authorizationStatus|default)\s*\(\s*for:\s*\.audio"#),
        use(.microphone, "requestRecordPermission", "RecordPermission", #"\brequestRecordPermission\b"#),
        use(.microphone, "AVAudioRecorder", "AVAudioRecorder", #"\bAVAudioRecorder\s*\("#),
        use(.microphone, "AVAudioEngine input", "inputNode", #"\.inputNode\b"#),
        use(.microphone, "AVAudioSession record", "Record", #"setCategory\s*\(\s*\.(record|playAndRecord)\b"#),
        // Location.
        use(.location, "CLLocationManager", "Authorization", #"\brequestWhenInUseAuthorization\s*\("#),
        use(.location, "CLLocationManager", "Location", #"\.(startUpdatingLocation|requestLocation|startMonitoringSignificantLocationChanges)\s*\("#),
        use(.location, "CLLocationUpdate", "CLLocationUpdate", #"\bCLLocationUpdate\s*\.\s*liveUpdates\b"#),
        use(.location, "CLMonitor", "CLMonitor", #"\bCLMonitor\s*\("#),
        use(.locationAlways, "CLLocationManager always", "requestAlwaysAuthorization", #"\brequestAlwaysAuthorization\s*\("#),
        // Photos: reading the library, and saving to it.
        use(.photos, "PHPhotoLibrary", "PHPhotoLibrary", #"PHPhotoLibrary\s*\.\s*(requestAuthorization|authorizationStatus)\s*(\{|\((?!\s*for:\s*\.addOnly))"#),
        use(.photos, "PHAsset", "PHAsset", #"\bPHAsset\s*\.\s*fetchAssets\b"#),
        use(.photosAdd, "PHPhotoLibrary add only", "addOnly", #"PHPhotoLibrary\s*\.\s*(requestAuthorization|authorizationStatus)\s*\(\s*for:\s*\.addOnly"#),
        use(.photosAdd, "UIImageWriteToSavedPhotosAlbum", "SavedPhotosAlbum", #"\b(UIImageWriteToSavedPhotosAlbum|UISaveVideoAtPathToSavedPhotosAlbum)\s*\("#),
        use(.photosAdd, "PHAssetChangeRequest", "PHAsset", #"\bPHAsset(Creation|Change)Request\b"#),
        // Contacts, calendars, reminders.
        use(.contacts, "CNContactStore", "CNContactStore", #"\bCNContactStore\s*\(\s*\)"#),
        use(.calendars, "EKEventStore", "Events", #"\brequestFullAccessToEvents\b"#),
        use(.calendars, "EKEventStore", "requestAccess", #"\brequestAccess\s*\(\s*to:\s*\.event\b"#),
        use(.calendarsWriteOnly, "EKEventStore write only", "requestWriteOnlyAccessToEvents", #"\brequestWriteOnlyAccessToEvents\b"#),
        use(.reminders, "EKEventStore reminders", "Reminders", #"\brequestFullAccessToReminders\b"#),
        use(.reminders, "EKEventStore reminders", "requestAccess", #"\brequestAccess\s*\(\s*to:\s*\.reminder\b"#),
        // Health: what it shares (writes) and what it reads.
        use(.healthWrite, "HKHealthStore", "toShare", #"requestAuthorization\s*\(\s*toShare:\s*+(?!nil\b|\[\]|Set\(\)|\.init\(\)|\[\s*\])"#),
        use(.healthRead, "HKHealthStore", "read:", #"requestAuthorization\s*\(\s*toShare:.*\bread:\s*+(?!nil\b|\[\]|Set\(\)|\.init\(\)|\[\s*\])"#),
        use(.healthRead, "HealthKit query", "HK", #"\b(HKSampleQuery|HKStatisticsQuery|HKAnchoredObjectQuery|HKStatisticsCollectionQuery|HKSampleQueryDescriptor|HKStatisticsQueryDescriptor)\s*\("#),
        // The rest.
        use(.bluetooth, "CBCentralManager", "CB", #"\b(CBCentralManager|CBPeripheralManager)\s*\("#),
        use(.tracking, "ATTrackingManager", "ATTrackingManager", #"\bATTrackingManager\s*\.\s*requestTrackingAuthorization\b"#),
        use(.speech, "SFSpeechRecognizer", "SFSpeechRecognizer", #"\bSFSpeechRecognizer\s*(\.\s*requestAuthorization\b|\()"#),
        use(.nfc, "Core NFC", "NFC", #"\b(NFCNDEFReaderSession|NFCTagReaderSession|NFCVASReaderSession)\s*\("#),
        use(.faceID, "LAContext", "evaluatePolicy", #"\.evaluatePolicy\s*\("#),
        use(.motion, "Core Motion", "CM", #"\b(CMMotionActivityManager|CMPedometer|CMAltimeter)\s*\("#),
        use(.homeKit, "HMHomeManager", "HMHomeManager", #"\bHMHomeManager\s*\("#),
        use(.mediaLibrary, "MPMediaLibrary", "MPMedia", #"\b(MPMediaLibrary\s*\.\s*requestAuthorization|MPMediaQuery\s*[.(])"#),
    ].compactMap(\.self)

    // MARK: - Accounts

    static let accounts: [ReviewRiskCodePattern] = [
        // Creating accounts.
        signal(.signUp, "Firebase createUser", "createUser", #"\.createUser\s*\(\s*withEmail:"#),
        signal(.signUp, "a sign-up call", "ign", #"\.(signUp|signup|signUpInBackground)\s*\("#),
        signal(.signUp, "a sign-up function", "func", #"\bfunc\s+(signUp|signup|createAccount|registerAccount|registerUser|createUser|register(?=\s*\(\s*(email|username|name|with)))\b"#),
        signal(.signUp, "a sign-up screen", "struct", #"\b(struct|class)\s+\w*(SignUp|Signup|Registration|CreateAccount)\w*\b"#),
        signal(
            .signUp, "a sign-up button", "\"",
            #""[^"]{0,30}\b(create (an |a new |your )?account|sign up|criar (uma )?conta|cadastre-se|crear (una )?cuenta|regístrate|konto erstellen|créer (un |votre )?compte|crea (un )?account)\b[^"]{0,30}""#,
            caseInsensitive: true
        ),
        // Signing in to accounts that exist.
        signal(.signIn, "an email sign-in", "signIn", #"\.signIn\s*\(\s*(withEmail|email|username|phone)\s*:"#),
        signal(.signIn, "an email sign-in", "Password", #"\.signInWithPassword\s*\("#),
        signal(.signIn, "Auth0 sign-in", "webAuth", #"\bAuth0\s*\.\s*webAuth\s*\("#),
        signal(.signIn, "Amplify sign-in", "Amplify", #"\bAmplify\s*\.\s*Auth\s*\.\s*signIn(WithWebUI)?\s*\("#),
        signal(.signIn, "a sign-in function", "func", #"\bfunc\s+(logIn|login|signIn|signin)\s*\(\s*(email|username|with|_\s+email)"#),
        // Deleting them.
        signal(.accountDeletion, "Firebase user delete", "delete", #"\bcurrentUser\s*[?!]?\s*\.\s*delete\s*\("#),
        signal(.accountDeletion, "Supabase deleteUser", "deleteUser", #"\.admin\s*\.\s*deleteUser\s*\("#),
        signal(
            .accountDeletion, "an account deletion", "ccount",
            #"\b(delete|remove|close|erase)_?(My|my|Your|your|The|the)?_?(Account|account)(?![a-z])"#
        ),
        signal(.accountDeletion, "an account deletion", "Delete", #"(Delete|Remove|Erase)(My|Your|The)?(Account|User|Profile)(?![a-z])(?!Defaults|Default|Image|Photo|Picture|Avatar|Cache|Session|Setting)"#),
        signal(.accountDeletion, "an account deletion", "delete", #"\b(delete|remove|erase)(My|Your|The)?(User|Profile)(?![a-z])(?!Defaults|Default|Image|Photo|Picture|Avatar|Cache|Session|Setting)"#),
        signal(.accountDeletion, "an account deletion", "delete_", #"\bdelete_(my_)?(account|user)\b"#),
        signal(
            .accountDeletion, "a Delete Account button", "\"",
            #""[^"]{0,30}\b((delete|remove|close|erase) (my |your |the )?account|excluir (minha |sua )?conta|apagar (minha |sua )?conta|deletar (minha )?conta|eliminar (mi |tu )?cuenta|borrar (mi |tu )?cuenta|konto löschen|supprimer (mon |votre |le )?compte|elimina(re)? (il )?(mio |tuo )?account)\b[^"]{0,30}""#,
            caseInsensitive: true
        ),
        signal(.accountDeletion, "an account deletion link", "account", #"(delete-account|deleteaccount|account/delete|delete_account)"#, caseInsensitive: true),
        // Revoking a Sign in with Apple token when the account goes.
        signal(
            .appleTokenRevoke, "Sign in with Apple token revoke", "revoke",
            #"(revoke\w*(token|apple|siwa)|appleid\.apple\.com/auth/revoke)"#, caseInsensitive: true
        ),
    ].compactMap(\.self)

    // MARK: - Sign-in

    static let signIns: [ReviewRiskCodePattern] = [
        // Sign in with Apple.
        signal(.appleSignIn, "Sign in with Apple", "ASAuthorizationAppleID", #"\bASAuthorizationAppleID(Provider|Button)\b"#),
        signal(.appleSignIn, "Sign in with Apple", "SignInWithAppleButton", #"\bSignInWithAppleButton\b"#),
        signal(
            .appleSignIn, "Sign in with Apple on the web", "apple",
            #"(providerID:\s*("apple\.com"|AuthProviderID\.apple)|provider:\s*\.apple\b|connection\s*\(\s*"apple")"#
        ),
        // Another company's sign-in.
        signal(.thirdPartyLogin, "Google Sign-In", "GoogleSignIn", #"^\s*(@\w+\s+)*import\s+GoogleSignIn(Swift)?\b"#),
        signal(.thirdPartyLogin, "Google Sign-In", "GIDSignIn", #"\bGIDSignIn\b"#),
        signal(.thirdPartyLogin, "Google Sign-In", "GoogleAuthProvider", #"\bGoogleAuthProvider\s*\.\s*credential\b"#),
        signal(.thirdPartyLogin, "Facebook Login", "Facebook", #"^\s*(@\w+\s+)*import\s+(FBSDKLoginKit|FacebookLogin)\b"#),
        signal(.thirdPartyLogin, "Facebook Login", "LoginButton", #"\b(FBLoginButton|FBSDKLoginButton)\b"#),
        signal(.thirdPartyLogin, "Facebook Login", "FacebookAuthProvider", #"\bFacebookAuthProvider\s*\.\s*credential\b"#),
        signal(.thirdPartyLogin, "Login with Amazon", "Amazon", #"(^\s*(@\w+\s+)*import\s+LoginWithAmazon\b|\bAMZNAuthorizationManager\b)"#),
        signal(.thirdPartyLogin, "LINE Login", "LineSDK", #"^\s*(@\w+\s+)*import\s+LineSDK\b"#),
        signal(.thirdPartyLogin, "Kakao Login", "Kakao", #"(^\s*(@\w+\s+)*import\s+(KakaoSDKAuth|KakaoSDKUser)\b|\bloginWithKakao(Talk|Account)\b)"#),
        signal(.thirdPartyLogin, "X (Twitter) sign-in", "Twitter", #"(^\s*(@\w+\s+)*import\s+TwitterKit\b|\bTWTRTwitter\b|\bTwitterAuthProvider\b)"#),
        signal(.thirdPartyLogin, "Microsoft sign-in", "MSAL", #"^\s*(@\w+\s+)*import\s+MSAL\b"#),
        signal(
            .thirdPartyLogin, "Firebase OAuth", "providerID",
            #"providerID:\s*("(google|facebook|twitter|github|microsoft|yahoo)\.com"|AuthProviderID\.(google|facebook|twitter|gitHub|microsoft|yahoo))"#
        ),
        signal(
            .thirdPartyLogin, "Supabase OAuth", "provider",
            #"(signInWithOAuth|signInWithIdToken)\s*\(.*provider:\s*\."#
                + #"(google|facebook|github|twitter|discord|azure|gitlab|bitbucket|slack|spotify|twitch|linkedin|linkedinOIDC|kakao|notion|zoom|figma)\b"#
        ),
        signal(
            .thirdPartyLogin, "Auth0 social sign-in", "connection",
            #"connection\s*\(\s*"(google-oauth2|facebook|twitter|github|windowslive|linkedin)""#
        ),
    ].compactMap(\.self)

    // MARK: - Making them

    private static func use(_ permission: ReviewRiskPermission, _ what: String, _ needle: String, _ pattern: String) -> ReviewRiskCodePattern? {
        ReviewRiskCodePattern(.permission(permission), what: what, needle: needle, pattern: pattern)
    }

    private static func signal(
        _ signal: ReviewRiskCodeSignal, _ what: String, _ needle: String, _ pattern: String, caseInsensitive: Bool = false
    ) -> ReviewRiskCodePattern? {
        ReviewRiskCodePattern(.signal(signal), what: what, needle: needle, pattern: pattern, caseInsensitive: caseInsensitive)
    }
}

// swiftlint:enable line_length
