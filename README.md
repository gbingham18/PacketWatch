# PacketWatch (Test Project)

A mock iOS accountability app that simulates network packet monitoring. This test project lets you explore DNS and TLS parsing, domain validation, app fingerprinting, and browser detection — all without needing Apple Network Extension entitlements.

## What It Does

- **Simulates VPN packet capture** — Generates realistic network traffic patterns
- **Parses DNS queries** — Extracts domain names from DNS wire format
- **Parses TLS ClientHello** — Extracts SNI (Server Name Indication) hostnames
- **Validates domains** — Checks against blocklists for explicit, gambling, proxy content
- **Infers active app** — Uses traffic fingerprints to determine which app made the request
- **Detects alternate browsers** — Identifies Chrome, Firefox, Brave, etc. from their network signatures

## Project Structure

```
PacketWatch/
├── PacketWatch/                    # Main app
│   ├── PacketWatchApp.swift        # Entry point
│   └── Views/
│       └── DashboardView.swift     # Main UI
│
├── Parsing/                        # Protocol parsers
│   ├── DNSParser.swift             # DNS query extraction
│   └── TLSParser.swift             # TLS SNI extraction
│
├── Shared/                         # Core logic
│   ├── DomainEntry.swift           # Data model
│   ├── DomainLogStore.swift        # Persistence
│   ├── DomainValidation.swift      # Blocklist checking, categorization
│   └── BrowsingContext.swift       # App inference, browser detection
│
├── Testing/                        # Mock infrastructure
│   ├── MockPacketTunnelProvider.swift  # Simulates NEPacketTunnelProvider
│   ├── PacketBuilder.swift         # Constructs raw packets byte-by-byte
│   ├── PacketGenerator.swift       # Simulates browsing sessions
│   └── ParserTests.swift           # Validation tests
│
└── README.md
```

## Xcode Setup

1. Create new iOS App project called "PacketWatch"
2. Add all Swift files to the main app target
3. Build and run in simulator (no physical device needed)

That's it — no entitlements, no Network Extension target, no provisioning profile setup.

## Using the App

1. Tap **Start Tunnel** to begin simulating traffic
2. Watch domains appear in the list
3. **Red entries** = flagged domains (explicit, proxy, etc.)
4. **Purple "via" tags** = inferred source app
5. **Orange warning banner** = alternate browser detected
6. Use menu to filter flagged-only or run parser tests

## Test Scenarios

The `PacketGenerator` includes realistic scenarios:

| Session | What it tests |
|---------|---------------|
| Twitter with Embedded Explicit | Explicit CDN loaded in social media context |
| Chrome Browser Activity | Triggers browser detection via sync domains |
| Firefox Browser Activity | Triggers browser detection via Mozilla domains |
| Reddit NSFW | Explicit content in Reddit app context |
| Direct Explicit Access | Direct navigation to explicit sites |
| Proxy Attempt | VPN/proxy service detection |

## Key Files to Explore

**Start here to understand packet structure:**
- `PacketBuilder.swift` — See exactly how IP/UDP/TCP/DNS/TLS packets are constructed

**Core parsing logic:**
- `DNSParser.swift` — Length-prefixed label decoding
- `TLSParser.swift` — Navigating nested TLS structures to find SNI

**Accountability features:**
- `DomainValidation.swift` — Blocklist matching, categorization
- `BrowsingContext.swift` — App fingerprinting, browser detection

## Running Tests

From the app menu, tap **Run Parser Tests** to verify:
- DNS query parsing (various domain formats)
- DNS response rejection (QR bit check)
- TLS SNI extraction
- Malformed packet handling
- Full packet stack verification

## Next Steps

To build a real Network Extension:
1. Request Network Extension entitlement from Apple
2. Create Network Extension target (Packet Tunnel Provider)
3. Move parsers to shared framework
4. Replace `MockPacketTunnelProvider` with real `NEPacketTunnelProvider`
5. Test on physical device

See Apple's [Network Extension documentation](https://developer.apple.com/documentation/networkextension) for details.
