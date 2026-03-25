// Shared/WellKnownBrowserFingerprints.swift
//
// Known browser fingerprints based on their sync, update, and service domains.
// Used to detect when alternate browsers are installed and active.

import Foundation

struct BrowserFingerprint {
    let name: String
    let domains: [String]
    let urlScheme: String
    let icon: String
}

/// Well-known browser fingerprints.
///
/// Each browser has characteristic domains it connects to for sync, updates,
/// and services. When we see traffic to these domains, we know that browser
/// is installed and being used.
///
/// This is important for accountability apps because:
/// 1. Safari is the only browser we can monitor with a Safari extension
/// 2. Alternate browsers bypass screen monitoring entirely
/// 3. Users should be warned when they're using unmonitored browsers
enum WellKnownBrowserFingerprints {
    
    static let all: [BrowserFingerprint] = [
        
        BrowserFingerprint(
            name: "Google Chrome",
            domains: [
                "clients.google.com",
                "clients2.google.com",
                "clients4.google.com",
                "update.googleapis.com",
                "chrome.google.com",
                "chromewebstore.google.com",
                "chrome-devtools-frontend.appspot.com"
            ],
            urlScheme: "googlechrome",
            icon: "globe"
        ),
        
        BrowserFingerprint(
            name: "Firefox",
            domains: [
                "firefox.settings.services.mozilla.com",
                "detectportal.firefox.com",
                "push.services.mozilla.com",
                "sync.services.mozilla.com",
                "shavar.services.mozilla.com",
                "addons.mozilla.org",
                "blocklists.settings.services.mozilla.com"
            ],
            urlScheme: "firefox",
            icon: "flame"
        ),
        
        BrowserFingerprint(
            name: "Brave",
            domains: [
                "brave.com",
                "laptop-updates.brave.com",
                "go-updater.brave.com",
                "variations.brave.com",
                "p3a.brave.com"
            ],
            urlScheme: "brave",
            icon: "shield"
        ),
        
        BrowserFingerprint(
            name: "DuckDuckGo",
            domains: [
                "duckduckgo.com",
                "improving.duckduckgo.com",
                "links.duckduckgo.com",
                "staticcdn.duckduckgo.com"
            ],
            urlScheme: "ddgQuickLink",
            icon: "magnifyingglass"
        ),
        
        BrowserFingerprint(
            name: "Opera",
            domains: [
                "opera.com",
                "opera-api.com",
                "autoupdate.opera.com",
                "sitecheck2.opera.com"
            ],
            urlScheme: "opera",
            icon: "circle.lefthalf.filled"
        ),
        
        BrowserFingerprint(
            name: "Microsoft Edge",
            domains: [
                "msedge.net",
                "edge.microsoft.com",
                "microsoftedge.microsoft.com",
                "iecvlist.microsoft.com"
            ],
            urlScheme: "microsoft-edge",
            icon: "circle.grid.cross"
        ),
        
        BrowserFingerprint(
            name: "Vivaldi",
            domains: [
                "vivaldi.com",
                "update.vivaldi.com"
            ],
            urlScheme: "vivaldi",
            icon: "paintbrush"
        ),
        
        BrowserFingerprint(
            name: "Puffin",
            domains: [
                "puffin.com",
                "cloudmosa.com"
            ],
            urlScheme: "puffin",
            icon: "cloud"
        ),
        
        BrowserFingerprint(
            name: "Tor Browser",
            domains: [
                "torproject.org",
                "check.torproject.org"
            ],
            urlScheme: "tor",
            icon: "shield.lefthalf.filled"
        ),
        
        BrowserFingerprint(
            name: "Arc",
            domains: [
                "arc.net",
                "resources.arc.net"
            ],
            urlScheme: "arc",
            icon: "circle.dotted"
        ),
    ]
    
    /// Find fingerprint matching a domain
    static func match(domain: String) -> BrowserFingerprint? {
        for fingerprint in all {
            if fingerprint.domains.contains(where: { domain.contains($0) }) {
                return fingerprint
            }
        }
        return nil
    }
    
    /// Get all URL schemes for canOpenURL detection
    static var urlSchemes: [String] {
        all.map { $0.urlScheme }
    }
}
