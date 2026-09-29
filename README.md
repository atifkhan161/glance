# Glance

A personal intelligence dashboard for iOS. Aggregates multiple data streams into a single home screen with a clean, dark-mode-first design.

![Glance](docs/screenshot.png)

## Features

- **Pulse Feed** — Unified card-based view of all your data streams
- **Real Madrid** — Match fixtures, live timeline, and news via ManagingMadrid + TheSportsDB
- **Pokémon GO** — Current raids, events, and priority recommendations
- **GitHub Trending** — Daily trending repositories with language breakdown
- **AI Intel** — Curated AI/ML news summarized by on-device or cloud intelligence
- **Custom RSS** — Add any RSS feed and surface it as a card in your Pulse

## Architecture

```
Glance/
├── App/              # App entry, AppState, ContentView, floating dock
├── Core/
│   ├── Cache/        # CacheStore (UserDefaults), KeychainStore for secrets
│   ├── Intelligence/ # IntelligenceRouter — Apple Foundation Models → Gemini fallback
│   ├── Network/      # API clients (Exa, Gemini, GitHub, SportsDB, RSS, etc.)
│   └── Time/         # Time formatting utilities
├── DesignSystem/     # Theme, colors, fonts (Manrope), reusable components
├── Features/
│   ├── AiIntel/      # AI news pipeline and views
│   ├── CustomRSS/    # User-added RSS feeds
│   ├── GenericRSS/   # RSS parsing pipeline
│   ├── GitHub/       # Trending repos pipeline and views
│   ├── Madrid/       # Real Madrid fixtures, timeline, articles
│   ├── PoGo/         # Pokémon GO raids and events
│   └── Pulse/        # Main feed view and card rendering
├── Settings/         # Settings, API key management, sources, RSS feed config
└── Shared/           # Enums, extensions
```

## Apple Intelligence

Glance runs AI entirely on-device using Apple's Foundation Models framework — zero cost, zero latency, fully private. No data leaves your phone.

### AI Features

| Feature | What it does |
|---------|-------------|
| **Article Summaries** | Streaming numbered sections + verdict on any article |
| **Real Madrid** | Match form, La Liga standing, tactical intel from web search |
| **Pokémon GO** | Top priority raid/event recommendation |
| **AI Intel** | Classifies news as Frontier Labs vs Open Weights |

### How It Works

1. **On-device** — Uses `SystemLanguageModel` with permissive guardrails for content summarization
2. **Fallback** — If Apple Intelligence is unavailable, routes to Gemini cloud (API key in Settings)
3. **Graceful degradation** — If both fail, feature hides silently — no crashes, no empty cards

### Requirements

- iPhone 15 Pro / iPhone 16 / iPhone 17 (A17 Pro or later)
- iOS 18+ with Apple Intelligence enabled
- ~1.6 GB model download (auto-downloads on first use)

Check status in **Settings > Sources > ON-DEVICE AI**.

## API Keys

Glance requires the following API keys, configured in Settings:

| Key | Purpose | Source |
|-----|---------|--------|
| **Exa** | Web search for AI Intel articles | [exa.ai](https://exa.ai) |
| **Gemini** | LLM intelligence routing (fallback when Apple Intelligence unavailable) | [aistudio.google.com](https://aistudio.google.com) |

Real Madrid and Pokémon GO data use free APIs (TheSportsDB, public RSS feeds) — no keys required.

**Gemini Model Selection:** Choose between Flash 3.6, 3.7, or 3.8 in Settings.

## Requirements

- **iOS 26.0+** on device (the app's deployment target)
- Xcode 16.0+ and Swift 5.9+ to build from source
- An iPhone 15 Pro Max or newer is recommended, but any arm64 device on iOS 26.0+ works

## Download

Grab the latest `.ipa` from [Releases](https://github.com/atifkhan161/glance/releases/latest).

The published IPA is **ad-hoc signed but not certificate-signed**. That is deliberate — every method below
re-signs it with your own Apple ID, so shipping a real signature would only be discarded. It does need a
signature to be present, though: sideloaders re-sign from an already-signed input, and a completely
unsigned app fails with a bundle-ID mismatch. It carries **no entitlements** — Glance has no app
extensions, no app groups, and uses the default keychain, so the sideloader supplies everything needed. Choose the method that fits you:

| Method | Computer needed | Best for |
| --- | --- | --- |
| [LiveContainer](#livecontainer) | Once, to install LiveContainer | Most people — no weekly chore, unlimited apps |
| [SideStore](#sidestore) | Once, to pair | Background refresh, no laptop needed afterwards |
| [AltStore](#altstore) | Every refresh | Simplest to set up, most upkeep |

### LiveContainer

[LiveContainer](https://livecontainer.github.io) is an app launcher that runs other apps inside itself.
One signed app slot can hold many, which sidesteps the free-tier 3-app limit entirely.

1. Install LiveContainer using its [official guide](https://livecontainer.github.io/docs/installation).
   It can be installed via Impactor, iloader, or an existing SideStore. (LiveContainer's docs
   specifically do **not** support Sideloadly, i4/3u Tools, or most online signers.)
2. Import your signing certificate so LiveContainer can sign apps in JIT-less mode:
   open LiveContainer **Settings → Import Certificate from SideStore**. SideStore opens, exports a
   certificate, and LiveContainer picks it up.
3. Check **Settings → JIT-Less Mode Diagnose → Test JIT-Less Mode**. It should report
   `JIT-Less Mode Test Passed`. If it reports a missing certificate, re-export from SideStore —
   the certificate changes on every refresh, so an outdated one breaks app signing.
4. Tap the **+** button in the top-right of LiveContainer and select the downloaded `Glance.ipa`.
5. Launch Glance from the LiveContainer list.

**Re-export the certificate after every SideStore/AltStore refresh** — this is the most common cause
of a suddenly-failing install. A calendar reminder every 7 days is a good idea on a free account.

### SideStore

[SideStore](https://sidestore.io) is a fork of AltStore that refreshes on-device over a local VPN, so
no computer needs to stay awake on your network.

1. Follow the [SideStore installation guide](https://sidestore.io) to pair once with a PC/Mac.
2. Open SideStore → **My Apps** → **+** and pick the downloaded `Glance.ipa`.
3. On first launch, go to **Settings → General → VPN & Device Management** and trust your Apple ID
   under "Developer App".
4. Keep the LocalDevVPN connected so SideStore can refresh in the background.

### AltStore

[AltStore](https://altstore.io) refreshes over WiFi from a computer running AltServer, so that
computer must be awake and on the same network when your certificate expires.

1. Download and install [AltServer](https://altstore.io) on your Mac (macOS 11+).
2. Connect your iPhone via USB, trust the computer, then install AltStore on the device from the
   AltServer menu bar icon.
3. Save the `Glance.ipa` to the Files app (e.g. **Files → On My iPhone → Downloads**).
4. Open AltStore → **My Apps** → **+** in the top-left, select the IPA, and wait while AltServer
   signs and installs it.
5. Go to **Settings → General → VPN & Device Management** and trust your Apple ID.
6. If AltStore prompts that it wants to open Glance, accept it.

**Option:** hold **Option** while clicking the AltServer menu bar icon and choose **Sideload .ipa…**
to install directly without AltStore. This skips the My Apps interface, but you must reinstall every
7 days by hand. Installing AltStore Classic is the better choice if you want managed refreshes.

### What to expect with a free Apple ID

- **7-day signature.** After it lapses the icon stays on your home screen but tapping it does nothing
  until you refresh. LiveContainer works around the *app count* but not this clock.
- **3 apps at once**, and AltStore/SideStore themselves count against that.
- **No push notifications** for apps running inside LiveContainer.
- **~10 new App IDs per rolling 7 days.** Glance ships without extensions, so it consumes one.

Developer Mode must be enabled the first time you open a sideloaded app:
**Settings → Privacy & Security → Developer Mode**.

### Troubleshooting

| Symptom | Fix |
| --- | --- |
| **"bundleid does not match with the specified"** | The IPA had no code signature. Sideloaders re-sign the app, but they re-sign from an already-signed input, so a blank app fails bundle-ID validation. Download the current release. |
| **"The keychain access group '$(AppIdentifierPrefix)…' does not contain a Team ID prefix"** | Same class of problem — the IPA shipped with unexpanded Xcode entitlement placeholders. Current releases are signed with **no entitlements**; Glance needs none (no extensions, no app groups, default keychain). |
| Icon present but app does nothing | Signature expired — refresh from AltStore/SideStore, or re-import the certificate into LiveContainer |
| LiveContainer says "Certificate not found" | Certificate wasn't exported after a refresh. In SideStore: **Settings → Export Signing Certificate…**, save with a password, then **Import Certificate** in LiveContainer |
| "Application failed preflight checks" | Another sideload operation is mid-flight. Wait for it to finish and retry |
| Installation stalls "Processing" | First-time device registration with Apple can take up to a day. It only happens once |
| App installs but features are missing | LiveContainer does not apply the guest app's entitlements, and app permissions are applied globally. Anything depending on a private entitlement may not work |

> **Apple Intelligence:** Glance prefers on-device Foundation Models for summarization, falling back to
> the Gemini API. Under LiveContainer, Foundation Models requires JIT and is unavailable below iOS 26, so
> the app falls back to Gemini — or degrades gracefully with no AI summary if no key is set. See
> [Apple Intelligence limitations](docs/apple-intelligence-limitations.md).

## Getting Started (from source)

1. Clone the repository:
   ```bash
   git clone https://github.com/atifkhan161/glance.git
   ```

2. Open `Glance/Glance.xcodeproj` in Xcode

3. Build and run on a device or simulator

4. Open Settings in-app and enter your API keys

## Design

- **Dark mode first** with light mode support
- **Floating pill dock** navigation (custom, not UITabBar)
- **Manrope** typeface throughout
- **Card-based** layout with accent color coding per data source
- Respects `UIAccessibility.isReduceMotionEnabled`

## License

MIT
