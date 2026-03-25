// Services/AuthService.swift
//
// Protocol and Firebase implementation for authentication.

import Foundation
import FirebaseAuth

// MARK: - Protocol

protocol AuthService {
    var currentUser: User? { get }
    var isSignedIn: Bool { get }

    func signUp(email: String, password: String, displayName: String) async throws -> User
    func signIn(email: String, password: String) async throws -> User
    func signOut() throws
    func sendPasswordReset(email: String) async throws
    func deleteAccount() async throws
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case notSignedIn
    case userNotFound
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case wrongPassword
    case networkError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:          return "You are not signed in"
        case .userNotFound:         return "No account found with this email"
        case .invalidEmail:         return "Invalid email address"
        case .weakPassword:         return "Password must be at least 6 characters"
        case .emailAlreadyInUse:    return "An account with this email already exists"
        case .wrongPassword:        return "Incorrect password"
        case .networkError:         return "Network error. Please check your connection."
        case .unknown(let message): return message
        }
    }
}

// MARK: - Firebase Implementation

final class FirebaseAuthService: AuthService {

    static let shared = FirebaseAuthService()

    private let auth = Auth.auth()
    private let storage: BaseModelStorageService = FirebaseBaseModelStorageService.shared

    private var cachedUser: User?

    var currentUser: User? { cachedUser }

    var isSignedIn: Bool { auth.currentUser != nil }

    // MARK: - Sign Up

    func signUp(email: String, password: String, displayName: String) async throws -> User {
        do {
            print("[AuthService] Starting sign up for email: \(email)")
            let result = try await auth.createUser(withEmail: email, password: password)
            print("[AuthService] Firebase Auth user created with UID: \(result.user.uid)")

            // Use Firebase Auth UID directly as the User's id
            let user = User(id: result.user.uid, email: email, displayName: displayName)
            try await storage.save(user)
            cachedUser = user
            print("[AuthService] Sign up complete")
            return user
        } catch let error as NSError {
            print("[AuthService] Sign up error: \(error.localizedDescription)")
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async throws -> User {
        do {
            print("[AuthService] signIn: attempting auth for \(email)")
            let result = try await auth.signIn(withEmail: email, password: password)
            print("[AuthService] signIn: auth succeeded, uid=\(result.user.uid)")

            print("[AuthService] signIn: fetching user document from Firestore, collection=users, id=\(result.user.uid)")
            let fetchedUser = try await storage.fetch(id: result.user.uid, type: User.self)
            print("[AuthService] signIn: fetch returned \(fetchedUser == nil ? "nil" : "user")")

            guard let user = fetchedUser else {
                print("[AuthService] signIn: no user document found, throwing userNotFound")
                throw AuthError.userNotFound
            }
            cachedUser = user
            print("[AuthService] signIn: complete, user.id=\(user.id)")
            return user
        } catch let error as NSError {
            print("[AuthService] signIn: caught error domain=\(error.domain) code=\(error.code) message=\(error.localizedDescription)")
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Sign Out

    func signOut() throws {
        do {
            try auth.signOut()
            cachedUser = nil
        } catch {
            throw AuthError.unknown(error.localizedDescription)
        }
    }

    // MARK: - Password Reset

    func sendPasswordReset(email: String) async throws {
        do {
            try await auth.sendPasswordReset(withEmail: email)
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        guard let firebaseUser = auth.currentUser,
              let user = cachedUser else {
            throw AuthError.notSignedIn
        }
        do {
            try await storage.delete(id: user.id, type: User.self)
            try await firebaseUser.delete()
            cachedUser = nil
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Restore Session

    func restoreSession() async throws {
        guard let firebaseUser = auth.currentUser else { return }
        cachedUser = try await storage.fetch(id: firebaseUser.uid, type: User.self)
    }

    // MARK: - Private Helpers

    private func mapFirebaseError(_ error: NSError) -> AuthError {
        guard error.domain == AuthErrorDomain else {
            return .unknown(error.localizedDescription)
        }
        switch error.code {
        case AuthErrorCode.invalidEmail.rawValue:       return .invalidEmail
        case AuthErrorCode.weakPassword.rawValue:       return .weakPassword
        case AuthErrorCode.emailAlreadyInUse.rawValue:  return .emailAlreadyInUse
        case AuthErrorCode.userNotFound.rawValue:       return .userNotFound
        case AuthErrorCode.wrongPassword.rawValue:      return .wrongPassword
        case AuthErrorCode.networkError.rawValue:       return .networkError
        default:                                        return .unknown(error.localizedDescription)
        }
    }
}

// MARK: - Mock for Testing

final class MockAuthService: AuthService {

    var currentUser: User?
    var isSignedIn: Bool { currentUser != nil }

    var shouldFailSignUp = false
    var shouldFailSignIn = false

    func signUp(email: String, password: String, displayName: String) async throws -> User {
        if shouldFailSignUp { throw AuthError.emailAlreadyInUse }
        let user = User(id: UUID().uuidString, email: email, displayName: displayName)
        currentUser = user
        return user
    }

    func signIn(email: String, password: String) async throws -> User {
        if shouldFailSignIn { throw AuthError.wrongPassword }
        let user = User(id: UUID().uuidString, email: email, displayName: "Test User")
        currentUser = user
        return user
    }

    func signOut() throws { currentUser = nil }

    func sendPasswordReset(email: String) async throws {}

    func deleteAccount() async throws { currentUser = nil }
}
