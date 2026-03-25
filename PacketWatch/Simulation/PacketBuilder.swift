// Testing/PacketBuilder.swift
//
// Utilities to construct realistic raw network packets byte-by-byte.
// These produce the exact binary format you'd see from packetFlow.readPacketObjects()
// on a real device.
//
// Packet structure refresher:
//   [IP Header (20 bytes)] [TCP/UDP Header] [Payload (DNS or TLS)]
//
// All multi-byte fields are big-endian (network byte order).

import Foundation

struct PacketBuilder {
    
    // MARK: - DNS Query Packets
    
    /// Build a complete IPv4/UDP/DNS query packet for the given domain.
    ///
    /// Example: buildDNSQuery(for: "www.google.com")
    /// Produces: IP(proto=UDP) → UDP(dst=53) → DNS(query for www.google.com)
    static func buildDNSQuery(
        for domain: String,
        srcIP: [UInt8] = [10, 0, 0, 1],
        dstIP: [UInt8] = [1, 1, 1, 1],   // Cloudflare DNS
        srcPort: UInt16 = 12345,
        dstPort: UInt16 = 53
    ) -> Packet {
        let dnsPayload = buildDNSPayload(domain: domain)
        let udpHeader = buildUDPHeader(srcPort: srcPort, dstPort: dstPort, payload: dnsPayload)
        let ipHeader = buildIPv4Header(proto: 17, srcIP: srcIP, dstIP: dstIP, payloadLength: udpHeader.count + dnsPayload.count)
        
        return Packet(ipHeader + udpHeader + dnsPayload)
    }
    
    /// Build a raw DNS query payload (no IP/UDP headers).
    /// Useful for unit testing DNSParser directly.
    static func buildDNSPayload(domain: String, transactionID: UInt16 = 0xABCD) -> [UInt8] {
        var dns: [UInt8] = []
        
        // Transaction ID: 2 bytes
        dns.append(UInt8(transactionID >> 8))
        dns.append(UInt8(transactionID & 0xFF))
        
        // Flags: standard query (QR=0, OPCODE=0, RD=1)
        dns.append(0x01)  // RD bit set
        dns.append(0x00)
        
        // QDCOUNT: 1 question
        dns.append(0x00); dns.append(0x01)
        // ANCOUNT: 0
        dns.append(0x00); dns.append(0x00)
        // NSCOUNT: 0
        dns.append(0x00); dns.append(0x00)
        // ARCOUNT: 0
        dns.append(0x00); dns.append(0x00)
        
        // QNAME: encode domain as length-prefixed labels
        // "www.google.com" → [3]www[6]google[3]com[0]
        let labels = domain.split(separator: ".")
        for label in labels {
            let bytes = Array(label.utf8)
            dns.append(UInt8(bytes.count))
            dns.append(contentsOf: bytes)
        }
        dns.append(0x00)  // Root label (end of QNAME)
        
        // QTYPE: A record (0x0001)
        dns.append(0x00); dns.append(0x01)
        
        // QCLASS: IN (0x0001)
        dns.append(0x00); dns.append(0x01)
        
        return dns
    }
    
    // MARK: - TLS ClientHello Packets
    
    /// Build a complete IPv4/TCP/TLS ClientHello packet with the given SNI.
    ///
    /// Example: buildTLSClientHello(sni: "api.example.com")
    /// Produces: IP(proto=TCP) → TCP(dst=443) → TLS ClientHello with SNI extension
    static func buildTLSClientHello(
        sni: String,
        srcIP: [UInt8] = [10, 0, 0, 1],
        dstIP: [UInt8] = [93, 184, 216, 34],  // example.com
        srcPort: UInt16 = 54321,
        dstPort: UInt16 = 443
    ) -> Packet {
        let tlsPayload = buildTLSClientHelloPayload(sni: sni)
        let tcpHeader = buildTCPHeader(srcPort: srcPort, dstPort: dstPort)
        let ipHeader = buildIPv4Header(proto: 6, srcIP: srcIP, dstIP: dstIP,
                                        payloadLength: tcpHeader.count + tlsPayload.count)
        
        return Packet(ipHeader + tcpHeader + tlsPayload)
    }
    
    /// Build a raw TLS ClientHello payload (no IP/TCP headers).
    /// Useful for unit testing TLSParser directly.
    static func buildTLSClientHelloPayload(sni: String) -> [UInt8] {
        // We build this inside-out: SNI extension → extensions → ClientHello → TLS record
        
        // --- SNI Extension Data ---
        let hostnameBytes = Array(sni.utf8)
        var sniExtData: [UInt8] = []
        // Server Name List length (will fill after)
        let sniListLength = UInt16(hostnameBytes.count + 3)  // type(1) + length(2) + name
        sniExtData.append(UInt8(sniListLength >> 8))
        sniExtData.append(UInt8(sniListLength & 0xFF))
        // Server Name Type: 0x00 (host_name)
        sniExtData.append(0x00)
        // Host Name length
        sniExtData.append(UInt8(hostnameBytes.count >> 8))
        sniExtData.append(UInt8(hostnameBytes.count & 0xFF))
        // Host Name
        sniExtData.append(contentsOf: hostnameBytes)
        
        // --- Extensions Block ---
        var extensions: [UInt8] = []
        // SNI extension: type 0x0000
        extensions.append(0x00); extensions.append(0x00)
        // SNI extension data length
        extensions.append(UInt8(sniExtData.count >> 8))
        extensions.append(UInt8(sniExtData.count & 0xFF))
        extensions.append(contentsOf: sniExtData)
        
        // Add a few more realistic extensions so it looks like a real ClientHello
        
        // Supported Versions extension (type 0x002B) — indicates TLS 1.3 support
        let supportedVersions: [UInt8] = [
            0x00, 0x2B,         // type: supported_versions
            0x00, 0x05,         // length: 5
            0x04,               // list length: 4 bytes
            0x03, 0x04,         // TLS 1.3
            0x03, 0x03          // TLS 1.2
        ]
        extensions.append(contentsOf: supportedVersions)
        
        // Signature Algorithms extension (type 0x000D)
        let sigAlgs: [UInt8] = [
            0x00, 0x0D,         // type: signature_algorithms
            0x00, 0x08,         // length: 8
            0x00, 0x06,         // list length: 6
            0x04, 0x03,         // ECDSA-SECP256R1-SHA256
            0x08, 0x04,         // RSA-PSS-RSAE-SHA256
            0x04, 0x01          // RSA-PKCS1-SHA256
        ]
        extensions.append(contentsOf: sigAlgs)
        
        // --- ClientHello Body ---
        var clientHello: [UInt8] = []
        
        // Client Version: TLS 1.2 (0x0303) — even TLS 1.3 uses this here
        clientHello.append(0x03); clientHello.append(0x03)
        
        // Random: 32 bytes (just zeros for testing — real ones are random)
        clientHello.append(contentsOf: [UInt8](repeating: 0xAA, count: 32))
        
        // Session ID: length 32 (common for TLS 1.3 compatibility)
        clientHello.append(32)
        clientHello.append(contentsOf: [UInt8](repeating: 0xBB, count: 32))
        
        // Cipher Suites: 6 bytes (3 suites)
        clientHello.append(0x00); clientHello.append(0x06)  // length
        clientHello.append(0x13); clientHello.append(0x01)  // TLS_AES_128_GCM_SHA256
        clientHello.append(0x13); clientHello.append(0x02)  // TLS_AES_256_GCM_SHA384
        clientHello.append(0xC0); clientHello.append(0x2F)  // TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
        
        // Compression Methods: 1 byte, null only
        clientHello.append(0x01)  // length
        clientHello.append(0x00)  // null compression
        
        // Extensions total length
        clientHello.append(UInt8(extensions.count >> 8))
        clientHello.append(UInt8(extensions.count & 0xFF))
        clientHello.append(contentsOf: extensions)
        
        // --- Handshake Header ---
        var handshake: [UInt8] = []
        // Handshake type: ClientHello (0x01)
        handshake.append(0x01)
        // Handshake length: 3 bytes (big-endian)
        let chLen = clientHello.count
        handshake.append(UInt8((chLen >> 16) & 0xFF))
        handshake.append(UInt8((chLen >> 8) & 0xFF))
        handshake.append(UInt8(chLen & 0xFF))
        handshake.append(contentsOf: clientHello)
        
        // --- TLS Record Header ---
        var record: [UInt8] = []
        // Content type: Handshake (0x16)
        record.append(0x16)
        // Version: TLS 1.0 (0x0301) — standard for record layer
        record.append(0x03); record.append(0x01)
        // Record length: 2 bytes
        record.append(UInt8(handshake.count >> 8))
        record.append(UInt8(handshake.count & 0xFF))
        record.append(contentsOf: handshake)
        
        return record
    }
    
    // MARK: - IP & Transport Headers
    
    /// Build a minimal IPv4 header.
    static func buildIPv4Header(
        proto: UInt8,        // 6 = TCP, 17 = UDP
        srcIP: [UInt8],      // 4 bytes
        dstIP: [UInt8],      // 4 bytes
        payloadLength: Int
    ) -> [UInt8] {
        let totalLength = 20 + payloadLength
        
        var header: [UInt8] = []
        // Version (4) + IHL (5 = 20 bytes, no options)
        header.append(0x45)
        // DSCP / ECN
        header.append(0x00)
        // Total Length
        header.append(UInt8(totalLength >> 8))
        header.append(UInt8(totalLength & 0xFF))
        // Identification
        header.append(0x00); header.append(0x01)
        // Flags + Fragment Offset (Don't Fragment)
        header.append(0x40); header.append(0x00)
        // TTL
        header.append(64)
        // Protocol
        header.append(proto)
        // Header Checksum (0 for simplicity — real stack would compute this)
        header.append(0x00); header.append(0x00)
        // Source IP
        header.append(contentsOf: srcIP)
        // Destination IP
        header.append(contentsOf: dstIP)
        
        return header
    }
    
    /// Build a minimal UDP header (8 bytes).
    static func buildUDPHeader(
        srcPort: UInt16,
        dstPort: UInt16,
        payload: [UInt8]
    ) -> [UInt8] {
        let udpLength = UInt16(8 + payload.count)
        
        var header: [UInt8] = []
        header.append(UInt8(srcPort >> 8)); header.append(UInt8(srcPort & 0xFF))
        header.append(UInt8(dstPort >> 8)); header.append(UInt8(dstPort & 0xFF))
        header.append(UInt8(udpLength >> 8)); header.append(UInt8(udpLength & 0xFF))
        // Checksum (0 = not computed)
        header.append(0x00); header.append(0x00)
        
        return header
    }
    
    /// Build a minimal TCP header (20 bytes, no options).
    /// Data offset = 5 (20 bytes / 4).
    static func buildTCPHeader(
        srcPort: UInt16,
        dstPort: UInt16
    ) -> [UInt8] {
        var header: [UInt8] = []
        // Source port
        header.append(UInt8(srcPort >> 8)); header.append(UInt8(srcPort & 0xFF))
        // Destination port
        header.append(UInt8(dstPort >> 8)); header.append(UInt8(dstPort & 0xFF))
        // Sequence number: 4 bytes
        header.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
        // Acknowledgment number: 4 bytes
        header.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        // Data offset (5 << 4 = 0x50) + reserved + flags (SYN)
        header.append(0x50)  // data offset = 5 (20 bytes)
        header.append(0x02)  // SYN flag
        // Window size
        header.append(0xFF); header.append(0xFF)
        // Checksum (0 for simplicity)
        header.append(0x00); header.append(0x00)
        // Urgent pointer
        header.append(0x00); header.append(0x00)
        
        return header
    }
    
    // MARK: - Edge Case Packets
    
    /// Build a DNS response (not a query). The parser should ignore these.
    static func buildDNSResponse(for domain: String) -> Packet {
        var payload = buildDNSPayload(domain: domain)
        // Flip the QR bit to make it a response: byte 2, bit 7
        payload[2] = payload[2] | 0x80
        
        let udpHeader = buildUDPHeader(srcPort: 53, dstPort: 12345, payload: payload)
        let ipHeader = buildIPv4Header(proto: 17,
                                        srcIP: [1, 1, 1, 1],
                                        dstIP: [10, 0, 0, 1],
                                        payloadLength: udpHeader.count + payload.count)
        
        return Packet(ipHeader + udpHeader + payload)
    }
    
    /// Build a TCP packet to port 443 but WITHOUT a TLS ClientHello
    /// (e.g., a TCP ACK with no payload). Parser should produce no result.
    static func buildEmptyTCPTo443() -> Packet {
        let tcpHeader = buildTCPHeader(srcPort: 54321, dstPort: 443)
        let ipHeader = buildIPv4Header(proto: 6,
                                        srcIP: [10, 0, 0, 1],
                                        dstIP: [93, 184, 216, 34],
                                        payloadLength: tcpHeader.count)
        return Packet(ipHeader + tcpHeader)
    }
    
    /// Build a UDP packet to a non-DNS port. Parser should ignore it.
    static func buildUDPNonDNS() -> Packet {
        let payload: [UInt8] = [0x01, 0x02, 0x03, 0x04]
        let udpHeader = buildUDPHeader(srcPort: 12345, dstPort: 8080, payload: payload)
        let ipHeader = buildIPv4Header(proto: 17,
                                        srcIP: [10, 0, 0, 1],
                                        dstIP: [192, 168, 1, 1],
                                        payloadLength: udpHeader.count + payload.count)
        return Packet(ipHeader + udpHeader + payload)
    }
    
    /// Build a truncated/malformed packet (only 10 bytes). Should be safely ignored.
    static func buildMalformedPacket() -> Packet {
        return Packet([0x45, 0x00, 0x00, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x40, 0x11])
    }
}
