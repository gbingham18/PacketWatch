// Services/InvitationService.swift
//
// Manages invitations for accountability networks.

import Foundation
import FirebaseFirestore

// MARK: - Protocol

protocol InvitationService {
    func sendInvitation(fromUser: User, toEmail: String, networkId: String, role: Invitation.InvitationRole) async throws -> Invitation
    func acceptInvitation(_ invitationId: String, byUser user: User) async throws
    func declineInvitation(_ invitationId: String) async throws
    func fetchPendingInvitations(forEmail email: String) async throws -> [Invitation]
    func fetchSentInvitations(fromUserId: String) async throws -> [Invitation]
}

// MARK: - Errors

enum InvitationError: LocalizedError {
    case invitationNotFound
    case invitationExpired
    case invitationAlreadyAccepted
    case networkNotFound
    case userNotFound
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invitationNotFound:           return "Invitation not found"
        case .invitationExpired:            return "This invitation has expired"
        case .invitationAlreadyAccepted:    return "This invitation has already been accepted"
        case .networkNotFound:              return "Accountability network not found"
        case .userNotFound:                 return "User not found"
        case .unknown(let message):         return message
        }
    }
}

// MARK: - Firebase Implementation

final class FirebaseInvitationService: InvitationService {

    static let shared = FirebaseInvitationService()

    private let storage: BaseModelStorageService
    private let networkService: AccountabilityNetworkService
    private let userService: UserService

    init(
        storage: BaseModelStorageService = FirebaseBaseModelStorageService.shared,
        networkService: AccountabilityNetworkService = FirebaseAccountabilityNetworkService.shared,
        userService: UserService = FirebaseUserService.shared
    ) {
        self.storage = storage
        self.networkService = networkService
        self.userService = userService
    }

    // MARK: - Send Invitation

    func sendInvitation(fromUser: User, toEmail: String, networkId: String, role: Invitation.InvitationRole) async throws -> Invitation {
        let invitation = Invitation(
            fromUserId: fromUser.id,
            fromUserName: fromUser.displayName,
            toUserEmail: toEmail.lowercased().trimmingCharacters(in: .whitespaces),
            networkId: networkId,
            role: role
        )
        try await storage.save(invitation)
        return invitation
    }

    // MARK: - Accept Invitation

    func acceptInvitation(_ invitationId: String, byUser user: User) async throws {
        guard let invitation = try await storage.fetch(id: invitationId, type: Invitation.self) else {
            throw InvitationError.invitationNotFound
        }

        guard invitation.status == .pending else {
            throw InvitationError.invitationAlreadyAccepted
        }
        guard !invitation.isExpired else {
            throw InvitationError.invitationExpired
        }

        print("[InvitationService] updating invitation status to accepted")
        try await storage.updateFields(
            ["status": Invitation.InvitationStatus.accepted.rawValue, "toUserId": user.id],
            id: invitationId,
            type: Invitation.self
        )
        print("[InvitationService] invitation status updated")

        print("[InvitationService] fetching network document: accountability_networks/\(invitation.networkId)")
        guard try await networkService.fetchNetwork(id: invitation.networkId) != nil else {
            print("[InvitationService] network document not found")
            throw InvitationError.networkNotFound
        }
        print("[InvitationService] network document found, updating for role=\(invitation.role)")

        switch invitation.role {
        case .administrator:
            print("[InvitationService] setting filterAdministratorUserId=\(user.id) and adding to allyUserIds")
            try await networkService.updateFilterAdministrator(invitation.networkId, userId: user.id)
        case .ally:
            print("[InvitationService] adding \(user.id) to allyUserIds")
            try await networkService.addAlly(invitation.networkId, userId: user.id)
        }

        print("[InvitationService] adding networkListFeatureId to user \(user.id)")
        try await userService.updateFields(
            ["featureIds": FieldValue.arrayUnion([WellKnownFeatureIds.networkListFeatureId])],
            forUser: user.id
        )

        print("[InvitationService] acceptInvitation complete")
    }

    // MARK: - Decline Invitation

    func declineInvitation(_ invitationId: String) async throws {
        guard try await storage.fetch(id: invitationId, type: Invitation.self) != nil else {
            throw InvitationError.invitationNotFound
        }
        try await storage.updateFields(
            ["status": Invitation.InvitationStatus.declined.rawValue],
            id: invitationId,
            type: Invitation.self
        )
    }

    // MARK: - Fetch Pending Invitations

    func fetchPendingInvitations(forEmail email: String) async throws -> [Invitation] {
        // Compound query (toUserEmail + status) not supported by BaseModelStorageService — direct call required
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        let db = Firestore.firestore()
        let snapshot = try await db.collection("invitations")
            .whereField("toUserEmail", isEqualTo: normalizedEmail)
            .whereField("status", isEqualTo: Invitation.InvitationStatus.pending.rawValue)
            .getDocuments()
        return snapshot.documents.compactMap { Invitation.from($0.data()) }.filter { !$0.isExpired }
    }

    // MARK: - Fetch Sent Invitations

    func fetchSentInvitations(fromUserId: String) async throws -> [Invitation] {
        // Single field query — use storage
        try await storage.fetchAll(
            matching: SearchFilter(filters: [FieldFilter(fieldName: "fromUserId", operation: .isEqualTo(fromUserId))]),
            type: Invitation.self
        )
    }
}

// MARK: - Mock for Testing

final class MockInvitationService: InvitationService {

    var invitations: [Invitation] = []
    var shouldFail = false

    func sendInvitation(fromUser: User, toEmail: String, networkId: String, role: Invitation.InvitationRole) async throws -> Invitation {
        if shouldFail { throw InvitationError.unknown("Mock error") }
        let invitation = Invitation(fromUserId: fromUser.id, fromUserName: fromUser.displayName, toUserEmail: toEmail, networkId: networkId, role: role)
        invitations.append(invitation)
        return invitation
    }

    func acceptInvitation(_ invitationId: String, byUser user: User) async throws {
        if shouldFail { throw InvitationError.unknown("Mock error") }
        guard let index = invitations.firstIndex(where: { $0.id == invitationId }) else {
            throw InvitationError.invitationNotFound
        }
        let inv = invitations[index]
        guard inv.status == .pending else { throw InvitationError.invitationAlreadyAccepted }
        invitations[index] = Invitation(id: inv.id, fromUserId: inv.fromUserId, fromUserName: inv.fromUserName,
            toUserEmail: inv.toUserEmail, toUserId: user.id, networkId: inv.networkId,
            role: inv.role, status: .accepted, createdAt: inv.createdAt, expiresAt: inv.expiresAt)
    }

    func declineInvitation(_ invitationId: String) async throws {
        if shouldFail { throw InvitationError.unknown("Mock error") }
        guard let index = invitations.firstIndex(where: { $0.id == invitationId }) else {
            throw InvitationError.invitationNotFound
        }
        let inv = invitations[index]
        invitations[index] = Invitation(id: inv.id, fromUserId: inv.fromUserId, fromUserName: inv.fromUserName,
            toUserEmail: inv.toUserEmail, toUserId: inv.toUserId, networkId: inv.networkId,
            role: inv.role, status: .declined, createdAt: inv.createdAt, expiresAt: inv.expiresAt)
    }

    func fetchPendingInvitations(forEmail email: String) async throws -> [Invitation] {
        if shouldFail { throw InvitationError.unknown("Mock error") }
        return invitations.filter { $0.toUserEmail.lowercased() == email.lowercased() && $0.status == .pending && !$0.isExpired }
    }

    func fetchSentInvitations(fromUserId: String) async throws -> [Invitation] {
        if shouldFail { throw InvitationError.unknown("Mock error") }
        return invitations.filter { $0.fromUserId == fromUserId }
    }
}
