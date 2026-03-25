// Simulation/SimulationData/BrowsingSessions.swift
//
// Defines simulated browsing sessions for packet generation.
// Each session represents a realistic browsing pattern with
// associated domains (APIs, CDNs, analytics).

import Foundation

// MARK: - Session Type

enum SessionType {
    case normal              // Regular browsing
    case socialWithExplicit  // Social media with embedded explicit content
    case explicit            // Direct explicit site access
    case browserSignal       // Contains alternate browser fingerprints
    case proxy               // Proxy/VPN attempt
}

// MARK: - Browsing Session

struct BrowsingSession {
    let name: String
    let type: SessionType
    let domains: [String]
}

// MARK: - Session Definitions

enum BrowsingSessions {
    
    static let all: [BrowsingSession] = [
     /*
        // MARK: - Normal Browsing
        
        BrowsingSession(
            name: "Google Search",
            type: .normal,
            domains: [
                "www.google.com",
                "apis.google.com",
                "fonts.googleapis.com",
                "www.gstatic.com",
                "accounts.google.com"
            ]
        ),
        
        BrowsingSession(
            name: "Reddit",
            type: .normal,
            domains: [
                "www.reddit.com",
                "oauth.reddit.com",
                "i.redd.it",
                "v.redd.it",
                "styles.redditmedia.com",
                "www.redditstatic.com"
            ]
        ),
        
        BrowsingSession(
            name: "YouTube",
            type: .normal,
            domains: [
                "www.youtube.com",
                "i.ytimg.com",
                "yt3.ggpht.com",
                "fonts.googleapis.com",
                "play.google.com",
                "jnn-pa.googleapis.com"
            ]
        ),
        
        BrowsingSession(
            name: "GitHub",
            type: .normal,
            domains: [
                "github.com",
                "api.github.com",
                "avatars.githubusercontent.com",
                "raw.githubusercontent.com",
                "github.githubassets.com",
                "collector.github.com"
            ]
        ),
        
        BrowsingSession(
            name: "Instagram",
            type: .normal,
            domains: [
                "i.instagram.com",
                "graph.instagram.com",
                "scontent-ord5-1.cdninstagram.com",
                "static.cdninstagram.com"
            ]
        ),
        
        BrowsingSession(
            name: "TikTok",
            type: .normal,
            domains: [
                "www.tiktok.com",
                "api.tiktokv.com",
                "log.tiktokv.com",
                "pull-l3.tiktokcdn.com",
                "v16-webapp.tiktok.com"
            ]
        ),
        
        BrowsingSession(
            name: "News Site",
            type: .normal,
            domains: [
                "www.nytimes.com",
                "static01.nyt.com",
                "cooking.nytimes.com",
                "cdn.optimizely.com"
            ]
        ),
        
        // MARK: - Social Media with Explicit Content
        
        BrowsingSession(
            name: "Twitter with Embedded Explicit",
            type: .socialWithExplicit,
            domains: [
                "twitter.com",
                "api.twitter.com",
                "pbs.twimg.com",
                "video.twimg.com",
                "explicitcdn.com",
                "abs.twimg.com",
                "api.twitter.com"
            ]
        ),
        
        BrowsingSession(
            name: "Reddit NSFW",
            type: .socialWithExplicit,
            domains: [
                "www.reddit.com",
                "oauth.reddit.com",
                "i.redd.it",
                "explicitcdn.com",
                "v.redd.it",
                "styles.redditmedia.com"
            ]
        ),
        */
        // MARK: - Direct Explicit Access
        
        BrowsingSession(
            name: "Direct Explicit Access",
            type: .explicit,
            domains: [
                "explicitdomain.com",
                "www.explicitdomain.com",
                "explicitcdn.com",
                "di.explicitcdn.com"
            ]
        ),
        /*
        // MARK: - Browser Signals
        
        BrowsingSession(
            name: "Chrome Browser Activity",
            type: .browserSignal,
            domains: [
                "clients.google.com",
                "update.googleapis.com",
                "www.somesite.com",
                "cdn.somesite.com",
                "clients4.google.com"
            ]
        ),
        
        BrowsingSession(
            name: "Firefox Browser Activity",
            type: .browserSignal,
            domains: [
                "firefox.settings.services.mozilla.com",
                "detectportal.firefox.com",
                "www.example.com",
                "mozilla.org"
            ]
        ),
        */
        // MARK: - Proxy/VPN
        
        BrowsingSession(
            name: "Proxy Attempt",
            type: .proxy,
            domains: [
                "nordvpn.com",
                "www.nordvpn.com",
                "cdn.nordvpn.com"
            ]
        ),
    ]
    
    // MARK: - Filtered Access
    
    static var normalSessions: [BrowsingSession] {
        all.filter { $0.type == .normal }
    }
    
    static var explicitSessions: [BrowsingSession] {
        all.filter { $0.type == .explicit || $0.type == .socialWithExplicit }
    }
    
    static var browserSignalSessions: [BrowsingSession] {
        all.filter { $0.type == .browserSignal }
    }
    
    static var proxySessions: [BrowsingSession] {
        all.filter { $0.type == .proxy }
    }
}
