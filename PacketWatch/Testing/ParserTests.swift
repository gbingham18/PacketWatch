// Testing/ParserTests.swift
//
// Unit tests for DNSParser and TLSParser.
// These can run as XCTest cases in Xcode, or you can call
// ParserTests.runAll() from the app to verify in the console.
//
// To use as XCTests:
//   1. Create a test target in Xcode
//   2. Import XCTest
//   3. Convert the static methods to func test___() methods
//
// For now, these run standalone so you can verify without a test target.

import Foundation

struct ParserTests {
    
    static func runAll() {
        print("=" * 60)
        print("Running Parser Tests")
        print("=" * 60)
        
        var passed = 0
        var failed = 0
        
        func assert(_ condition: Bool, _ name: String) {
            if condition {
                print("  ✅ \(name)")
                passed += 1
            } else {
                print("  ❌ \(name)")
                failed += 1
            }
        }
        
        // ---- DNS Parser Tests ----
        print("\n--- DNSParser ---")
        
        // Basic domain parsing
        let googleDNS = PacketBuilder.buildDNSPayload(domain: "www.google.com")
        assert(
            DNSParser.extractDomain(from: Data(googleDNS)) == "www.google.com",
            "Parse simple domain: www.google.com"
        )
        
        // Single-label domain
        let localhost = PacketBuilder.buildDNSPayload(domain: "localhost")
        assert(
            DNSParser.extractDomain(from: Data(localhost)) == "localhost",
            "Parse single-label domain: localhost"
        )
        
        // Deep subdomain
        let deep = PacketBuilder.buildDNSPayload(domain: "a.b.c.d.example.co.uk")
        assert(
            DNSParser.extractDomain(from: Data(deep)) == "a.b.c.d.example.co.uk",
            "Parse deep subdomain"
        )
        
        // DNS response should return nil (we only want queries)
        var responseDNS = PacketBuilder.buildDNSPayload(domain: "example.com")
        responseDNS[2] = responseDNS[2] | 0x80  // Set QR bit
        assert(
            DNSParser.extractDomain(from: Data(responseDNS)) == nil,
            "Reject DNS response (QR=1)"
        )
        
        // Empty data
        assert(
            DNSParser.extractDomain(from: Data()) == nil,
            "Handle empty data gracefully"
        )
        
        // Truncated header
        assert(
            DNSParser.extractDomain(from: Data([0x00, 0x01, 0x01])) == nil,
            "Handle truncated header"
        )
        
        // Zero QDCOUNT
        var noQuestions = PacketBuilder.buildDNSPayload(domain: "test.com")
        noQuestions[4] = 0x00; noQuestions[5] = 0x00  // QDCOUNT = 0
        assert(
            DNSParser.extractDomain(from: Data(noQuestions)) == nil,
            "Reject packet with zero questions"
        )
        
        // ---- TLS Parser Tests ----
        print("\n--- TLSParser ---")
        
        // Basic SNI extraction
        let githubTLS = PacketBuilder.buildTLSClientHelloPayload(sni: "github.com")
        assert(
            TLSParser.extractSNI(from: Data(githubTLS)) == "github.com",
            "Parse SNI: github.com"
        )
        
        // Long subdomain
        let longSNI = PacketBuilder.buildTLSClientHelloPayload(sni: "api.v2.staging.internal.example.com")
        assert(
            TLSParser.extractSNI(from: Data(longSNI)) == "api.v2.staging.internal.example.com",
            "Parse long subdomain SNI"
        )
        
        // Short domain
        let shortSNI = PacketBuilder.buildTLSClientHelloPayload(sni: "t.co")
        assert(
            TLSParser.extractSNI(from: Data(shortSNI)) == "t.co",
            "Parse short SNI: t.co"
        )
        
        // Not a TLS record (wrong content type)
        var notTLS = PacketBuilder.buildTLSClientHelloPayload(sni: "test.com")
        notTLS[0] = 0x15  // Change from Handshake (0x16) to Alert (0x15)
        assert(
            TLSParser.extractSNI(from: Data(notTLS)) == nil,
            "Reject non-Handshake record type"
        )
        
        // TLS record but not ClientHello (e.g., ServerHello = 0x02)
        var serverHello = PacketBuilder.buildTLSClientHelloPayload(sni: "test.com")
        serverHello[5] = 0x02  // Change handshake type from ClientHello to ServerHello
        assert(
            TLSParser.extractSNI(from: Data(serverHello)) == nil,
            "Reject ServerHello (not ClientHello)"
        )
        
        // Empty data
        assert(
            TLSParser.extractSNI(from: Data()) == nil,
            "Handle empty data gracefully"
        )
        
        // Random garbage
        let garbage = Data((0..<100).map { _ in UInt8.random(in: 0...255) })
        // This might or might not return nil depending on random bytes,
        // but it should NOT crash
        let _ = TLSParser.extractSNI(from: garbage)
        assert(true, "Handle random data without crashing")
        
        // ---- Full Pipeline Tests ----
        print("\n--- Full Packet Pipeline ---")
        
        // DNS query through full IP/UDP stack
        let fullDNS = PacketBuilder.buildDNSQuery(for: "stackoverflow.com")
        let dnsBytes = [UInt8](fullDNS.data)
        // Verify IP header: version 4, proto 17 (UDP)
        assert(dnsBytes[0] >> 4 == 4, "Full DNS packet has IPv4 header")
        assert(dnsBytes[9] == 17, "Full DNS packet has UDP protocol")
        // Verify UDP dst port 53
        let udpStart = Int(dnsBytes[0] & 0x0F) * 4
        let dstPort = UInt16(dnsBytes[udpStart + 2]) << 8 | UInt16(dnsBytes[udpStart + 3])
        assert(dstPort == 53, "Full DNS packet targets port 53")
        // Verify domain is extractable from payload
        let dnsPayloadStart = udpStart + 8
        let dnsPayload = Data(dnsBytes[dnsPayloadStart...])
        assert(
            DNSParser.extractDomain(from: dnsPayload) == "stackoverflow.com",
            "Extract domain from full packet's payload"
        )
        
        // TLS ClientHello through full IP/TCP stack
        let fullTLS = PacketBuilder.buildTLSClientHello(sni: "api.example.com")
        let tlsBytes = [UInt8](fullTLS.data)
        assert(tlsBytes[0] >> 4 == 4, "Full TLS packet has IPv4 header")
        assert(tlsBytes[9] == 6, "Full TLS packet has TCP protocol")
        let tcpStart = Int(tlsBytes[0] & 0x0F) * 4
        let tcpDstPort = UInt16(tlsBytes[tcpStart + 2]) << 8 | UInt16(tlsBytes[tcpStart + 3])
        assert(tcpDstPort == 443, "Full TLS packet targets port 443")
        let tcpDataOffset = Int(tlsBytes[tcpStart + 12] >> 4) * 4
        let tlsPayloadStart = tcpStart + tcpDataOffset
        let tlsPayload = Data(tlsBytes[tlsPayloadStart...])
        assert(
            TLSParser.extractSNI(from: tlsPayload) == "api.example.com",
            "Extract SNI from full packet's payload"
        )
        
        // ---- Summary ----
        print("\n" + "=" * 60)
        print("Results: \(passed) passed, \(failed) failed")
        print("=" * 60)
    }
}

// Helper for string repetition
private func *(lhs: String, rhs: Int) -> String {
    String(repeating: lhs, count: rhs)
}
