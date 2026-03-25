// Shared/WellKnownAppFingerprints.swift
//
// Known app fingerprints based on their API, CDN, and service domains.
// Used to infer which app made a network request.

import Foundation

struct AppFingerprint {
    let name: String
    let domains: [String]  // Partial matches (contains)
    let icon: String       // SF Symbol name for UI
}

/// Well-known app fingerprints.
/// 
/// Each app has characteristic domains it connects to (APIs, CDNs, analytics).
/// When we see traffic to these domains, we can infer that app is active.
///
/// To add a new app:
/// 1. Monitor the app's network traffic (e.g., with Charles Proxy or mitmproxy)
/// 2. Identify unique domains that aren't shared with other apps
/// 3. Prefer API domains over generic CDNs
enum WellKnownAppFingerprints {
    
    static let all: [AppFingerprint] = [
        
        // MARK: - Social Media
        
        AppFingerprint(
            name: "Twitter/X",
            domains: [
                "twitter.com",
                "api.twitter.com",
                "twimg.com",
                "t.co",
                "x.com"
            ],
            icon: "bird"
        ),
        
        AppFingerprint(
            name: "Instagram",
            domains: [
                "instagram.com",
                "i.instagram.com",
                "graph.instagram.com",
                "cdninstagram.com"
            ],
            icon: "camera"
        ),
        
        AppFingerprint(
            name: "Facebook",
            domains: [
                "facebook.com",
                "fb.com",
                "fbcdn.net",
                "fbsbx.com",
                "connect.facebook.net"
            ],
            icon: "person.2"
        ),
        
        AppFingerprint(
            name: "TikTok",
            domains: [
                "tiktok.com",
                "tiktokv.com",
                "tiktokcdn.com",
                "musical.ly",
                "byteoversea.com"
            ],
            icon: "music.note"
        ),
        
        AppFingerprint(
            name: "Snapchat",
            domains: [
                "snapchat.com",
                "snap.com",
                "sc-cdn.net",
                "snapkit.co",
                "impala-media-production.s3.amazonaws.com"
            ],
            icon: "camera.viewfinder"
        ),
        
        AppFingerprint(
            name: "LinkedIn",
            domains: [
                "linkedin.com",
                "licdn.com",
                "linkedin.sc.omtrdc.net"
            ],
            icon: "briefcase"
        ),
        
        AppFingerprint(
            name: "Pinterest",
            domains: [
                "pinterest.com",
                "pinimg.com",
                "api.pinterest.com"
            ],
            icon: "pin"
        ),
        
        AppFingerprint(
            name: "Discord",
            domains: [
                "discord.com",
                "discord.gg",
                "discordapp.com",
                "discord.media",
                "cdn.discordapp.com"
            ],
            icon: "message"
        ),
        
        AppFingerprint(
            name: "Telegram",
            domains: [
                "telegram.org",
                "t.me",
                "telegram.me",
                "telesco.pe"
            ],
            icon: "paperplane"
        ),
        
        AppFingerprint(
            name: "WhatsApp",
            domains: [
                "whatsapp.com",
                "whatsapp.net",
                "wa.me"
            ],
            icon: "phone.bubble.left"
        ),
        
        AppFingerprint(
            name: "Signal",
            domains: [
                "signal.org",
                "signal.art",
                "textsecure-service.whispersystems.org"
            ],
            icon: "lock.shield"
        ),
        
        AppFingerprint(
            name: "Slack",
            domains: [
                "slack.com",
                "slack-edge.com",
                "slack-imgs.com",
                "slack-files.com"
            ],
            icon: "number"
        ),
        
        AppFingerprint(
            name: "YouTube",
            domains: [
                "youtube.com",
                "youtu.be",
                "googlevideo.com",
                "ytimg.com",
                "youtube-nocookie.com"
            ],
            icon: "play.rectangle"
        ),
        
        AppFingerprint(
            name: "Netflix",
            domains: [
                "netflix.com",
                "nflxvideo.net",
                "nflximg.net",
                "nflxext.com"
            ],
            icon: "tv"
        ),
        
        AppFingerprint(
            name: "Twitch",
            domains: [
                "twitch.tv",
                "jtvnw.net",
                "twitchcdn.net",
                "ext-twitch.tv"
            ],
            icon: "gamecontroller"
        ),
        
        AppFingerprint(
            name: "Reddit",
            domains: [
                "reddit.com",
                "redd.it",
                "redditmedia.com",
                "redditstatic.com",
                "reddituploads.com"
            ],
            icon: "bubble.left.and.bubble.right"
        ),
        
        AppFingerprint(
            name: "Tumblr",
            domains: [
                "tumblr.com",
                "txmblr.com",
                "assets.tumblr.com"
            ],
            icon: "text.quote"
        ),
        
        AppFingerprint(
            name: "Apple News",
            domains: [
                "news-events.apple.com",
                "news-edge.apple.com",
                "apple.news"
            ],
            icon: "newspaper"
        ),
        
        AppFingerprint(
            name: "Flipboard",
            domains: [
                "flipboard.com",
                "cdn.flipboard.com"
            ],
            icon: "book"
        ),
        
        AppFingerprint(
            name: "Tinder",
            domains: [
                "tinder.com",
                "gotinder.com",
                "tindersparks.com"
            ],
            icon: "flame"
        ),
        
        AppFingerprint(
            name: "Bumble",
            domains: [
                "bumble.com",
                "thebeehive.bumble.com"
            ],
            icon: "heart"
        ),
        
        AppFingerprint(
            name: "Hinge",
            domains: [
                "hinge.co",
                "hingeaws.net"
            ],
            icon: "heart.circle"
        ),
    ]
    
    /// Find fingerprint matching a domain
    static func match(domain: String) -> AppFingerprint? {
        for fingerprint in all {
            if fingerprint.domains.contains(where: { domain.contains($0) }) {
                return fingerprint
            }
        }
        return nil
    }
}
