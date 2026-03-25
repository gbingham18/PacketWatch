// Shared/DomainValidationProvider.swift
//
// Handles domain validation against blocklists, categorization,
// and produces enriched validation results with context.

import Foundation

/// Validates domains against blocklists and categorizes them.
class DomainValidationProvider {

    static let shared = DomainValidationProvider()

    private let browsingContext = BrowsingContext.shared

    // MARK: - Current Filter Settings

    /// The current user's filter settings. Set this on app launch after user logs in.
    private(set) var currentFilterSettings: FilterSettings?

    /// Load filter settings for the current user
    func loadSettings(_ settings: FilterSettings) {
        self.currentFilterSettings = settings
    }

    // MARK: - Built-in blocklists (for testing/fallback)
    // In production, these should be fetched from a remote database

    /// Map of categories to known domains
    private let knownDomainsByCategory: [ContentCategory: Set<String>] = [
        .explicit: ["explicitdomain.com", "explicitcdn.com"],
        .proxy: ["proxysite.com", "nordvpn.com"],
        .gambling: ["draftkings.com", "fanduel.com"],
        .socialMedia: ["facebook.com", "twitter.com", "instagram.com"],
        .streaming: ["netflix.com", "youtube.com", "twitch.tv"]
    ]
    
    // MARK: - Validation
    
    /// Validate a domain and return a full result with context
    func validate(_ domain: String) -> ValidationResult {
        browsingContext.recordDomain(domain)
        let normalizedDomain = normalizeDomain(domain)
        let category = categorize(normalizedDomain)

        // Use currentFilterSettings to determine if flagged, or use default behavior
        let isFlagged: Bool
        if let settings = currentFilterSettings {
            isFlagged = settings.shouldFlag(domain: normalizedDomain, category: category)
        } else {
            // Fallback: use category's default flagging behavior
            isFlagged = category.isFlaggedByDefault
        }

        // Get browsing context (inferred app, surrounding domains, etc.)
        let context = browsingContext.getContext(for: domain, at: Date())

        return ValidationResult(
            domain: domain,
            normalizedDomain: normalizedDomain,
            category: category,
            isFlagged: isFlagged,
            context: context,
            timestamp: Date()
        )
    }
    
    /// Categorize a domain
    func categorize(_ domain: String) -> ContentCategory {
        let normalized = normalizeDomain(domain)

        // Check against known domains by category
        for (category, domains) in knownDomainsByCategory {
            if matchesList(normalized, against: domains) {
                return category
            }
        }

        // Check if domain matches app fingerprints for social media
        for fingerprint in browsingContext.appFingerprints {
            if fingerprint.domains.contains(where: { normalized.contains($0) }) {
                return .socialMedia
            }
        }

        return .unknown
    }
    
    /// Check if any alternate browsers have been detected
    func getAlternateBrowserWarnings() -> [BrowserWarning] {
        return browsingContext.getDetectedBrowsers().map { browserName in
            BrowserWarning(
                browserName: browserName,
                message: "\(browserName) detected. Screen monitoring unavailable in this browser.",
                severity: .warning
            )
        }
    }
    
    /// Generate a summary report of flagged activity
    func generateReport(from entries: [ActivityEntry]) -> ValidationReport {
        var flaggedByCategory: [ContentCategory: [ValidationResult]] = [:]
        var appBreakdown: [String: Int] = [:]
        var safariCount = 0
        var nonSafariCount = 0
        
        for entry in entries {
            let result = validate(entry.domain)
            
            if result.isFlagged {
                flaggedByCategory[result.category, default: []].append(result)
            }
            
            if result.context.wasInSafari {
                safariCount += 1
            } else {
                nonSafariCount += 1
                if let app = result.context.inferredApp {
                    appBreakdown[app.appName, default: 0] += 1
                }
            }
        }
        
        return ValidationReport(
            totalDomains: entries.count,
            flaggedByCategory: flaggedByCategory,
            safariCount: safariCount,
            nonSafariCount: nonSafariCount,
            appBreakdown: appBreakdown,
            detectedBrowsers: browsingContext.getDetectedBrowsers(),
            generatedAt: Date()
        )
    }
    
    // MARK: - Private Helpers
    
    /// Normalize a domain for comparison
    /// Strips www., converts to lowercase, extracts root domain
    private func normalizeDomain(_ domain: String) -> String {
        var normalized = domain.lowercased()
        
        // Remove www.
        if normalized.hasPrefix("www.") {
            normalized = String(normalized.dropFirst(4))
        }
        
        // Remove trailing dot if present
        if normalized.hasSuffix(".") {
            normalized = String(normalized.dropLast())
        }
        
        return normalized
    }
    
    /// Check if a domain matches any entry in a blocklist
    /// Handles subdomains (cdn.explicitdomain.com matches explicitdomain.com)
    private func matchesList(_ domain: String, against list: Set<String>) -> Bool {
        // Direct match
        if list.contains(domain) {
            return true
        }
        
        // Subdomain match (check if domain ends with .blockedsite.com)
        for blocked in list {
            if domain.hasSuffix(".\(blocked)") {
                return true
            }
        }
        
        // Partial match for CDNs (domain contains blocked pattern)
        for blocked in list {
            if domain.contains(blocked) {
                return true
            }
        }
        
        return false
    }
}

// MARK: - Supporting Types

struct ValidationResult {
    let domain: String
    let normalizedDomain: String
    let category: ContentCategory
    let isFlagged: Bool
    let context: DomainContext
    let timestamp: Date
    
    /// Human-readable summary for reports
    var summary: String {
        var parts: [String] = []
        
        parts.append(domain)
        
        if isFlagged {
            parts.append("[\(category.rawValue)]")
        }
        
        if let app = context.inferredApp {
            parts.append("via \(app.appName) (\(app.confidence.rawValue) confidence)")
        } else if context.wasInSafari {
            parts.append("via Safari")
        } else {
            parts.append("via unknown app")
        }
        
        return parts.joined(separator: " ")
    }
}

struct BrowserWarning {
    let browserName: String
    let message: String
    let severity: Severity
    
    enum Severity {
        case info
        case warning
        case critical
    }
}

struct ValidationReport {
    let totalDomains: Int
    let flaggedByCategory: [ContentCategory: [ValidationResult]]
    let safariCount: Int
    let nonSafariCount: Int
    let appBreakdown: [String: Int]
    let detectedBrowsers: [String]
    let generatedAt: Date
    
    var totalFlagged: Int {
        flaggedByCategory.values.reduce(0) { $0 + $1.count }
    }
    
    var safariPercentage: Double {
        guard totalDomains > 0 else { return 0 }
        return Double(safariCount) / Double(totalDomains) * 100
    }
    
    var coverageWarning: String? {
        if safariPercentage < 50 {
            return "⚠️ Only \(Int(safariPercentage))% of traffic was in Safari where full monitoring is available."
        }
        return nil
    }
}
