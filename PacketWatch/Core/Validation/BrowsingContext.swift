// Shared/BrowsingContext.swift
//
// Tracks browsing context over time to infer which app is active
// and detect alternate browser usage.

import Foundation

/// Tracks recent network activity to infer browsing context.
///
/// This class maintains a sliding window of recent domains and uses
/// app fingerprinting to determine which app is likely active when
/// a flagged domain is detected.
class BrowsingContext: ObservableObject {
    
    static let shared = BrowsingContext()
    
    // MARK: - Configuration
    
    /// How long to keep domains in the recent activity window
    private let windowDuration: TimeInterval = 1800.0
    
    // MARK: - State
    
    /// Recent domain activity with timestamps
    private var recentActivity: [(domain: String, timestamp: Date)] = []
    
    /// Detected alternate browsers that have been active
    @Published private(set) var detectedBrowsers: Set<String> = []
    
    /// Domains observed in Safari (via extension, if available)
    /// In real implementation, Safari extension would populate this
    private var safariDomains: Set<String> = []
    
    /// Lock for thread-safe access
    private let lock = NSLock()
    
    // MARK: - Fingerprint References
    
    /// App fingerprints from WellKnownAppFingerprints
    var appFingerprints: [AppFingerprint] {
        WellKnownAppFingerprints.all
    }
    
    /// Browser fingerprints from WellKnownBrowserFingerprints
    var browserFingerprints: [BrowserFingerprint] {
        WellKnownBrowserFingerprints.all
    }
    
    // MARK: - Public Interface
    
    /// Record a domain access. Call this for every extracted domain.
    func recordDomain(_ domain: String) {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        
        // Add to recent activity
        recentActivity.append((domain: domain, timestamp: now))
        
        // Prune old entries
        recentActivity = recentActivity.filter {
            now.timeIntervalSince($0.timestamp) < windowDuration
        }
        
        // Check for browser activity
        checkForBrowserActivity(domain)
    }
    
    /// Mark a domain as having been seen in Safari (called by Safari extension)
    func recordSafariDomain(_ domain: String) {
        lock.lock()
        defer { lock.unlock() }
        safariDomains.insert(domain)
    }
    
    /// Infer which app was active when a specific domain was accessed.
    /// Works BACKWARDS from the target domain to find the most recent
    /// app or browser fingerprint match.
    ///
    /// This answers: "What app likely loaded this domain?"
    func inferActiveApp(for targetDomain: String, at timestamp: Date) -> AppInference? {
        lock.lock()
        defer { lock.unlock() }
        
        // Get activity BEFORE this domain access, sorted newest first
        let precedingActivity = recentActivity
            .filter { $0.timestamp < timestamp }
            .sorted { $0.timestamp > $1.timestamp }  // Most recent first
        
        return inferAppByLookback(from: precedingActivity)
    }
    
    /// Get context for a specific domain at a specific time.
    /// Looks BACKWARDS in traffic to determine likely source app.
    func getContext(for domain: String, at timestamp: Date) -> DomainContext {
        lock.lock()
        defer { lock.unlock() }
        
        guard !safariDomains.contains(domain) else {
            return DomainContext(
                domain: domain,
                timestamp: timestamp,
                inferredApp: nil,
                wasInSafari: true,
                monitoringLevel: MonitoringLevel.full,
                surroundingDomains: []
            )
        }
        
        let precedingActivity = recentActivity.filter { $0.timestamp < timestamp }
        
        let appInference = inferAppByLookback(from: precedingActivity)
        
        // Get surrounding domains for context (still useful for reporting)
        let windowStart = timestamp.addingTimeInterval(-windowDuration)
        let surroundingDomains = recentActivity
            .filter { $0.timestamp >= windowStart && $0.timestamp <= timestamp }
            .map { $0.domain }
        
        // Determine monitoring level
        let monitoringLevel: MonitoringLevel
        if appInference != nil {
            monitoringLevel = .networkOnly
        } else {
            monitoringLevel = .unknown
        }
        
        return DomainContext(
            domain: domain,
            timestamp: timestamp,
            inferredApp: appInference,
            wasInSafari: false,
            monitoringLevel: monitoringLevel,
            surroundingDomains: surroundingDomains
        )
    }
    
    /// Check if a domain was accessed outside of Safari
    func wasAccessedOutsideSafari(_ domain: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !safariDomains.contains(domain)
    }
    
    /// Get all detected alternate browsers
    func getDetectedBrowsers() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(detectedBrowsers).sorted()
    }
    
    /// Clear all tracked state (e.g., for testing or reset)
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        recentActivity = []
        detectedBrowsers = []
        safariDomains = []
    }
    
    // MARK: - Private Helpers
    
    /// Work backwards through activity to find the most recent app/browser fingerprint.
    ///
    /// Algorithm:
    /// 1. Walk backwards through domains (most recent first)
    /// 2. For each domain, check if it matches an app or browser fingerprint
    /// 3. Return the FIRST match found (most recent app context)
    /// 4. Track consecutive matches to build confidence
    ///
    /// This correctly answers "what app was being used right before this request?"
    private func inferAppByLookback(
        from activity: [(domain: String, timestamp: Date)]
    ) -> AppInference? {
        for (index, entry) in activity.reversed().enumerated() {
            let domain = entry.domain
            
            if let fingerprint = WellKnownAppFingerprints.match(domain: domain) {
                return AppInference(
                    appName: fingerprint.name,
                    confidence: confidenceFor(index: index),
                    matchedDomains: 1,
                    icon: fingerprint.icon
                )
            }
            
            if let browser = WellKnownBrowserFingerprints.match(domain: domain) {
                return AppInference(
                    appName: browser.name,
                    confidence: confidenceFor(index: index),
                    matchedDomains: 1,
                    icon: browser.icon
                )
            }
            
            if index >= 10 {
                break
            }
        }
        
        return nil
    }

    private func confidenceFor(index: Int) -> AppInference.Confidence {
        switch index {
            case 0...1: return .high
            case 2...4: return .medium
            default: return .low
        }
    }
    
    private func checkForBrowserActivity(_ domain: String) {
        for browser in browserFingerprints {
            if browser.domains.contains(where: { domain.contains($0) }) {
                if !detectedBrowsers.contains(browser.name) {
                    detectedBrowsers.insert(browser.name)
                    print("[BrowsingContext] Alternate browser detected: \(browser.name)")
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct AppInference: Equatable {
    let appName: String
    let confidence: Confidence
    let matchedDomains: Int
    let icon: String
    
    enum Confidence: String, Codable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
    }
}

enum MonitoringLevel: String, Codable {
    case full = "Full"           // Safari with extension
    case networkOnly = "Network" // Can see domains but not screen
    case unknown = "Unknown"     // Can't determine source
}

struct DomainContext {
    let domain: String
    let timestamp: Date
    let inferredApp: AppInference?
    let wasInSafari: Bool
    let monitoringLevel: MonitoringLevel
    let surroundingDomains: [String]
}
