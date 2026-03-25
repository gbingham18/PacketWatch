// Services/SafariExtensionService.swift
//
// Reads domain data reported by the Safari Extension via App Groups.
// Provides confirmed Safari browsing activity to the main app.

import Foundation
import Combine

// MARK: - Protocol

protocol SafariExtensionService {
    /// Publisher for Safari navigation events
    var navigationsPublisher: AnyPublisher<SafariNavigation, Never> { get }
    
    /// Read all stored Safari navigations
    func readAll() -> [SafariNavigation]
    
    /// Clear stored navigations
    func clear()
    
    /// Start polling for new navigations
    func startPolling()
    
    /// Stop polling
    func stopPolling()
}

// MARK: - Safari Navigation

struct SafariNavigation: Identifiable, Codable {
    let id: UUID
    let domain: String
    let type: NavigationType
    let timestamp: Date
    
    enum NavigationType: String, Codable {
        case navigation     // Page load completed
        case tabActivated   // User switched to tab
    }
    
    init(domain: String, type: NavigationType, timestamp: Date) {
        self.id = UUID()
        self.domain = domain
        self.type = type
        self.timestamp = timestamp
    }
}

// MARK: - Implementation

final class DefaultSafariExtensionService: SafariExtensionService {

    static let shared = DefaultSafariExtensionService()

    // MARK: - Configuration

    private let appGroupID = "group.com.bingham.packetwatch"
    private let storageKey = "safariDomains"
    private let pollingInterval: TimeInterval = 1.0

    // MARK: - Dependencies

    private let validationProvider: DomainValidationProvider
    private let storage: BaseModelStorageService
    private let authService: AuthService

    // MARK: - State

    private let navigationsSubject = PassthroughSubject<SafariNavigation, Never>()
    private var pollTimer: Timer?
    private var lastReadTimestamp: Double = 0

    var navigationsPublisher: AnyPublisher<SafariNavigation, Never> {
        navigationsSubject.eraseToAnyPublisher()
    }

    // MARK: - Init

    init(
        validationProvider: DomainValidationProvider = .shared,
        storage: BaseModelStorageService = UserDefaultsBaseModelStorageService.shared,
        authService: AuthService = FirebaseAuthService.shared
    ) {
        self.validationProvider = validationProvider
        self.storage = storage
        self.authService = authService
    }
    
    // MARK: - SafariExtensionService
    
    func readAll() -> [SafariNavigation] {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let entries = defaults.array(forKey: storageKey) as? [[String: Any]] else {
            return []
        }
        
        return entries.compactMap { parseEntry($0) }
    }
    
    func clear() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.removeObject(forKey: storageKey)
        lastReadTimestamp = 0
    }
    
    func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            self?.checkForNewNavigations()
        }
    }
    
    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    // MARK: - Private
    
    private func checkForNewNavigations() {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let entries = defaults.array(forKey: storageKey) as? [[String: Any]] else {
            return
        }

        // Find entries newer than last read
        for entry in entries {
            guard let timestamp = entry["timestamp"] as? Double,
                  timestamp > lastReadTimestamp,
                  let navigation = parseEntry(entry) else {
                continue
            }

            lastReadTimestamp = timestamp
            navigationsSubject.send(navigation)

            // Validate and store flagged domains
            processDomain(navigation.domain, source: .safariExtension)
        }
    }

    private func processDomain(_ domain: String, source: ActivityEntry.DetectionSource) {
        guard let userId = authService.currentUser?.id else {
            print("Warning: No user logged in, skipping Safari activity logging")
            return
        }

        let result = validationProvider.validate(domain)

        // Only store flagged domains
        if result.isFlagged {
            let entry = ActivityEntry(
                dataOwnerId: userId,
                domain: domain,
                source: source,
                validationResult: result
            )

            Task {
                try? await storage.save(entry)
            }
        }
    }
    
    private func parseEntry(_ entry: [String: Any]) -> SafariNavigation? {
        guard let domain = entry["domain"] as? String,
              let timestamp = entry["timestamp"] as? Double else {
            return nil
        }
        
        let typeString = entry["type"] as? String ?? "navigation"
        let type = SafariNavigation.NavigationType(rawValue: typeString) ?? .navigation
        
        return SafariNavigation(
            domain: domain,
            type: type,
            timestamp: Date(timeIntervalSince1970: timestamp / 1000)
        )
    }
}

// MARK: - Mock for Testing

final class MockSafariExtensionService: SafariExtensionService {
    
    private let navigationsSubject = PassthroughSubject<SafariNavigation, Never>()
    
    var navigationsPublisher: AnyPublisher<SafariNavigation, Never> {
        navigationsSubject.eraseToAnyPublisher()
    }
    
    private var storedNavigations: [SafariNavigation] = []
    
    func readAll() -> [SafariNavigation] {
        storedNavigations
    }
    
    func clear() {
        storedNavigations = []
    }
    
    func startPolling() { }
    func stopPolling() { }
    
    // Test helpers
    func simulateNavigation(domain: String) {
        let navigation = SafariNavigation(
            domain: domain,
            type: .navigation,
            timestamp: Date()
        )
        storedNavigations.append(navigation)
        navigationsSubject.send(navigation)
    }
}
