// SafariExtension/SafariWebExtensionHandler.swift
//
// Receives messages from the Safari Extension JavaScript
// and forwards them to the main app via App Groups.

import SafariServices
import os.log

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    
    private let appGroupID = "group.com.bingham.packetwatch"
    private let storageKey = "safariDomains"
    private let logger = Logger(subsystem: "com.bingham.packetwatch", category: "SafariExtension")
    
    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem
        
        guard let message = request?.userInfo?[SFExtensionMessageKey] as? [String: Any] else {
            logger.error("Invalid message format")
            context.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }
        
        // Extract domain from message
        guard let domain = message["domain"] as? String else {
            logger.error("Missing domain in message")
            context.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }
        
        let messageType = message["type"] as? String ?? "navigation"
        let timestamp = message["timestamp"] as? Double ?? Date().timeIntervalSince1970 * 1000
        
        logger.info("Safari visited: \(domain)")
        
        // Store in App Group for main app to read
        storeDomain(domain, type: messageType, timestamp: timestamp)
        
        // Send response back to JavaScript
        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: ["status": "received"]]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
    
    private func storeDomain(_ domain: String, type: String, timestamp: Double) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            logger.error("Could not access App Group")
            return
        }
        
        // Create entry
        let entry: [String: Any] = [
            "domain": domain,
            "type": type,
            "timestamp": timestamp,
            "source": "safariExtension"
        ]
        
        // Append to existing entries
        var entries = defaults.array(forKey: storageKey) as? [[String: Any]] ?? []
        entries.append(entry)
        
        // Keep last 1000 entries
        if entries.count > 1000 {
            entries = Array(entries.suffix(1000))
        }
        
        defaults.set(entries, forKey: storageKey)
    }
}
