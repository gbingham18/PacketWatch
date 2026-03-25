// Simulation/PacketGenerator.swift
//
// Generates realistic network traffic by cycling through browsing sessions.
//
// Each batch represents a complete browsing session:
//   - DNS queries and responses for each domain
//   - TLS ClientHello packets with SNI
//   - Noise packets sprinkled in

import Foundation

class PacketGenerator {
    
    // MARK: - State
    
    private let sessions: [BrowsingSession]
    private var currentSessionIndex = 0
    private var batchCount = 0
    
    // MARK: - Init
    
    init(sessions: [BrowsingSession] = BrowsingSessions.all) {
        self.sessions = sessions
    }
    
    // MARK: - Generation
    
    /// Generate the next batch of packets for one browsing session.
    func nextBatch() -> [Packet] {
        guard !sessions.isEmpty else {
            print("Next Batch Early Return")
            return [] }
        
        let session = sessions[currentSessionIndex]
        var packets: [Packet] = []
        
        print("[PacketGen] Session: \(session.name) [\(session.type)]")
        
        // Generate packets for each domain in the session
        for domain in session.domains {
            packets.append(PacketBuilder.buildDNSQuery(for: domain))
            packets.append(PacketBuilder.buildDNSResponse(for: domain))
            
            // 90% chance of TLS handshake (some might be cached)
            if Int.random(in: 0..<10) < 9 {
                packets.append(PacketBuilder.buildTLSClientHello(sni: domain))
            }
        }
        
        // Add noise packets at random positions
        insertNoise(into: &packets)
        
        // Advance to next session
        currentSessionIndex = (currentSessionIndex + 1) % sessions.count
        batchCount += 1
        
        return packets
    }
    
    /// Reset the generator to start from the first session.
    func reset() {
        currentSessionIndex = 0
        batchCount = 0
    }
    
    // MARK: - Private
    
    private func insertNoise(into packets: inout [Packet]) {
        var noise: [Packet] = []
        
        if Bool.random() {
            noise.append(PacketBuilder.buildEmptyTCPTo443())
        }
        
        if Bool.random() {
            noise.append(PacketBuilder.buildUDPNonDNS())
        }
        
        // Occasional malformed packet
        if batchCount % 5 == 0 {
            noise.append(PacketBuilder.buildMalformedPacket())
        }
        
        for noisePacket in noise {
            let position = Int.random(in: 0...packets.count)
            packets.insert(noisePacket, at: position)
        }
    }
    
    // MARK: - Convenience
    
    /// Generate a single DNS query packet.
    static func singleDNS(_ domain: String) -> Packet {
        PacketBuilder.buildDNSQuery(for: domain)
    }
    
    /// Generate a single TLS ClientHello packet.
    static func singleTLS(_ sni: String) -> Packet {
        PacketBuilder.buildTLSClientHello(sni: sni)
    }
}
