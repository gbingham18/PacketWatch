// Features/Dashboard/DashboardViewModel.swift
//
// ViewModel for the Dashboard feature.
// Handles tunnel control, domain filtering, and state management.
// The View observes this and renders accordingly.

import Foundation
import Combine

/// Represents the current state of the packet monitoring tunnel
enum TunnelState: Equatable {
    case stopped
    case starting
    case running
    case stopping
    
    var isRunning: Bool {
        self == .running
    }
    
    var canToggle: Bool {
        self == .stopped || self == .running
    }
}

// MARK: - ViewModel

@MainActor
final class DashboardViewModel: ObservableObject {
    
    // MARK: - Published State

    @Published private(set) var tunnelState: TunnelState = .stopped
    @Published private(set) var entries: [ActivityEntry] = []
    @Published private(set) var detectedBrowsers: Set<String> = []
    @Published private(set) var isLoading = false
    
    // MARK: - Computed Properties
    
    var hasDetectedBrowsers: Bool {
        !detectedBrowsers.isEmpty
    }
    
    var detectedBrowsersList: String {
        detectedBrowsers.sorted().joined(separator: ", ")
    }
    
    // MARK: - Dependencies

    private let browsingContext: BrowsingContext
    private let authService: AuthService
    private let activityStreamService: ActivityStreamService
    private let networkExtensionService: NetworkExtensionService
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        browsingContext: BrowsingContext = .shared,
        authService: AuthService = FirebaseAuthService.shared,
        activityStreamService: ActivityStreamService = FirebaseActivityStreamService.shared,
        networkExtensionService: NetworkExtensionService = DefaultNetworkExtensionService.shared
    ) {
        self.browsingContext = browsingContext
        self.authService = authService
        self.activityStreamService = activityStreamService
        self.networkExtensionService = networkExtensionService
        setupBindings()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: - Setup

    private func setupBindings() {
        browsingContext.$detectedBrowsers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] browsers in
                self?.detectedBrowsers = browsers
            }
            .store(in: &cancellables)

        networkExtensionService.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .idle:         self?.tunnelState = .stopped
                case .starting:     self?.tunnelState = .starting
                case .running:      self?.tunnelState = .running
                case .stopping:     self?.tunnelState = .stopping
                case .failed:       self?.tunnelState = .stopped
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Actions
    
    /// Start observing for entry updates
    func startObserving() {
        refreshEntries()
        
        // Poll for updates every second
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshEntries()
            }
        }
    }
    
    /// Stop observing for entry updates
    func stopObserving() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    /// Toggle the tunnel on/off
    func toggleTunnel() {
        guard tunnelState.canToggle else { return }
        
        if tunnelState == .running {
            stopTunnel()
        } else {
            startTunnel()
        }
    }
    
    /// Clear all logged entries and reset state
    func clearAll() {
        browsingContext.reset()
        entries = []
    }
    
    /// Run the parser test suite
    func runParserTests() {
        ParserTests.runAll()
    }
    
    // MARK: - Private Methods

    private func startTunnel() {
        Task {
            do {
                try await networkExtensionService.start()
            } catch {
                print("[DashboardVM] Tunnel start error: \(error)")
            }
        }
    }

    private func stopTunnel() {
        Task {
            await networkExtensionService.stop()
        }
    }
    
    func refreshEntries() {
        guard let accountabilityNetworkId = authService.currentUser?.accountabilityNetworkId else {
            entries = []
            return
        }
        
        print("Dashboard Accountability Network Id: " + accountabilityNetworkId)
        
        Task {
            isLoading = true

            do {
                let stream = try await activityStreamService.fetchStream(forNetwork: accountabilityNetworkId, limit: 500)
                entries = stream.entries.sorted { $0.timestamp > $1.timestamp }
            } catch {
                print("Error loading activity: \(error)")
            }

            isLoading = false
        }
    }

    // MARK: - Load from Firebase

    func loadActivity(for accountabilityNetworkId: String?) async {
        guard let accountabilityNetworkId = accountabilityNetworkId else { return }

        isLoading = true

        do {
            let stream = try await activityStreamService.fetchStream(forNetwork: accountabilityNetworkId, limit: 500)
            entries = stream.entries.sorted { $0.timestamp > $1.timestamp }
        } catch {
            print("Error loading activity: \(error)")
        }

        isLoading = false
    }
}
