// PacketTunnel/DNSParser.swift
// Add to the Network Extension target ONLY

import Foundation

/// Parses raw DNS query packets to extract the queried domain name.
///
/// DNS packet format (simplified):
///   - Header: 12 bytes (ID, flags, counts)
///   - Question section: variable length
///     - QNAME: sequence of length-prefixed labels (e.g., 3www6google3com0)
///     - QTYPE: 2 bytes
///     - QCLASS: 2 bytes
///
/// We only care about extracting QNAME from the question section.
struct DNSParser {
    
    /// Attempt to extract the queried domain from a raw DNS packet payload.
    /// The input should be the UDP payload (not including IP/UDP headers).
    ///
    /// Returns nil if the packet doesn't look like a valid DNS query.
    static func extractDomain(from payload: Data) -> String? {
        // DNS header is 12 bytes minimum
        guard payload.count > 12 else { return nil }
        
        let bytes = [UInt8](payload)
        
        // Check QR bit (byte 2, bit 7): 0 = query, 1 = response
        // We want queries (QR = 0)
        let isQuery = (bytes[2] & 0x80) == 0
        guard isQuery else { return nil }
        
        // QDCOUNT (bytes 4-5): number of questions, expect >= 1
        let qdcount = (UInt16(bytes[4]) << 8) | UInt16(bytes[5])
        guard qdcount >= 1 else { return nil }
        
        // Parse QNAME starting at byte 12
        var offset = 12
        var labels: [String] = []
        
        while offset < bytes.count {
            let labelLength = Int(bytes[offset])
            
            // A zero-length label marks the end of QNAME
            if labelLength == 0 {
                break
            }
            
            // Sanity check: label length should be 1-63
            guard labelLength <= 63 else { return nil }
            
            offset += 1
            
            // Make sure we have enough bytes for this label
            guard offset + labelLength <= bytes.count else { return nil }
            
            let labelBytes = bytes[offset..<(offset + labelLength)]
            guard let label = String(bytes: labelBytes, encoding: .utf8) else { return nil }
            labels.append(label)
            
            offset += labelLength
        }
        
        guard !labels.isEmpty else { return nil }
        
        return labels.joined(separator: ".")
    }
}
