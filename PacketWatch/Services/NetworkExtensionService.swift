// Services/PacketMonitorService.swift
//
// Protocol and implementation for packet monitoring.
// Manages the tunnel lifecycle and packet processing pipeline.

import Foundation
import Combine

// MARK: - Protocol

/// Defines packet monitoring operations.
protocol NetworkExtensionService {
    /// Current state of the monitor
    var statePublisher: AnyPublisher<MonitorState, Never> { get }
    
    /// Start monitoring packets
    func start() async throws
    
    /// Stop monitoring packets
    func stop() async
    
    /// Current state
    var currentState: MonitorState { get }
}

// MARK: - Monitor State

enum MonitorState: Equatable {
    case idle
    case starting
    case running
    case stopping
    case failed(String)
    
    var isRunning: Bool {
        self == .running
    }
    
    var canStart: Bool {
        self == .idle || isFailed
    }
    
    var canStop: Bool {
        self == .running
    }
    
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}

// MARK: - Errors

enum NetworkExtensionError: LocalizedError {
    case alreadyRunning
    case startFailed(String)
    case notRunning
    
    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "Monitor is already running"
        case .startFailed(let reason):
            return "Failed to start monitor: \(reason)"
        case .notRunning:
            return "Monitor is not running"
        }
    }
}

// MARK: - Implementation

final class DefaultNetworkExtensionService: NetworkExtensionService {
    
    static let shared = DefaultNetworkExtensionService()
    
    // MARK: - Dependencies

    private let storage: BaseModelStorageService
    private let validationProvider: DomainValidationProvider
    private let authService: AuthService

    // MARK: - State

    private let stateSubject = CurrentValueSubject<MonitorState, Never>(.idle)
    private var tunnel: SimulationPacketTunnelProvider?

    var statePublisher: AnyPublisher<MonitorState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    var currentState: MonitorState {
        stateSubject.value
    }

    // MARK: - Init

    init(
        storage: BaseModelStorageService = FirebaseBaseModelStorageService.shared,
        validationProvider: DomainValidationProvider = .shared,
        authService: AuthService = FirebaseAuthService.shared
    ) {
        self.storage = storage
        self.validationProvider = validationProvider
        self.authService = authService
    }
    
    // MARK: - PacketMonitorService
    
    func start() async throws {
        guard currentState.canStart else {
            throw NetworkExtensionError.alreadyRunning
        }
        
        stateSubject.send(.starting)
        
        // Inject our services into the tunnel
        let newTunnel = SimulationPacketTunnelProvider(
            storage: storage,
            validationProvider: validationProvider,
            authService: authService
        )
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            newTunnel.startTunnel(options: nil) { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    self.stateSubject.send(.failed(error.localizedDescription))
                    continuation.resume(throwing: NetworkExtensionError.startFailed(error.localizedDescription))
                } else {
                    self.tunnel = newTunnel
                    self.stateSubject.send(.running)
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    func stop() async {
        guard currentState.canStop else { return }
        
        stateSubject.send(.stopping)
        
        await withCheckedContinuation { continuation in
            tunnel?.stopTunnel {
                continuation.resume()
            }
        }
        
        tunnel = nil
        stateSubject.send(.idle)
    }
}

// MARK: - Mock for Testing

final class MockPacketMonitorService: NetworkExtensionService {
    
    private let stateSubject = CurrentValueSubject<MonitorState, Never>(.idle)
    
    var statePublisher: AnyPublisher<MonitorState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    var currentState: MonitorState {
        stateSubject.value
    }
    
    // Test hooks
    var shouldFailOnStart = false
    var startCallCount = 0
    var stopCallCount = 0
    
    func start() async throws {
        startCallCount += 1
        
        if shouldFailOnStart {
            stateSubject.send(.failed("Mock failure"))
            throw NetworkExtensionError.startFailed("Mock failure")
        }
        
        stateSubject.send(.starting)
        
        // Simulate async startup
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        stateSubject.send(.running)
    }
    
    func stop() async {
        stopCallCount += 1
        
        stateSubject.send(.stopping)
        
        // Simulate async shutdown
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        stateSubject.send(.idle)
    }
    
    // For testing state transitions
    func setState(_ state: MonitorState) {
        stateSubject.send(state)
    }
}
