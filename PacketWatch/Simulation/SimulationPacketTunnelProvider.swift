// Simulation/PacketTunnelProvider.swift
//
// A stand-in for NEPacketTunnelProvider that you can run in the main app
// target (or unit tests) without any entitlements or a physical device.
//
// It mimics the real API surface:
//   - startTunnel / stopTunnel lifecycle
//   - A mock packetFlow that delivers synthetic packets
//   - The same processPacket() pipeline as the real provider
//
// Usage:
//   let mock = MockPacketTunnelProvider()
//   mock.startTunnel(options: nil) { error in ... }
//   // Packets start flowing automatically from the generator

import Foundation

// MARK: - Simulation NEPacket

/// Mimics NEPacket — just raw bytes with a protocol family.
struct Packet {
    let data: Data
    let protocolFamily: sa_family_t  // AF_INET = 2 for IPv4
    
    init(_ bytes: [UInt8]) {
        self.data = Data(bytes)
        self.protocolFamily = sa_family_t(AF_INET)
    }
}

/// Drop-in replacement for PacketTunnelProvider during development.
///
/// The processing pipeline (processPacket → processUDP/processTCP →
/// DNSParser/TLSParser → DomainValidationProvider → BaseModelStorageService) is identical
/// to the real provider. Only the packet source is different.
class SimulationPacketTunnelProvider {

    // MARK: - Dependencies

    private let packetFlow = PacketFlow()
    private let storage: BaseModelStorageService
    private let validationProvider: DomainValidationProvider
    private let authService: AuthService
    private let browsingContext: BrowsingContext

    // MARK: - State

    private(set) var isRunning = false

    // MARK: - Init

    init(
        storage: BaseModelStorageService = UserDefaultsBaseModelStorageService.shared,
        validationProvider: DomainValidationProvider = .shared,
        authService: AuthService = FirebaseAuthService.shared,
        browsingContext: BrowsingContext = BrowsingContext.shared
    ) {
        self.storage = storage
        self.validationProvider = validationProvider
        self.authService = authService
        self.browsingContext = browsingContext
    }
    
    // MARK: - Tunnel Lifecycle
    
    /// Mimics NEPacketTunnelProvider.startTunnel()
    func startTunnel(
        options: [String: Any]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        print("Starting tunnel...")
        isRunning = true
        
        browsingContext.reset()
        
        completionHandler(nil)
        readPackets()
    }
    
    /// Mimics NEPacketTunnelProvider.stopTunnel()
    func stopTunnel(completionHandler: @escaping () -> Void) {
        print("Stopping tunnel...")
        isRunning = false
        packetFlow.stop()
        
        completionHandler()
    }
    
    // MARK: - Packet Reading
    
    private func readPackets() {
        print("Read Packets...")
        packetFlow.startGenerating(interval: 0.5) { [weak self] packets in
            guard let self = self else {
                print("Early return")
                return }
            
            print("Handler")
            
            for packet in packets {
                self.processPacket(packet)
            }
            
            // Pass-through (no-op in mock)
            self.packetFlow.writePacketObjects(packets)
        }
    }
    
    // MARK: - Packet Processing
    
    private func processPacket(_ packet: Packet) {
        print("Processing Packet...")
        let bytes = [UInt8](packet.data)
        
        guard bytes.count >= 20 else { return }
        
        let version = bytes[0] >> 4
        guard version == 4 else { return }
        
        let ihl = Int(bytes[0] & 0x0F) * 4
        guard ihl >= 20, bytes.count > ihl else { return }
        
        let proto = bytes[9]
        
        switch proto {
        case 17:
            processUDP(bytes: bytes, ipHeaderLength: ihl)
        case 6:
            processTCP(bytes: bytes, ipHeaderLength: ihl)
        default:
            break
        }
    }
    
    private func processUDP(bytes: [UInt8], ipHeaderLength: Int) {
        print("UDP")
        let udpStart = ipHeaderLength
        guard bytes.count >= udpStart + 8 else { return }
        
        let dstPort = UInt16(bytes[udpStart + 2]) << 8 | UInt16(bytes[udpStart + 3])
        guard dstPort == 53 else { return }
        
        let payloadStart = udpStart + 8
        let payload = Data(bytes[payloadStart...])
        
        if let domain = DNSParser.extractDomain(from: payload) {
            processDomain(domain, source: .dns)
        }
    }
    
    private func processTCP(bytes: [UInt8], ipHeaderLength: Int) {
        print("TCP")
        let tcpStart = ipHeaderLength
        guard bytes.count >= tcpStart + 20 else { return }
        
        let dstPort = UInt16(bytes[tcpStart + 2]) << 8 | UInt16(bytes[tcpStart + 3])
        guard dstPort == 443 else { return }
        
        let dataOffset = Int(bytes[tcpStart + 12] >> 4) * 4
        let payloadStart = tcpStart + dataOffset
        
        guard payloadStart < bytes.count else { return }
        let payload = Data(bytes[payloadStart...])
        
        if let sni = TLSParser.extractSNI(from: payload) {
            processDomain(sni, source: .sni)
        }
    }
    
    /// Process an extracted domain through validation and logging
    private func processDomain(_ domain: String, source: ActivityEntry.DetectionSource) {
        guard let user = authService.currentUser else {
            print("Warning: No user logged in, skipping activity logging")
            return
        }

        guard let networkId = user.accountabilityNetworkId else {
            print("Warning: No accountabilityNetworkId on user, skipping activity logging")
            return
        }
        
        print("User: " + user.id)
        print("Accountability Network Id: " + networkId)
        
        let result = validationProvider.validate(domain)
        
        let resultString = String(result.isFlagged)
        
        print("Validation result: " + resultString)
        
        // Only store flagged domains
        if result.isFlagged {
            let entry = ActivityEntry(
                dataOwnerId: user.id,
                domain: domain,
                source: source,
                validationResult: result
            )

            Task {
                try? await storage.save(
                    entry,
                    toSubcollection: "entries",
                    ofDocument: networkId,
                    inCollection: "activityStreams"
                )
            }
        }
    }
}
