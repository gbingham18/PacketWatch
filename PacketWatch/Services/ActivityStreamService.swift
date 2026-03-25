// Services/ActivityStreamService.swift
//
// Manages activity streams with deduplication logic for Safari + Network Extension.

import Foundation
import FirebaseFirestore

// MARK: - Protocol

protocol ActivityStreamService {
    func createStream(networkId: String, monitoredUserId: String) async throws
    func addEntry(_ entry: ActivityEntry, forNetwork networkId: String) async throws
    func fetchStream(forNetwork networkId: String, limit: Int?) async throws -> ActivityStream
    func fetchEntries(forNetwork networkId: String, from startDate: Date, to endDate: Date) async throws -> [ActivityEntry]
    func deleteEntriesOlderThan(_ date: Date, forNetwork networkId: String) async throws
}

// MARK: - Errors

enum ActivityStreamError: LocalizedError {
    case streamNotFound
    case invalidEntry
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .streamNotFound:           return "Activity stream not found"
        case .invalidEntry:             return "Invalid activity entry"
        case .unknown(let message):     return message
        }
    }
}

// MARK: - Firebase Implementation

final class FirebaseActivityStreamService: ActivityStreamService {

    static let shared = FirebaseActivityStreamService()

    private let storage: BaseModelStorageService
    private let deduplicationWindowSeconds: TimeInterval = 5.0

    init(storage: BaseModelStorageService = FirebaseBaseModelStorageService.shared) {
        self.storage = storage
    }

    // MARK: - Create Stream

    func createStream(networkId: String, monitoredUserId: String) async throws {
        // Only create if it doesn't already exist
        if try await storage.fetch(id: networkId, type: ActivityStream.self) == nil {
            let stream = ActivityStream(id: networkId, monitoredUserId: monitoredUserId)
            try await storage.save(stream)
        }
    }

    // MARK: - Add Entry with Deduplication

    func addEntry(_ entry: ActivityEntry, forNetwork networkId: String) async throws {
        let windowStart = entry.timestamp.addingTimeInterval(-deduplicationWindowSeconds)
        let windowEnd = entry.timestamp.addingTimeInterval(deduplicationWindowSeconds)

        let existingEntries = try await storage.fetchFromSubcollection(
            subcollection: "entries",
            ofDocument: networkId,
            inCollection: "activityStreams",
            matching: SearchFilter(filters: [
                FieldFilter(fieldName: "domain", operation: .isEqualTo(entry.domain)),
                FieldFilter(fieldName: "timestamp", operation: .isGreaterThanOrEqualToDate(windowStart)),
                FieldFilter(fieldName: "timestamp", operation: .isLessThanOrEqualToDate(windowEnd))
            ], limit: 5),
            type: ActivityEntry.self
        )

        if let existingEntry = existingEntries.first {
            if shouldMergeEntries(existing: existingEntry, new: entry) {
                let mergedEntry = mergeEntries(existing: existingEntry, new: entry)
                try await storage.save(mergedEntry, toSubcollection: "entries", ofDocument: networkId, inCollection: "activityStreams")
            }
            // Otherwise skip - duplicate
        } else {
            try await storage.save(entry, toSubcollection: "entries", ofDocument: networkId, inCollection: "activityStreams")
            try await updateStreamMetadata(networkId: networkId)
        }
    }

    // MARK: - Fetch Stream

    func fetchStream(forNetwork networkId: String, limit: Int? = 1000) async throws -> ActivityStream {
        guard let stream = try await storage.fetch(id: networkId, type: ActivityStream.self) else {
            throw ActivityStreamError.streamNotFound
        }

        let entries = try await storage.fetchFromSubcollection(
            subcollection: "entries",
            ofDocument: networkId,
            inCollection: "activityStreams",
            matching: SearchFilter(orderBy: "timestamp", descending: true, limit: limit),
            type: ActivityEntry.self
        )

        return ActivityStream(id: stream.id, monitoredUserId: stream.monitoredUserId, entries: entries, createdAt: stream.createdAt, updatedAt: stream.updatedAt)
    }

    // MARK: - Fetch Entries in Time Range

    func fetchEntries(forNetwork networkId: String, from startDate: Date, to endDate: Date) async throws -> [ActivityEntry] {
        try await storage.fetchFromSubcollection(
            subcollection: "entries",
            ofDocument: networkId,
            inCollection: "activityStreams",
            matching: SearchFilter(filters: [
                FieldFilter(fieldName: "timestamp", operation: .isGreaterThanOrEqualToDate(startDate)),
                FieldFilter(fieldName: "timestamp", operation: .isLessThanOrEqualToDate(endDate))
            ], orderBy: "timestamp", descending: true),
            type: ActivityEntry.self
        )
    }

    // MARK: - Delete Old Entries

    func deleteEntriesOlderThan(_ date: Date, forNetwork networkId: String) async throws {
        try await storage.deleteFromSubcollection(
            subcollection: "entries",
            ofDocument: networkId,
            inCollection: "activityStreams",
            matching: SearchFilter(filters: [
                FieldFilter(fieldName: "timestamp", operation: .isLessThanDate(date))
            ]),
            type: ActivityEntry.self
        )
    }

    // MARK: - Private Helpers

    private func shouldMergeEntries(existing: ActivityEntry, new: ActivityEntry) -> Bool {
        if new.source == .safariExtension && existing.source != .safariExtension { return true }
        if new.category != nil && existing.category == nil { return true }
        if new.inferredApp != nil && existing.inferredApp == nil { return true }
        return false
    }

    private func mergeEntries(existing: ActivityEntry, new: ActivityEntry) -> ActivityEntry {
        let mergedSource: ActivityEntry.DetectionSource =
            (new.source == .safariExtension || existing.source == .safariExtension) ? .safariExtension : existing.source

        return ActivityEntry(
            id: existing.id,
            dataOwnerId: existing.dataOwnerId,
            domain: existing.domain,
            timestamp: existing.timestamp,
            source: mergedSource,
            category: new.category ?? existing.category,
            isFlagged: new.isFlagged || existing.isFlagged,
            inferredApp: new.inferredApp ?? existing.inferredApp,
            appConfidence: new.appConfidence ?? existing.appConfidence,
            monitoringLevel: new.monitoringLevel ?? existing.monitoringLevel
        )
    }

    private func updateStreamMetadata(networkId: String) async throws {
        // Only update if the stream doc exists (created during onboarding)
        guard try await storage.fetch(id: networkId, type: ActivityStream.self) != nil else { return }
        try await storage.updateFields(
            ["updatedAt": FieldValue.serverTimestamp()],
            id: networkId,
            type: ActivityStream.self
        )
    }
}

// MARK: - Mock for Testing

final class MockActivityStreamService: ActivityStreamService {

    var streams: [String: ActivityStream] = [:]
    var shouldFail = false

    func createStream(networkId: String, monitoredUserId: String) async throws {
        if shouldFail { throw ActivityStreamError.unknown("Mock error") }
        if streams[networkId] == nil {
            streams[networkId] = ActivityStream(id: networkId, monitoredUserId: monitoredUserId)
        }
    }

    func addEntry(_ entry: ActivityEntry, forNetwork networkId: String) async throws {
        if shouldFail { throw ActivityStreamError.unknown("Mock error") }
        let stream = streams[networkId] ?? ActivityStream(monitoredUserId: "")
        var entries = stream.entries
        entries.append(entry)
        streams[networkId] = ActivityStream(id: stream.id, monitoredUserId: stream.monitoredUserId, entries: entries, createdAt: stream.createdAt, updatedAt: Date())
    }

    func fetchStream(forNetwork networkId: String, limit: Int? = nil) async throws -> ActivityStream {
        if shouldFail { throw ActivityStreamError.unknown("Mock error") }
        let stream = streams[networkId] ?? ActivityStream(monitoredUserId: "")
        if let limit {
            return ActivityStream(id: stream.id, monitoredUserId: stream.monitoredUserId, entries: Array(stream.entries.prefix(limit)), createdAt: stream.createdAt, updatedAt: stream.updatedAt)
        }
        return stream
    }

    func fetchEntries(forNetwork networkId: String, from startDate: Date, to endDate: Date) async throws -> [ActivityEntry] {
        if shouldFail { throw ActivityStreamError.unknown("Mock error") }
        return (streams[networkId]?.entries ?? []).filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }

    func deleteEntriesOlderThan(_ date: Date, forNetwork networkId: String) async throws {
        if shouldFail { throw ActivityStreamError.unknown("Mock error") }
        guard let stream = streams[networkId] else { return }
        let filtered = stream.entries.filter { $0.timestamp >= date }
        streams[networkId] = ActivityStream(id: stream.id, monitoredUserId: stream.monitoredUserId, entries: filtered, createdAt: stream.createdAt, updatedAt: Date())
    }
}
