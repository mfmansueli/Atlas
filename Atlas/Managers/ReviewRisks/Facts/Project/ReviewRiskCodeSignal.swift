//
//  ReviewRiskCodeSignal.swift
//  Atlas
//

import Foundation

/// What a line of the app's code says about accounts and sign-in.
enum ReviewRiskCodeSignal: String, CaseIterable, Codable, Hashable, Sendable {
    /// Creates accounts: Firebase `createUser`, Supabase `signUp`, a
    /// sign-up screen or function.
    case signUp
    /// Signs people in to an account that exists (email and password, Auth0).
    case signIn
    /// Deletes an account: `deleteAccount`, `currentUser?.delete()`,
    /// "Delete Account".
    case accountDeletion
    /// Sign in with Apple: `ASAuthorizationAppleIDProvider`, its button.
    case appleSignIn
    /// Revokes a Sign in with Apple token when an account goes.
    case appleTokenRevoke
    /// Sign-in with another company's account: Google, Facebook, Amazon…
    case thirdPartyLogin
}
