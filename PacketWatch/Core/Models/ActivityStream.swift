// Core/Models/ActivityStream.swift
//
// A collection of activity entries with filtering and sorting capabilities.

import Foundation

struct ActivityStream: BaseModel {
    let id: String              // UUID string
    let monitoredUserId: String // Firebase Auth UID
    let entries: [ActivityEntry]
    let createdAt: Date
    let updatedAt: Date

    var dataOwnerId: String { monitoredUserId }

    init(
        id: String = UUID().uuidString,
        monitoredUserId: String,
        entries: [ActivityEntry] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.monitoredUserId = monitoredUserId
        self.entries = entries
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Filtering

extension ActivityStream {

    func filtered(from startDate: Date, to endDate: Date) -> ActivityStream {
        let filtered = entries.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
        return ActivityStream(id: id, monitoredUserId: monitoredUserId, entries: filtered, createdAt: createdAt, updatedAt: updatedAt)
    }

    func filtered(by category: String) -> ActivityStream {
        let filtered = entries.filter { $0.category == category }
        return ActivityStream(id: id, monitoredUserId: monitoredUserId, entries: filtered, createdAt: createdAt, updatedAt: updatedAt)
    }

    var flaggedOnly: ActivityStream {
        let filtered = entries.filter { $0.isFlagged }
        return ActivityStream(id: id, monitoredUserId: monitoredUserId, entries: filtered, createdAt: createdAt, updatedAt: updatedAt)
    }

    func filtered(by source: ActivityEntry.DetectionSource) -> ActivityStream {
        let filtered = entries.filter { $0.source == source }
        return ActivityStream(id: id, monitoredUserId: monitoredUserId, entries: filtered, createdAt: createdAt, updatedAt: updatedAt)
    }

    func filtered(byApp app: String) -> ActivityStream {
        let filtered = entries.filter { $0.inferredApp == app }
        return ActivityStream(id: id, monitoredUserId: monitoredUserId, entries: filtered, createdAt: createdAt, updatedAt: updatedAt)
    }
}

// MARK: - Sorting

extension ActivityStream {

    enum SortOrder {
        case newestFirst
        case oldestFirst
        case domain
        case severity
    }

    func sorted(by order: SortOrder) -> ActivityStream {
        let sorted: [ActivityEntry]
        switch order {
        case .newestFirst:
            sorted = entries.sorted { $0.timestamp > $1.timestamp }
        case .oldestFirst:
            sorted = entries.sorted { $0.timestamp < $1.timestamp }
        case .domain:
            sorted = entries.sorted { $0.domain < $1.domain }
        case .severity:
            sorted = entries.sorted { lhs, rhs in
                if lhs.isFlagged != rhs.isFlagged { return lhs.isFlagged }
                return lhs.timestamp > rhs.timestamp
            }
        }
        return ActivityStream(id: id, monitoredUserId: monitoredUserId, entries: sorted, createdAt: createdAt, updatedAt: updatedAt)
    }
}

// MARK: - Statistics

extension ActivityStream {

    var count: Int { entries.count }

    var flaggedCount: Int { entries.filter { $0.isFlagged }.count }

    var uniqueDomains: Set<String> { Set(entries.map { $0.domain }) }

    var categoryBreakdown: [String: Int] {
        var breakdown: [String: Int] = [:]
        for entry in entries {
            if let category = entry.category {
                breakdown[category, default: 0] += 1
            }
        }
        return breakdown
    }

    var appBreakdown: [String: Int] {
        var breakdown: [String: Int] = [:]
        for entry in entries {
            breakdown[entry.inferredApp ?? "Unknown", default: 0] += 1
        }
        return breakdown
    }

    var sourceBreakdown: [ActivityEntry.DetectionSource: Int] {
        var breakdown: [ActivityEntry.DetectionSource: Int] = [:]
        for entry in entries {
            breakdown[entry.source, default: 0] += 1
        }
        return breakdown
    }

    var mostRecentTimestamp: Date? { entries.map { $0.timestamp }.max() }

    var oldestTimestamp: Date? { entries.map { $0.timestamp }.min() }
}

// MARK: - Firestore Helpers

extension ActivityStream {

    var asDictionary: [String: Any] {
        [
            "id": id,
            "monitoredUserId": monitoredUserId,
            "entryCount": entries.count,
            "flaggedCount": flaggedCount,
            "createdAt": createdAt,
            "updatedAt": updatedAt
        ]
        // Note: Individual entries are stored in a subcollection
    }

    static func from(_ data: [String: Any]) -> ActivityStream? {
        guard let id = data["id"] as? String,
              let monitoredUserId = data["monitoredUserId"] as? String else {
            return nil
        }

        let createdAt = data["createdAt"] as? Date ?? Date()
        let updatedAt = data["updatedAt"] as? Date ?? Date()

        return ActivityStream(
            id: id,
            monitoredUserId: monitoredUserId,
            entries: [], // Entries loaded separately from subcollection
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
