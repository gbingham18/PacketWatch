// Core/Models/AccountabilityNetwork.swift
//
// Defines the accountability relationships for a monitored user.
// - One monitored user (account owner)
// - One filter Administrator (manages settings)
// - Multiple allies (can view reports)

import Foundation

struct AccountabilityNetwork: BaseModel {
    let id: String                          // UUID string
    let dataOwnerId: String                 // Firebase Auth UID of the monitored user
    let monitoredUserId: String             // Firebase Auth UID of person being tracked
    let filterAdministratorUserId: String   // Firebase Auth UID of admin who manages settings
    let allyUserIds: [String]              // Firebase Auth UIDs of allies
    let activityStreamId: String            // ID of the associated ActivityStream document
    let status: NetworkStatus
    let createdAt: Date

    enum NetworkStatus: String, Codable {
        case pending    // Setup started but not complete
        case active     // Fully active, monitoring enabled
        case paused     // Temporarily disabled
        case ended      // Dissolved
    }

    init(
        id: String = UUID().uuidString,
        monitoredUserId: String,
        filterAdministratorUserId: String,
        allyUserIds: [String] = [],
        activityStreamId: String? = nil,
        status: NetworkStatus = .pending,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.dataOwnerId = monitoredUserId  // Network belongs to monitored user
        self.monitoredUserId = monitoredUserId
        self.filterAdministratorUserId = filterAdministratorUserId
        self.allyUserIds = allyUserIds
        self.activityStreamId = activityStreamId ?? id  // Defaults to network ID
        self.status = status
        self.createdAt = createdAt
    }
}

// MARK: - Convenience Methods

extension AccountabilityNetwork {

    func isAlly(_ userId: String) -> Bool {
        allyUserIds.contains(userId)
    }

    func isFilterAdministrator(_ userId: String) -> Bool {
        filterAdministratorUserId == userId
    }

    func hasAccess(_ userId: String) -> Bool {
        monitoredUserId == userId || isAlly(userId)
    }

    func addingAlly(_ userId: String) -> AccountabilityNetwork {
        guard !allyUserIds.contains(userId) else { return self }
        return AccountabilityNetwork(
            id: id,
            monitoredUserId: monitoredUserId,
            filterAdministratorUserId: filterAdministratorUserId,
            allyUserIds: allyUserIds + [userId],
            activityStreamId: activityStreamId,
            status: status,
            createdAt: createdAt
        )
    }

    func removingAlly(_ userId: String) -> AccountabilityNetwork {
        AccountabilityNetwork(
            id: id,
            monitoredUserId: monitoredUserId,
            filterAdministratorUserId: filterAdministratorUserId,
            allyUserIds: allyUserIds.filter { $0 != userId },
            activityStreamId: activityStreamId,
            status: status,
            createdAt: createdAt
        )
    }

    func changingFilterGuardian(to userId: String) -> AccountabilityNetwork {
        AccountabilityNetwork(
            id: id,
            monitoredUserId: monitoredUserId,
            filterAdministratorUserId: userId,
            allyUserIds: allyUserIds,
            activityStreamId: activityStreamId,
            status: status,
            createdAt: createdAt
        )
    }

    func withStatus(_ newStatus: NetworkStatus) -> AccountabilityNetwork {
        AccountabilityNetwork(
            id: id,
            monitoredUserId: monitoredUserId,
            filterAdministratorUserId: filterAdministratorUserId,
            allyUserIds: allyUserIds,
            activityStreamId: activityStreamId,
            status: newStatus,
            createdAt: createdAt
        )
    }
}

// MARK: - Firestore Helpers

extension AccountabilityNetwork {

    var asDictionary: [String: Any] {
        [
            "id": id,
            "dataOwnerId": dataOwnerId,
            "monitoredUserId": monitoredUserId,
            "filterAdministratorUserId": filterAdministratorUserId,
            "allyUserIds": allyUserIds,
            "activityStreamId": activityStreamId,
            "status": status.rawValue,
            "createdAt": createdAt
        ]
    }

    static func from(_ data: [String: Any]) -> AccountabilityNetwork? {
        guard let id = data["id"] as? String,
              let monitoredUserId = data["monitoredUserId"] as? String,
              let filterAdministratorUserId = data["filterAdministratorUserId"] as? String,
              let statusString = data["status"] as? String,
              let status = NetworkStatus(rawValue: statusString) else {
            return nil
        }

        let allyUserIds = data["allyUserIds"] as? [String] ?? []
        let activityStreamId = data["activityStreamId"] as? String ?? id
        let createdAt = data["createdAt"] as? Date ?? Date()

        return AccountabilityNetwork(
            id: id,
            monitoredUserId: monitoredUserId,
            filterAdministratorUserId: filterAdministratorUserId,
            allyUserIds: allyUserIds,
            activityStreamId: activityStreamId,
            status: status,
            createdAt: createdAt
        )
    }
}
