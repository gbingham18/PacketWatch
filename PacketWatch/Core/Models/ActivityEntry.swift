// Core/Models/ActivityEntry.swift
// Add to BOTH targets (main app + extension)

import Foundation

/// A single logged domain access event with optional enriched context.
struct ActivityEntry: BaseModel, Hashable {
    let id: String          // UUID string, generated on creation
    let dataOwnerId: String // Firebase Auth UID of the monitored user
    let domain: String
    let timestamp: Date
    let source: DetectionSource

    // Enriched fields (populated by validation)
    var category: String?
    var isFlagged: Bool
    var inferredApp: String?
    var appConfidence: String?
    var monitoringLevel: String?

    enum DetectionSource: String, Codable {
        case dns              // Network Extension - domain only
        case sni              // Network Extension - domain only
        case safariExtension  // Safari Extension - full URL, confirmed Safari
    }

    /// Basic initializer (used during packet processing)
    init(dataOwnerId: String, domain: String, source: DetectionSource) {
        self.id = UUID().uuidString
        self.dataOwnerId = dataOwnerId
        self.domain = domain
        self.timestamp = Date()
        self.source = source
        self.isFlagged = false
    }

    /// Full memberwise initializer (used for deserialization)
    init(
        id: String,
        dataOwnerId: String,
        domain: String,
        timestamp: Date,
        source: DetectionSource,
        category: String? = nil,
        isFlagged: Bool = false,
        inferredApp: String? = nil,
        appConfidence: String? = nil,
        monitoringLevel: String? = nil
    ) {
        self.id = id
        self.dataOwnerId = dataOwnerId
        self.domain = domain
        self.timestamp = timestamp
        self.source = source
        self.category = category
        self.isFlagged = isFlagged
        self.inferredApp = inferredApp
        self.appConfidence = appConfidence
        self.monitoringLevel = monitoringLevel
    }

    /// Full initializer with validation context
    init(dataOwnerId: String, domain: String, source: DetectionSource, validationResult: ValidationResult) {
        self.id = UUID().uuidString
        self.dataOwnerId = dataOwnerId
        self.domain = domain
        self.timestamp = Date()
        self.source = source
        self.category = validationResult.category.rawValue
        self.isFlagged = validationResult.isFlagged
        self.inferredApp = validationResult.context.inferredApp?.appName
        self.appConfidence = validationResult.context.inferredApp?.confidence.rawValue
        self.monitoringLevel = validationResult.context.monitoringLevel.rawValue
    }

    // MARK: - Hashable (only use id for equality)

    static func == (lhs: ActivityEntry, rhs: ActivityEntry) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
