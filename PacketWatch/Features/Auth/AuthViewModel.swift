// Features/Auth/AuthViewModel.swift
//
// ViewModel for authentication flows.

import Foundation
import FirebaseFirestore

@MainActor
final class AuthViewModel: ObservableObject {
    
    // MARK: - Form Fields
    
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var displayName = ""
    
    // MARK: - State
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var currentUser: User?
    
    // MARK: - Dependencies

    private let authService: AuthService
    private let userService: UserService
    private var userListener: ListenerRegistration?
    
    // MARK: - Computed
    
    var isSignedIn: Bool {
        currentUser != nil
    }
    
    var canSignUp: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        !displayName.isEmpty &&
        password == confirmPassword
    }
    
    var canSignIn: Bool {
        !email.isEmpty && !password.isEmpty
    }
    
    // MARK: - Init
    
    init(
        authService: AuthService = ServiceContainer.shared.authService,
        userService: UserService = FirebaseUserService.shared
    ) {
        self.authService = authService
        self.userService = userService
        self.currentUser = authService.currentUser
    }
    
    // MARK: - Actions
    
    func signUp() async {
        print("[AuthViewModel] Sign up button tapped")

        guard password == confirmPassword else {
            errorMessage = "Passwords don't match"
            print("[AuthViewModel] Password mismatch")
            return
        }

        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            print("[AuthViewModel] Password too short")
            return
        }

        isLoading = true
        errorMessage = nil

        print("[AuthViewModel] Calling authService.signUp")
        do {
            let user = try await authService.signUp(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password,
                displayName: displayName.trimmingCharacters(in: .whitespaces)
            )
            print("[AuthViewModel] Sign up successful, user: \(user.id)")
            currentUser = user
            startListeningToUser(user.id)
            clearForm()
        } catch {
            print("[AuthViewModel] Sign up failed with error: \(error)")
            print("[AuthViewModel] Error localized description: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
        print("[AuthViewModel] Sign up complete, isLoading = false")
    }
    
    func signIn() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await authService.signIn(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password
            )
            currentUser = user
            startListeningToUser(user.id)
            clearForm()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signOut() {
        do {
            try authService.signOut()
            stopListeningToUser()
            currentUser = nil
            clearForm()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func sendPasswordReset() async {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.sendPasswordReset(
                email: email.trimmingCharacters(in: .whitespaces)
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func restoreSession() async {
        guard let firebaseService = authService as? FirebaseAuthService else {
            return
        }

        do {
            try await firebaseService.restoreSession()
            currentUser = authService.currentUser
            if let userId = currentUser?.id {
                startListeningToUser(userId)
            }
        } catch {
            // Silent failure — user will need to sign in
        }
    }

    func deleteAccount() async throws {
        isLoading = true
        errorMessage = nil

        do {
            try await authService.deleteAccount()
            currentUser = nil
            clearForm()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }

        isLoading = false
    }

    // MARK: - Private

    private func startListeningToUser(_ userId: String) {
        userListener?.remove()
        userListener = userService.addSnapshotListener(forUser: userId) { [weak self] user in
            guard let self else { return }
            Task { @MainActor in self.currentUser = user }
        }
    }

    private func stopListeningToUser() {
        userListener?.remove()
        userListener = nil
    }

    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        displayName = ""
        errorMessage = nil
    }
}
