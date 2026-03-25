// Core/Models/FilterSettings.swift
//
// User-configurable filter settings managed by the filter guardian.
// Contains ContentCategory and SensitivityLevel enums used throughout the app.

import Foundation

// MARK: - Content Category

/// Categories of content that can be monitored and flagged.
enum ContentCategory: String, Codable, CaseIterable {
    case explicit           // Pornography
    case suggestive         // Lingerie, swimwear, risqué content
    case violence           // Gore, graphic violence
    case gambling           // Betting, casinos
    case drugs              // Drug-related content
    case dating             // Dating apps/sites
    case proxy              // VPNs, proxies, anonymizers
    case socialMedia        // Social media platforms
    case streaming          // Video streaming services
    case unknown            // Uncategorized

    var displayName: String {
        switch self {
        case .explicit: return "Explicit Content"
        case .suggestive: return "Suggestive Content"
        case .violence: return "Violence & Gore"
        case .gambling: return "Gambling"
        case .drugs: return "Drugs & Alcohol"
        case .dating: return "Dating Sites"
        case .proxy: return "VPNs & Proxies"
        case .socialMedia: return "Social Media"
        case .streaming: return "Streaming Services"
        case .unknown: return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .explicit: return "exclamationmark.triangle.fill"
        case .suggestive: return "eye.trianglebadge.exclamationmark"
        case .violence: return "flame.fill"
        case .gambling: return "dice.fill"
        case .drugs: return "pills.fill"
        case .dating: return "heart.fill"
        case .proxy: return "network.badge.shield.half.filled"
        case .socialMedia: return "person.2.fill"
        case .streaming: return "play.tv.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    /// Categories that are flagged by default at moderate sensitivity
    var isFlaggedByDefault: Bool {
        switch self {
        case .explicit, .suggestive, .violence, .gambling, .drugs, .proxy:
            return true
        default:
            return false
        }
    }

    /// Categories that are always flagged regardless of settings
    var isAlwaysFlagged: Bool {
        self == .explicit
    }

    /// Default set of blocked categories
    static var defaultBlocked: Set<ContentCategory> {
        Set(ContentCategory.allCases.filter { $0.isFlaggedByDefault })
    }
}

// MARK: - Sensitivity Level

/// Preset sensitivity levels that determine which categories are flagged.
enum SensitivityLevel: String, Codable, CaseIterable {
    case low        // Only explicit content
    case moderate   // Explicit + suggestive + violence
    case high       // Above + gambling, drugs, dating, proxy
    case strict     // Everything except unknown

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .strict: return "Strict"
        }
    }

    var description: String {
        switch self {
        case .low: return "Only explicit content"
        case .moderate: return "Explicit, suggestive, and violent content"
        case .high: return "Includes gambling, drugs, dating, and proxies"
        case .strict: return "Flag everything suspicious"
        }
    }

    /// Categories included at this sensitivity level
    var includedCategories: Set<ContentCategory> {
        switch self {
        case .low:
            return [.explicit]
        case .moderate:
            return [.explicit, .suggestive, .violence]
        case .high:
            return [.explicit, .suggestive, .violence, .gambling, .drugs, .dating, .proxy]
        case .strict:
            return Set(ContentCategory.allCases.filter { $0 != .unknown })
        }
    }
}

// MARK: - Filter Settings

/// User-configurable filter settings managed by the filter guardian.
struct FilterSettings: BaseModel {
    let id: String              // UUID string
    let dataOwnerId: String     // Firebase Auth UID of the monitored user
    var lastModifiedBy: String  // Firebase Auth UID of the guardian who made last change
    var lastModifiedAt: Date

    // Sensitivity
    var sensitivityLevel: SensitivityLevel

    // Built-in category toggles
    var blockedCategories: Set<ContentCategory>

    // Custom lists
    var customBlockedDomains: [String]
    var customAllowedDomains: [String]

    // Monitoring options
    var monitorAlternateBrowsers: Bool
    var alertOnAlternateBrowser: Bool
    var sampleUnflaggedActivity: Bool
    var samplePercentage: Int

    // Notifications
    var instantAlertOnFlagged: Bool
    var dailyReportEnabled: Bool
    var weeklyReportEnabled: Bool

    init(
        id: String = UUID().uuidString,
        dataOwnerId: String,
        lastModifiedBy: String,
        lastModifiedAt: Date = Date(),
        sensitivityLevel: SensitivityLevel = .moderate,
        blockedCategories: Set<ContentCategory>? = nil,
        customBlockedDomains: [String] = [],
        customAllowedDomains: [String] = [],
        monitorAlternateBrowsers: Bool = true,
        alertOnAlternateBrowser: Bool = true,
        sampleUnflaggedActivity: Bool = true,
        samplePercentage: Int = 5,
        instantAlertOnFlagged: Bool = false,
        dailyReportEnabled: Bool = false,
        weeklyReportEnabled: Bool = true
    ) {
        self.id = id
        self.dataOwnerId = dataOwnerId
        self.lastModifiedBy = lastModifiedBy
        self.lastModifiedAt = lastModifiedAt
        self.sensitivityLevel = sensitivityLevel
        self.blockedCategories = blockedCategories ?? sensitivityLevel.includedCategories
        self.customBlockedDomains = customBlockedDomains
        self.customAllowedDomains = customAllowedDomains
        self.monitorAlternateBrowsers = monitorAlternateBrowsers
        self.alertOnAlternateBrowser = alertOnAlternateBrowser
        self.sampleUnflaggedActivity = sampleUnflaggedActivity
        self.samplePercentage = samplePercentage
        self.instantAlertOnFlagged = instantAlertOnFlagged
        self.dailyReportEnabled = dailyReportEnabled
        self.weeklyReportEnabled = weeklyReportEnabled
    }
}

// MARK: - Convenience Methods

extension FilterSettings {

    func shouldFlag(domain: String, category: ContentCategory?) -> Bool {
        let normalizedDomain = domain.lowercased()

        if customAllowedDomains.contains(where: { normalizedDomain.contains($0.lowercased()) }) {
            return false
        }
        if customBlockedDomains.contains(where: { normalizedDomain.contains($0.lowercased()) }) {
            return true
        }
        if let category = category, category.isAlwaysFlagged {
            return true
        }
        if let category = category, blockedCategories.contains(category) {
            return true
        }
        return false
    }

    func shouldSample() -> Bool {
        guard sampleUnflaggedActivity else { return false }
        return Int.random(in: 1...100) <= samplePercentage
    }

    mutating func applySensitivity(_ level: SensitivityLevel) {
        self.sensitivityLevel = level
        self.blockedCategories = level.includedCategories
    }

    static func defaults(for userId: String, guardianId: String) -> FilterSettings {
        FilterSettings(dataOwnerId: userId, lastModifiedBy: guardianId)
    }
}

// MARK: - Firestore Helpers

extension FilterSettings {

    var asDictionary: [String: Any] {
        [
            "id": id,
            "dataOwnerId": dataOwnerId,
            "lastModifiedBy": lastModifiedBy,
            "lastModifiedAt": lastModifiedAt,
            "sensitivityLevel": sensitivityLevel.rawValue,
            "blockedCategories": blockedCategories.map { $0.rawValue },
            "customBlockedDomains": customBlockedDomains,
            "customAllowedDomains": customAllowedDomains,
            "monitorAlternateBrowsers": monitorAlternateBrowsers,
            "alertOnAlternateBrowser": alertOnAlternateBrowser,
            "sampleUnflaggedActivity": sampleUnflaggedActivity,
            "samplePercentage": samplePercentage,
            "instantAlertOnFlagged": instantAlertOnFlagged,
            "dailyReportEnabled": dailyReportEnabled,
            "weeklyReportEnabled": weeklyReportEnabled
        ]
    }

    static func from(_ data: [String: Any]) -> FilterSettings? {
        guard let id = data["id"] as? String,
              let dataOwnerId = data["dataOwnerId"] as? String,
              let lastModifiedBy = data["lastModifiedBy"] as? String,
              let sensitivityRaw = data["sensitivityLevel"] as? String,
              let sensitivityLevel = SensitivityLevel(rawValue: sensitivityRaw) else {
            return nil
        }

        let lastModifiedAt = data["lastModifiedAt"] as? Date ?? Date()
        let categoryStrings = data["blockedCategories"] as? [String] ?? []
        let blockedCategories = Set(categoryStrings.compactMap { ContentCategory(rawValue: $0) })

        return FilterSettings(
            id: id,
            dataOwnerId: dataOwnerId,
            lastModifiedBy: lastModifiedBy,
            lastModifiedAt: lastModifiedAt,
            sensitivityLevel: sensitivityLevel,
            blockedCategories: blockedCategories,
            customBlockedDomains: data["customBlockedDomains"] as? [String] ?? [],
            customAllowedDomains: data["customAllowedDomains"] as? [String] ?? [],
            monitorAlternateBrowsers: data["monitorAlternateBrowsers"] as? Bool ?? true,
            alertOnAlternateBrowser: data["alertOnAlternateBrowser"] as? Bool ?? true,
            sampleUnflaggedActivity: data["sampleUnflaggedActivity"] as? Bool ?? true,
            samplePercentage: data["samplePercentage"] as? Int ?? 5,
            instantAlertOnFlagged: data["instantAlertOnFlagged"] as? Bool ?? false,
            dailyReportEnabled: data["dailyReportEnabled"] as? Bool ?? false,
            weeklyReportEnabled: data["weeklyReportEnabled"] as? Bool ?? true
        )
    }
}
