// Core/Models/Invitation.swift
//
// Represents an invitation to join an accountability network.

import Foundation

struct Invitation: BaseModel {
    let id: String          // UUID string
    let dataOwnerId: String // Firebase Auth UID of the person who sent the invitation
    let fromUserId: String  // Firebase Auth UID
    let fromUserName: String
    let toUserEmail: String
    let toUserId: String?   // Firebase Auth UID, set when recipient accepts
    let networkId: String   // UUID string of the network
    let role: InvitationRole
    let status: InvitationStatus
    let createdAt: Date
    let expiresAt: Date

    enum InvitationRole: String, Codable {
        case administrator  // Can approve filter settings
        case ally          // Can view activity reports
    }

    enum InvitationStatus: String, Codable {
        case pending
        case accepted
        case declined
        case expired
    }

    init(
        id: String = UUID().uuidString,
        fromUserId: String,
        fromUserName: String,
        toUserEmail: String,
        toUserId: String? = nil,
        networkId: String,
        role: InvitationRole,
        status: InvitationStatus = .pending,
        createdAt: Date = Date(),
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.dataOwnerId = fromUserId
        self.fromUserId = fromUserId
        self.fromUserName = fromUserName
        self.toUserEmail = toUserEmail
        self.toUserId = toUserId
        self.networkId = networkId
        self.role = role
        self.status = status
        self.createdAt = createdAt
        self.expiresAt = expiresAt ?? Calendar.current.date(byAdding: .day, value: 7, to: createdAt)!
    }
}

// MARK: - Computed Properties

extension Invitation {

    var isExpired: Bool {
        Date() > expiresAt
    }

    var isPending: Bool {
        status == .pending && !isExpired
    }

    var description: String {
        switch role {
        case .administrator:
            return "\(fromUserName) wants you to manage their filter settings"
        case .ally:
            return "\(fromUserName) wants you to be an accountability ally"
        }
    }
}

// MARK: - Firestore Helpers

extension Invitation {

    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "dataOwnerId": dataOwnerId,
            "fromUserId": fromUserId,
            "fromUserName": fromUserName,
            "toUserEmail": toUserEmail,
            "networkId": networkId,
            "role": role.rawValue,
            "status": status.rawValue,
            "createdAt": createdAt,
            "expiresAt": expiresAt
        ]
        if let toUserId = toUserId {
            dict["toUserId"] = toUserId
        }
        return dict
    }

    static func from(_ data: [String: Any]) -> Invitation? {
        guard let id = data["id"] as? String,
              let fromUserId = data["fromUserId"] as? String,
              let fromUserName = data["fromUserName"] as? String,
              let toUserEmail = data["toUserEmail"] as? String,
              let networkId = data["networkId"] as? String,
              let roleString = data["role"] as? String,
              let role = InvitationRole(rawValue: roleString),
              let statusString = data["status"] as? String,
              let status = InvitationStatus(rawValue: statusString) else {
            return nil
        }

        let toUserId = data["toUserId"] as? String
        let createdAt = data["createdAt"] as? Date ?? Date()
        let expiresAt = data["expiresAt"] as? Date ?? Calendar.current.date(byAdding: .day, value: 7, to: createdAt)!

        return Invitation(
            id: id,
            fromUserId: fromUserId,
            fromUserName: fromUserName,
            toUserEmail: toUserEmail,
            toUserId: toUserId,
            networkId: networkId,
            role: role,
            status: status,
            createdAt: createdAt,
            expiresAt: expiresAt
        )
    }
}
