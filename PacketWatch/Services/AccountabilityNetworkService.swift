// Services/AccountabilityNetworkService.swift
//
// Manages accountability network CRUD operations.

import Foundation
import FirebaseFirestore

// MARK: - Protocol

protocol AccountabilityNetworkService {
    func create(_ network: AccountabilityNetwork) async throws
    func updateStatus(_ networkId: String, status: AccountabilityNetwork.NetworkStatus) async throws
    func updateFilterAdministrator(_ networkId: String, userId: String) async throws
    func addAlly(_ networkId: String, userId: String) async throws
    func fetchNetworksForAlly(userId: String) async throws -> [AccountabilityNetwork]
    func fetchNetwork(id: String) async throws -> AccountabilityNetwork?
}

// MARK: - Errors

enum AccountabilityNetworkError: LocalizedError {
    case networkNotFound
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .networkNotFound:      return "Accountability network not found"
        case .unknown(let message): return message
        }
    }
}

// MARK: - Firebase Implementation

final class FirebaseAccountabilityNetworkService: AccountabilityNetworkService {

    static let shared = FirebaseAccountabilityNetworkService()

    private let storage: BaseModelStorageService

    init(storage: BaseModelStorageService = FirebaseBaseModelStorageService.shared) {
        self.storage = storage
    }

    func create(_ network: AccountabilityNetwork) async throws {
        try await storage.save(network)
    }

    func updateStatus(_ networkId: String, status: AccountabilityNetwork.NetworkStatus) async throws {
        try await storage.updateFields(["status": status.rawValue], id: networkId, type: AccountabilityNetwork.self)
    }

    func updateFilterAdministrator(_ networkId: String, userId: String) async throws {
        try await storage.updateFields(
            ["filterAdministratorUserId": userId, "allyUserIds": FieldValue.arrayUnion([userId])],
            id: networkId,
            type: AccountabilityNetwork.self
        )
    }

    func addAlly(_ networkId: String, userId: String) async throws {
        try await storage.updateFields(
            ["allyUserIds": FieldValue.arrayUnion([userId])],
            id: networkId,
            type: AccountabilityNetwork.self
        )
    }

    func fetchNetworksForAlly(userId: String) async throws -> [AccountabilityNetwork] {
        try await storage.fetchAll(
            matching: SearchFilter(filters: [
                FieldFilter(fieldName: "allyUserIds", operation: .arrayContains(userId)),
                FieldFilter(fieldName: "status", operation: .isEqualTo(AccountabilityNetwork.NetworkStatus.active.rawValue))
            ]),
            type: AccountabilityNetwork.self
        )
    }

    func fetchNetwork(id: String) async throws -> AccountabilityNetwork? {
        try await storage.fetch(id: id, type: AccountabilityNetwork.self)
    }
}

// MARK: - Mock for Testing

final class MockAccountabilityNetworkService: AccountabilityNetworkService {

    var networks: [String: AccountabilityNetwork] = [:]
    var shouldFail = false

    func create(_ network: AccountabilityNetwork) async throws {
        if shouldFail { throw AccountabilityNetworkError.unknown("Mock error") }
        networks[network.id] = network
    }

    func updateStatus(_ networkId: String, status: AccountabilityNetwork.NetworkStatus) async throws {
        if shouldFail { throw AccountabilityNetworkError.unknown("Mock error") }
        guard let network = networks[networkId] else { throw AccountabilityNetworkError.networkNotFound }
        networks[networkId] = network.withStatus(status)
    }

    func updateFilterAdministrator(_ networkId: String, userId: String) async throws {
        if shouldFail { throw AccountabilityNetworkError.unknown("Mock error") }
        guard let network = networks[networkId] else { throw AccountabilityNetworkError.networkNotFound }
        networks[networkId] = network.changingFilterGuardian(to: userId).addingAlly(userId)
    }

    func addAlly(_ networkId: String, userId: String) async throws {
        if shouldFail { throw AccountabilityNetworkError.unknown("Mock error") }
        guard let network = networks[networkId] else { throw AccountabilityNetworkError.networkNotFound }
        networks[networkId] = network.addingAlly(userId)
    }

    func fetchNetworksForAlly(userId: String) async throws -> [AccountabilityNetwork] {
        if shouldFail { throw AccountabilityNetworkError.unknown("Mock error") }
        return networks.values.filter { $0.allyUserIds.contains(userId) && $0.status == .active }
    }

    func fetchNetwork(id: String) async throws -> AccountabilityNetwork? {
        if shouldFail { throw AccountabilityNetworkError.unknown("Mock error") }
        return networks[id]
    }
}
