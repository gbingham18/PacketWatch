// PacketTunnel/TLSParser.swift
// Add to the Network Extension target ONLY

import Foundation

/// Extracts the Server Name Indication (SNI) from a TLS ClientHello message.
///
/// TLS record format:
///   - Content type: 1 byte (0x16 = Handshake)
///   - Version: 2 bytes
///   - Length: 2 bytes
///   - Handshake payload...
///
/// Handshake (ClientHello):
///   - Handshake type: 1 byte (0x01 = ClientHello)
///   - Length: 3 bytes
///   - Client version: 2 bytes
///   - Random: 32 bytes
///   - Session ID: variable (1 byte length + data)
///   - Cipher Suites: variable (2 byte length + data)
///   - Compression Methods: variable (1 byte length + data)
///   - Extensions: variable (2 byte total length, then individual extensions)
///
/// SNI Extension:
///   - Extension type: 0x0000 (server_name)
///   - Extension data length: 2 bytes
///   - Server Name List length: 2 bytes
///   - Server Name Type: 1 byte (0x00 = hostname)
///   - Host Name length: 2 bytes
///   - Host Name: UTF-8 string
///
/// NOTE: This parser is intentionally simple and won't handle every edge case.
/// It's meant for learning and will work for the vast majority of real-world
/// TLS ClientHello messages.
struct TLSParser {
    
    /// Attempt to extract the SNI hostname from a TCP payload.
    /// The input should be the raw TCP payload (not including IP/TCP headers).
    ///
    /// Returns nil if this isn't a TLS ClientHello or has no SNI extension.
    static func extractSNI(from payload: Data) -> String? {
        let bytes = [UInt8](payload)
        
        // Minimum size for a TLS record header + handshake header
        guard bytes.count > 9 else { return nil }
        
        // --- TLS Record Header ---
        
        // Content type must be 0x16 (Handshake)
        guard bytes[0] == 0x16 else { return nil }
        
        // TLS version (bytes 1-2): we accept 0x0301 (TLS 1.0) through 0x0303 (TLS 1.2)
        // TLS 1.3 ClientHello still uses 0x0301 in the record layer for compatibility
        guard bytes[1] == 0x03, bytes[2] >= 0x01, bytes[2] <= 0x03 else { return nil }
        
        // Record length (bytes 3-4)
        let recordLength = Int(bytes[3]) << 8 | Int(bytes[4])
        guard bytes.count >= 5 + recordLength else { return nil }
        
        // --- Handshake Header ---
        var offset = 5
        
        // Handshake type must be 0x01 (ClientHello)
        guard bytes[offset] == 0x01 else { return nil }
        offset += 1
        
        // Handshake length: 3 bytes (skip — we'll bounds-check as we go)
        offset += 3
        
        // Client version: 2 bytes
        offset += 2
        
        // Random: 32 bytes
        offset += 32
        
        guard offset < bytes.count else { return nil }
        
        // --- Session ID ---
        let sessionIDLength = Int(bytes[offset])
        offset += 1 + sessionIDLength
        guard offset + 2 <= bytes.count else { return nil }
        
        // --- Cipher Suites ---
        let cipherSuitesLength = Int(bytes[offset]) << 8 | Int(bytes[offset + 1])
        offset += 2 + cipherSuitesLength
        guard offset + 1 <= bytes.count else { return nil }
        
        // --- Compression Methods ---
        let compressionLength = Int(bytes[offset])
        offset += 1 + compressionLength
        guard offset + 2 <= bytes.count else { return nil }
        
        // --- Extensions ---
        let extensionsLength = Int(bytes[offset]) << 8 | Int(bytes[offset + 1])
        offset += 2
        
        let extensionsEnd = offset + extensionsLength
        guard extensionsEnd <= bytes.count else { return nil }
        
        // Walk through extensions looking for SNI (type 0x0000)
        while offset + 4 <= extensionsEnd {
            let extType = Int(bytes[offset]) << 8 | Int(bytes[offset + 1])
            let extLength = Int(bytes[offset + 2]) << 8 | Int(bytes[offset + 3])
            offset += 4
            
            if extType == 0x0000 {
                // SNI extension found — parse the Server Name List
                return parseSNIExtension(bytes: bytes, offset: offset, length: extLength)
            }
            
            offset += extLength
        }
        
        return nil
    }
    
    /// Parse the SNI extension data to extract the hostname.
    private static func parseSNIExtension(bytes: [UInt8], offset: Int, length: Int) -> String? {
        var pos = offset
        let end = offset + length
        
        guard pos + 2 <= end else { return nil }
        
        // Server Name List length: 2 bytes
        // let listLength = Int(bytes[pos]) << 8 | Int(bytes[pos + 1])
        pos += 2
        
        // We only handle the first entry
        guard pos + 3 <= end else { return nil }
        
        // Server Name Type: 1 byte (0x00 = host_name)
        let nameType = bytes[pos]
        pos += 1
        
        guard nameType == 0x00 else { return nil }
        
        // Host Name length: 2 bytes
        let nameLength = Int(bytes[pos]) << 8 | Int(bytes[pos + 1])
        pos += 2
        
        guard pos + nameLength <= end else { return nil }
        
        // Host Name: UTF-8 string
        let nameBytes = bytes[pos..<(pos + nameLength)]
        return String(bytes: nameBytes, encoding: .utf8)
    }
}
