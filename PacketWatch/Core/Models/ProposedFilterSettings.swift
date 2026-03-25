// Core/Models/ProposedFilterSettings.swift
//
// Represents a proposed change to filter settings that requires administrator approval.

import Foundation

struct ProposedFilterSettings: BaseModel {
    let id: String                  // UUID string
    let dataOwnerId: String         // Firebase Auth UID of the monitored user who proposed these settings
    let filterAdministratorId: String  // Firebase Auth UID of the admin who must approve/reject
    let settings: FilterSettings
    let status: ProposalStatus
    let proposedAt: Date
    let reviewedAt: Date?

    enum ProposalStatus: String, Codable {
        case pending
        case approved
        case rejected
    }

    init(
        id: String = UUID().uuidString,
        monitoredUserId: String,
        filterAdministratorId: String,
        settings: FilterSettings,
        status: ProposalStatus = .pending,
        proposedAt: Date = Date(),
        reviewedAt: Date? = nil
    ) {
        self.id = id
        self.dataOwnerId = monitoredUserId
        self.filterAdministratorId = filterAdministratorId
        self.settings = settings
        self.status = status
        self.proposedAt = proposedAt
        self.reviewedAt = reviewedAt
    }
}
