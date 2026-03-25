// Core/Models/User.swift
//
// User account model.

import Foundation

struct User: BaseModel {
    let id: String          // Firebase Auth UID
    let dataOwnerId: String // Self-owned: dataOwnerId == id
    let email: String
    let displayName: String
    let createdAt: Date
    var onboardingComplete: Bool
    var accountabilityNetworkId: String?
    var featureIds: [String]

    init(
        id: String,
        email: String,
        displayName: String,
        createdAt: Date = Date(),
        onboardingComplete: Bool = false,
        accountabilityNetworkId: String? = nil,
        featureIds: [String] = []
    ) {
        self.id = id
        self.dataOwnerId = id  // User owns their own data
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
        self.onboardingComplete = onboardingComplete
        self.accountabilityNetworkId = accountabilityNetworkId
        self.featureIds = featureIds
    }
}

// MARK: - Firestore Helpers

extension User {

    /// Convert to Firestore dictionary
    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "dataOwnerId": dataOwnerId,
            "email": email,
            "displayName": displayName,
            "createdAt": createdAt,
            "onboardingComplete": onboardingComplete,
            "featureIds": featureIds
        ]
        if let networkId = accountabilityNetworkId {
            dict["accountabilityNetworkId"] = networkId
        }
        return dict
    }

    /// Create from Firestore document data
    static func from(_ data: [String: Any]) -> User? {
        guard let id = data["id"] as? String,
              let email = data["email"] as? String,
              let displayName = data["displayName"] as? String else {
            return nil
        }

        let createdAt = (data["createdAt"] as? Date) ?? Date()
        let onboardingComplete = data["onboardingComplete"] as? Bool ?? false
        let accountabilityNetworkId = data["accountabilityNetworkId"] as? String
        let featureIds = data["featureIds"] as? [String] ?? []

        return User(
            id: id,
            email: email,
            displayName: displayName,
            createdAt: createdAt,
            onboardingComplete: onboardingComplete,
            accountabilityNetworkId: accountabilityNetworkId,
            featureIds: featureIds
        )
    }
}
