# PacketWatch (Test Project)

 PacketWatch helps users stay accountable online by building a personal accountability network and monitoring network activity. Users can sign up, configure monitoring preferences, designate allies and administrators within their accountability network, and view or generate reports on network activity.

Features

- **User authentication & onboarding — Sign-up flow with guided setup for new users
- **Accountability networking — Build a network of allies and administrators who can help keep you accountable
- **Monitoring preferences — Configure what gets monitored and how
- **Network activity reporting — View and report on network traffic data
- **Feature-gated UI** — Tab bar adapts based on user role; monitored users see their own activity, supporters see a list of networks they monitor

### Packet Monitoring
- **Simulates VPN packet capture** — Generates realistic network traffic patterns
- **Parses DNS queries** — Extracts domain names from DNS wire format
- **Parses TLS ClientHello** — Extracts SNI (Server Name Indication) hostnames
- **Validates domains** — Checks against blocklists for explicit, gambling, proxy content
- **Infers active app** — Uses traffic fingerprints to determine which app made the request
- **Detects alternate browsers** — Identifies Chrome, Firefox, Brave, etc. from their network signatures

Status
This project is actively in development. Network traffic data is currently simulated, as the app does not yet have Apple Network Extension entitlements. The goal is to integrate real packet monitoring once those entitlements are obtained.

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

## Next Steps

1. Request Network Extension entitlement from Apple
2. Replace `SimulationPacketTunnelProvider` with real `NEPacketTunnelProvider`
3. Test on physical device

See Apple's [Network Extension documentation](https://developer.apple.com/documentation/networkextension) for details.
