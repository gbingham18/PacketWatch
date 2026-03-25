// Services/UserService.swift
//
// Manages user document reads, partial updates, and realtime listeners.

import Foundation
import FirebaseFirestore

// MARK: - Protocol

protocol UserService {
    func fetchUser(id: String) async throws -> User?
    func updateFields(_ fields: [String: Any], forUser userId: String) async throws
    func addSnapshotListener(forUser userId: String, onChange: @escaping (User) -> Void) -> ListenerRegistration
}

// MARK: - Errors

enum UserServiceError: LocalizedError {
    case userNotFound
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .userNotFound:         return "User not found"
        case .unknown(let message): return message
        }
    }
}

// MARK: - Firebase Implementation

final class FirebaseUserService: UserService {

    static let shared = FirebaseUserService()

    private let storage: BaseModelStorageService

    init(storage: BaseModelStorageService = FirebaseBaseModelStorageService.shared) {
        self.storage = storage
    }

    func fetchUser(id: String) async throws -> User? {
        try await storage.fetch(id: id, type: User.self)
    }

    func updateFields(_ fields: [String: Any], forUser userId: String) async throws {
        try await storage.updateFields(fields, id: userId, type: User.self)
    }

    func addSnapshotListener(forUser userId: String, onChange: @escaping (User) -> Void) -> ListenerRegistration {
        storage.addSnapshotListener(id: userId, type: User.self, onChange: onChange)
    }
}

// MARK: - Mock for Testing

final class MockUserService: UserService {

    var users: [String: User] = [:]
    var shouldFail = false

    func fetchUser(id: String) async throws -> User? {
        if shouldFail { throw UserServiceError.unknown("Mock error") }
        return users[id]
    }

    func updateFields(_ fields: [String: Any], forUser userId: String) async throws {
        if shouldFail { throw UserServiceError.unknown("Mock error") }
        // No-op in mock — tests can inspect calls separately if needed
    }

    func addSnapshotListener(forUser userId: String, onChange: @escaping (User) -> Void) -> ListenerRegistration {
        MockListenerRegistration()
    }
}
