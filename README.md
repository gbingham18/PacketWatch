# PacketWatch (Test Project)

A mock iOS accountability app that combines user authentication, onboarding, and accountability networking with simulated network packet monitoring. Users can sign up, configure their monitoring preferences, build an accountability network of allies and administrators, and view or report on network activity — all without needing Apple Network Extension entitlements.

## What It Does

### App Flow
- **Authentication** — Sign up, sign in, and session restore via Firebase Auth
- **Role-based onboarding** — New users choose to be monitored or to support others, then configure an administrator, filter sensitivity, and allies
- **Accountability networks** — Invite administrators (who approve filter changes) and allies (who view activity reports)
- **Feature-gated UI** — Tab bar adapts based on user role; monitored users see their own activity, supporters see a list of networks they monitor

### Packet Monitoring
- **Simulates VPN packet capture** — Generates realistic network traffic patterns
- **Parses DNS queries** — Extracts domain names from DNS wire format
- **Parses TLS ClientHello** — Extracts SNI (Server Name Indication) hostnames
- **Validates domains** — Checks against blocklists for explicit, gambling, proxy content
- **Infers active app** — Uses traffic fingerprints to determine which app made the request
- **Detects alternate browsers** — Identifies Chrome, Firefox, Brave, etc. from their network signatures

## Project Structure

```
PacketWatch/
├── PacketWatch/                        # Main app target
│   ├── PacketWatchApp.swift            # Entry point
│   ├── ContentView.swift               # Root view
│   │
│   ├── Core/                           # Domain models and core logic
│   │   ├── Features/
│   │   │   └── WellKnownFeatureIds.swift
│   │   ├── Fingerprints/
│   │   │   ├── WellKnownAppFingerprints.swift
│   │   │   └── WellKnownBrowserFingerprints.swift
│   │   ├── Models/                     # Data models
│   │   │   ├── AccountabilityNetwork.swift
│   │   │   ├── ActivityEntry.swift
│   │   │   ├── ActivityStream.swift
│   │   │   ├── BaseModel.swift
│   │   │   ├── FilterSettings.swift
│   │   │   ├── Invitation.swift
│   │   │   ├── ProposedFilterSettings.swift
│   │   │   └── User.swift
│   │   └── Validation/
│   │       ├── BrowsingContext.swift       # App inference, browser detection
│   │       └── DomainValidationProvider.swift  # Blocklist checking, categorization
│   │
│   ├── Features/                       # UI feature modules
│   │   ├── Auth/
│   │   │   ├── AuthComponents.swift
│   │   │   ├── AuthViewModel.swift
│   │   │   ├── ForgotPasswordView.swift
│   │   │   ├── SignInView.swift
│   │   │   ├── SignUpView.swift
│   │   │   └── WelcomeView.swift
│   │   ├── Dashboard/
│   │   │   ├── DashboardView.swift
│   │   │   └── DashboardViewModel.swift
│   │   ├── Networks/
│   │   │   └── NetworksListView.swift
│   │   ├── Onboarding/
│   │   │   ├── InvitationsView.swift
│   │   │   ├── OnboardingView.swift
│   │   │   └── OnboardingViewModel.swift
│   │   ├── Shared/
│   │   │   └── ActivityStreamView.swift
│   │   └── ProfileView.swift
│   │
│   ├── Parsing/                        # Protocol parsers
│   │   ├── DNSParser.swift             # DNS query extraction
│   │   └── TLSParser.swift             # TLS SNI extraction
│   │
│   ├── Services/                       # Firebase and app services
│   │   ├── AccountabilityNetworkService.swift
│   │   ├── ActivityStreamService.swift
│   │   ├── AuthService.swift
│   │   ├── BaseModelStorageService.swift
│   │   ├── FilterSettingsService.swift
│   │   ├── InvitationService.swift
│   │   ├── NetworkExtensionService.swift
│   │   ├── SafariExtensionService.swift
│   │   ├── ServiceContainer.swift
│   │   └── UserService.swift
│   │
│   ├── Simulation/                     # Mock packet infrastructure
│   │   ├── PacketBuilder.swift         # Constructs raw packets byte-by-byte
│   │   ├── PacketFlow.swift
│   │   ├── PacketGenerator.swift       # Simulates browsing sessions
│   │   ├── SimulationPacketTunnelProvider.swift  # Simulates NEPacketTunnelProvider
│   │   └── SimulationData/
│   │       └── BrowsingSessions.swift
│   │
│   └── Testing/                        # Validation tests
│       ├── PacketGeneratorTests.swift
│       └── ParserTests.swift
│
├── PacketWatchSafariExtension/         # Safari Web Extension target
│   ├── SafariWebExtensionHandler.swift
│   └── Resources/                      # Web extension bundle
│       ├── manifest.json
│       ├── background.js
│       ├── content.js
│       ├── popup.html / popup.css / popup.js
│       └── images/
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
