// Services/FilterSettingsService.swift
//
// Manages filter settings with propose/approve workflow.

import Foundation
import FirebaseFirestore

// MARK: - Protocol

protocol FilterSettingsService {
    func getSettings(for userId: String) async throws -> FilterSettings
    func proposeSettings(_ settings: FilterSettings, filterAdministratorId: String) async throws -> ProposedFilterSettings
    func approveProposal(_ proposalId: String, approvedBy administratorId: String) async throws
    func rejectProposal(_ proposalId: String, rejectedBy administratorId: String) async throws
    func fetchPendingProposals(for userId: String) async throws -> [ProposedFilterSettings]
    func updateSettings(_ settings: FilterSettings) async throws
}

// MARK: - Errors

enum FilterSettingsError: LocalizedError {
    case settingsNotFound
    case proposalNotFound
    case unauthorized
    case invalidSettings
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .settingsNotFound:         return "Filter settings not found"
        case .proposalNotFound:         return "Proposal not found"
        case .unauthorized:             return "You are not authorized to perform this action"
        case .invalidSettings:          return "Invalid filter settings"
        case .unknown(let message):     return message
        }
    }
}

// MARK: - Firebase Implementation

final class FirebaseFilterSettingsService: FilterSettingsService {

    static let shared = FirebaseFilterSettingsService()

    private let storage: BaseModelStorageService

    init(storage: BaseModelStorageService = FirebaseBaseModelStorageService.shared) {
        self.storage = storage
    }

    // MARK: - Get Settings

    func getSettings(for userId: String) async throws -> FilterSettings {
        guard let settings = try await storage.fetch(id: userId, type: FilterSettings.self) else {
            throw FilterSettingsError.settingsNotFound
        }
        return settings
    }

    // MARK: - Propose Settings

    func proposeSettings(_ settings: FilterSettings, filterAdministratorId: String) async throws -> ProposedFilterSettings {
        let proposal = ProposedFilterSettings(
            monitoredUserId: settings.dataOwnerId,
            filterAdministratorId: filterAdministratorId,
            settings: settings
        )
        try await storage.save(proposal)
        return proposal
    }

    // MARK: - Approve Proposal

    func approveProposal(_ proposalId: String, approvedBy administratorId: String) async throws {
        guard let proposal = try await storage.fetch(id: proposalId, type: ProposedFilterSettings.self) else {
            throw FilterSettingsError.proposalNotFound
        }
        guard administratorId == proposal.filterAdministratorId else {
            throw FilterSettingsError.unauthorized
        }

        // serverTimestamp not supported by BaseModelStorageService — direct partial update required
        try await storage.updateFields(
            ["status": ProposedFilterSettings.ProposalStatus.approved.rawValue,
             "reviewedAt": FieldValue.serverTimestamp()],
            id: proposalId,
            type: ProposedFilterSettings.self
        )

        var approvedSettings = proposal.settings
        approvedSettings.lastModifiedBy = administratorId
        approvedSettings.lastModifiedAt = Date()
        try await storage.save(approvedSettings)
    }

    // MARK: - Reject Proposal

    func rejectProposal(_ proposalId: String, rejectedBy administratorId: String) async throws {
        guard let proposal = try await storage.fetch(id: proposalId, type: ProposedFilterSettings.self) else {
            throw FilterSettingsError.proposalNotFound
        }
        guard administratorId == proposal.filterAdministratorId else {
            throw FilterSettingsError.unauthorized
        }

        try await storage.updateFields(
            ["status": ProposedFilterSettings.ProposalStatus.rejected.rawValue,
             "reviewedAt": FieldValue.serverTimestamp()],
            id: proposalId,
            type: ProposedFilterSettings.self
        )
    }

    // MARK: - Fetch Pending Proposals

    func fetchPendingProposals(for userId: String) async throws -> [ProposedFilterSettings] {
        // Compound query (dataOwnerId + status + orderBy) not supported by BaseModelStorageService — direct call required
        let db = Firestore.firestore()
        let snapshot = try await db.collection("proposed_filter_settings")
            .whereField("dataOwnerId", isEqualTo: userId)
            .whereField("status", isEqualTo: ProposedFilterSettings.ProposalStatus.pending.rawValue)
            .order(by: "proposedAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { ProposedFilterSettings.from($0.data()) }
    }

    // MARK: - Update Settings (Direct)

    func updateSettings(_ settings: FilterSettings) async throws {
        try await storage.save(settings)
    }
}

// MARK: - Mock for Testing

final class MockFilterSettingsService: FilterSettingsService {

    var settings: [String: FilterSettings] = [:]
    var proposals: [ProposedFilterSettings] = []
    var shouldFail = false

    func getSettings(for userId: String) async throws -> FilterSettings {
        if shouldFail { throw FilterSettingsError.unknown("Mock error") }
        guard let settings = settings[userId] else { throw FilterSettingsError.settingsNotFound }
        return settings
    }

    func proposeSettings(_ settings: FilterSettings, filterAdministratorId: String) async throws -> ProposedFilterSettings {
        if shouldFail { throw FilterSettingsError.unknown("Mock error") }
        let proposal = ProposedFilterSettings(
            monitoredUserId: settings.dataOwnerId,
            filterAdministratorId: filterAdministratorId,
            settings: settings
        )
        proposals.append(proposal)
        return proposal
    }

    func approveProposal(_ proposalId: String, approvedBy administratorId: String) async throws {
        if shouldFail { throw FilterSettingsError.unknown("Mock error") }
        guard let index = proposals.firstIndex(where: { $0.id == proposalId }) else {
            throw FilterSettingsError.proposalNotFound
        }
        let proposal = proposals[index]
        guard administratorId == proposal.filterAdministratorId else {
            throw FilterSettingsError.unauthorized
        }
        var approvedSettings = proposal.settings
        approvedSettings.lastModifiedBy = administratorId
        settings[proposal.dataOwnerId] = approvedSettings
        proposals[index] = ProposedFilterSettings(
            id: proposal.id, monitoredUserId: proposal.dataOwnerId,
            filterAdministratorId: proposal.filterAdministratorId,
            settings: proposal.settings, status: .approved,
            proposedAt: proposal.proposedAt, reviewedAt: Date()
        )
    }

    func rejectProposal(_ proposalId: String, rejectedBy administratorId: String) async throws {
        if shouldFail { throw FilterSettingsError.unknown("Mock error") }
        guard let index = proposals.firstIndex(where: { $0.id == proposalId }) else {
            throw FilterSettingsError.proposalNotFound
        }
        let proposal = proposals[index]
        guard administratorId == proposal.filterAdministratorId else {
            throw FilterSettingsError.unauthorized
        }
        proposals[index] = ProposedFilterSettings(
            id: proposal.id, monitoredUserId: proposal.dataOwnerId,
            filterAdministratorId: proposal.filterAdministratorId,
            settings: proposal.settings, status: .rejected,
            proposedAt: proposal.proposedAt, reviewedAt: Date()
        )
    }

    func fetchPendingProposals(for userId: String) async throws -> [ProposedFilterSettings] {
        if shouldFail { throw FilterSettingsError.unknown("Mock error") }
        return proposals.filter { $0.dataOwnerId == userId && $0.status == .pending }
    }

    func updateSettings(_ settings: FilterSettings) async throws {
        if shouldFail { throw FilterSettingsError.unknown("Mock error") }
        self.settings[settings.dataOwnerId] = settings
    }
}

// MARK: - ProposedFilterSettings Firestore Helpers

extension ProposedFilterSettings {

    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "dataOwnerId": dataOwnerId,
            "filterAdministratorId": filterAdministratorId,
            "status": status.rawValue,
            "proposedAt": proposedAt,
            "settings": settings.asDictionary
        ]
        if let reviewedAt { dict["reviewedAt"] = reviewedAt }
        return dict
    }

    static func from(_ data: [String: Any]) -> ProposedFilterSettings? {
        guard let id = data["id"] as? String,
              let dataOwnerId = data["dataOwnerId"] as? String,
              let filterAdministratorId = data["filterAdministratorId"] as? String,
              let statusRaw = data["status"] as? String,
              let status = ProposalStatus(rawValue: statusRaw),
              let settingsData = data["settings"] as? [String: Any],
              let settings = FilterSettings.from(settingsData) else {
            return nil
        }

        let proposedAt = data["proposedAt"] as? Date ?? Date()
        let reviewedAt = data["reviewedAt"] as? Date

        return ProposedFilterSettings(
            id: id,
            monitoredUserId: dataOwnerId,
            filterAdministratorId: filterAdministratorId,
            settings: settings,
            status: status,
            proposedAt: proposedAt,
            reviewedAt: reviewedAt
        )
    }
}
