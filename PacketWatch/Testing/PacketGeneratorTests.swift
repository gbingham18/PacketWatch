// Testing/PacketGeneratorTests.swift
//
// Test scenarios for packet generation.
// These generate specific packet sequences to test particular features.

import Foundation

enum PacketGeneratorTests {
    
    // MARK: - Explicit Content Tests
    
    /// Generate a sequence that tests explicit content embedded in social media.
    /// The explicit CDN should be attributed to the Twitter app context.
    static func explicitEmbeddedInTwitter() -> [Packet] {
        var packets: [Packet] = []
        
        // Twitter app traffic (establishes context)
        packets.append(PacketBuilder.buildDNSQuery(for: "api.twitter.com"))
        packets.append(PacketBuilder.buildTLSClientHello(sni: "api.twitter.com"))
        packets.append(PacketBuilder.buildDNSQuery(for: "pbs.twimg.com"))
        packets.append(PacketBuilder.buildTLSClientHello(sni: "pbs.twimg.com"))
        
        // Explicit CDN loaded as embedded content
        packets.append(PacketBuilder.buildDNSQuery(for: "explicitcdn.com"))
        packets.append(PacketBuilder.buildTLSClientHello(sni: "explicitcdn.com"))
        
        // More Twitter traffic
        packets.append(PacketBuilder.buildDNSQuery(for: "video.twimg.com"))
        packets.append(PacketBuilder.buildTLSClientHello(sni: "video.twimg.com"))
        
        return packets
    }
    
    /// Generate a sequence showing direct explicit site access.
    /// No social media context — user navigated directly.
    static func directExplicitAccess() -> [Packet] {
        var packets: [Packet] = []
        
        packets.append(PacketBuilder.buildDNSQuery(for: "explicitdomain.com"))
        packets.append(PacketBuilder.buildTLSClientHello(sni: "explicitdomain.com"))
        packets.append(PacketBuilder.buildDNSQuery(for: "explicitcdn.com"))
        packets.append(PacketBuilder.buildTLSClientHello(sni: "explicitcdn.com"))
        packets.append(PacketBuilder.buildDNSQuery(for: "di.explicitcdn.com"))
        packets.append(PacketBuilder.buildTLSClientHello(sni: "di.explicitcdn.com"))
        
        return packets
    }
    
    // MARK: - Browser Detection Tests
    
    /// Generate a sequence that triggers Chrome detection.
    static func chromeActivity() -> [Packet] {
        var packets: [Packet] = []
        
        // Chrome sync and update domains
        packets.append(PacketBuilder.buildDNSQuery(for: "clients.google.com"))
        packets.append(PacketBuilder.buildTLSClientHello(sni: "clients.google.com"))
        packets.append(PacketBuilder.buildDNSQuery(for: "update.googleapis.com"))
        packets.append(PacketBuilder.buildTLSClientHello(sni: "update.googleapis.com"))
        
        // Then some browsing
        packets.append(PacketBuilder.buildDNSQuery(for: "www.example.com"))
        packets.append(PacketBuilder.buildTLSClientHello(sni: "www.example.com"))
        
        return packets
    }
    
    /// Generate a sequence that triggers Firefox detection.
    static func firefoxActivity() -> [Packet] {
        var packets: [Packet] = []
        
        // Firefox service domains
        packets.append(PacketBuilder.buildDNSQuery(for: "firefox.settings.services.mozilla.com"))
        packets.append(PacketBuilder.buildTLSClientHello(sni: "firefox.settings.services.mozilla.com"))
        packets.append(PacketBuilder.buildDNSQuery(for: "detectportal.firefox.com"))
        packets.append(PacketBuilder.buildTLSClientHello(sni: "detectportal.firefox.com"))
        
        // Then some browsing
        packets.append(PacketBuilder.buildDNSQuery(for: "www.example.com"))
        packets.append(PacketBuilder.buildTLSClientHello(sni: "www.example.com"))
        
        return packets
    }
    
    // MARK: - Proxy Detection Tests
    
    /// Generate a sequence that triggers proxy/VPN detection.
    static func proxyAttempt() -> [Packet] {
        var packets: [Packet] = []
        
        packets.append(PacketBuilder.buildDNSQuery(for: "nordvpn.com"))
        packets.append(PacketBuilder.buildTLSClientHello(sni: "nordvpn.com"))
        packets.append(PacketBuilder.buildDNSQuery(for: "api.nordvpn.com"))
        packets.append(PacketBuilder.buildTLSClientHello(sni: "api.nordvpn.com"))
        
        return packets
    }
    
    // MARK: - Edge Cases
    
    /// Generate malformed packets to test parser resilience.
    static func malformedPackets() -> [Packet] {
        var packets: [Packet] = []
        
        packets.append(PacketBuilder.buildMalformedPacket())
        packets.append(PacketBuilder.buildEmptyTCPTo443())
        packets.append(PacketBuilder.buildUDPNonDNS())
        
        // A valid packet after garbage
        packets.append(PacketBuilder.buildDNSQuery(for: "valid.com"))
        
        return packets
    }
    
    /// Generate DNS response packets (should be ignored by parser).
    static func dnsResponses() -> [Packet] {
        var packets: [Packet] = []
        
        packets.append(PacketBuilder.buildDNSQuery(for: "example.com"))
        packets.append(PacketBuilder.buildDNSResponse(for: "example.com"))
        packets.append(PacketBuilder.buildDNSResponse(for: "another.com"))
        packets.append(PacketBuilder.buildDNSResponse(for: "third.com"))
        
        return packets
    }
    
    // MARK: - Run All Tests
    
    static func runAll() {
        print("\n" + String(repeating: "=", count: 60))
        print("PACKET GENERATOR TESTS")
        print(String(repeating: "=", count: 60))
        
        runTest("Explicit in Twitter", packets: explicitEmbeddedInTwitter())
        runTest("Direct Explicit", packets: directExplicitAccess())
        runTest("Chrome Detection", packets: chromeActivity())
        runTest("Firefox Detection", packets: firefoxActivity())
        runTest("Proxy Detection", packets: proxyAttempt())
        runTest("Malformed Packets", packets: malformedPackets())
        runTest("DNS Responses", packets: dnsResponses())
        
        print(String(repeating: "=", count: 60) + "\n")
    }
    
    private static func runTest(_ name: String, packets: [Packet]) {
        print("\n[\(name)]")
        print("  Generated \(packets.count) packets")
        
        var dnsCount = 0
        var sniCount = 0
        
        for packet in packets {
            let bytes = [UInt8](packet.data)
            guard bytes.count >= 20 else { continue }
            
            let proto = bytes[9]
            let ihl = Int(bytes[0] & 0x0F) * 4
            
            if proto == 17 { // UDP
                let payloadStart = ihl + 8
                if payloadStart < bytes.count {
                    let payload = Data(bytes[payloadStart...])
                    if let domain = DNSParser.extractDomain(from: payload) {
                        print("  DNS: \(domain)")
                        dnsCount += 1
                    }
                }
            } else if proto == 6 { // TCP
                let tcpStart = ihl
                let dataOffset = Int(bytes[tcpStart + 12] >> 4) * 4
                let payloadStart = tcpStart + dataOffset
                if payloadStart < bytes.count {
                    let payload = Data(bytes[payloadStart...])
                    if let sni = TLSParser.extractSNI(from: payload) {
                        print("  SNI: \(sni)")
                        sniCount += 1
                    }
                }
            }
        }
        
        print("  Extracted: \(dnsCount) DNS, \(sniCount) SNI")
    }
}
