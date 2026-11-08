# MBQuickDemoiOSClient

Acme Bank's iOS client — a SwiftUI app built with [XcodeGen](https://github.com/yonaskolb/XcodeGen).

## Getting started

1. Install XcodeGen (`brew install xcodegen`) if you don't have it.
2. Generate the Xcode project: `xcodegen generate`.
3. Open `AcmeBank.xcodeproj` and run the `AcmeBank` scheme on a simulator.

The app talks to the [Mock Backend](../acme-mock-backend) over plain HTTP.
Start it locally (default `http://localhost:3000`) before signing in —
demo credentials: `bankuser.one@acmebank.com` / `Password123`.

## Configuration

- `API_BASE_URL` — the Mock Backend's base URL. Read at runtime from the
  app's `Info.plist` (never hardcoded in Swift). Supplied via
  `Config/Base.xcconfig`, which defaults to `http://localhost:3000` — this
  is not a secret, so it's committed as-is and there's no local/gitignored
  override needed. Point it at a different host by editing that file (or
  overriding the `API_BASE_URL` build setting) if your Mock Backend runs
  elsewhere.

## Project layout

- `AcmeBank/App` — `@main` entry point, root view, in-memory session store.
- `AcmeBank/Networking` — `APIClient` (URLSession/async-await) and `AuthService`.
- `AcmeBank/DesignSystem` — shared colours and vector shapes (hexagon logo,
  Okta mark) — navy/white/grey only, no image assets.
- `AcmeBank/Features/Login` — the login screen (`LoginView` + `LoginViewModel`).
- `AcmeBankTests` — XCTest unit tests (ViewModel-level; no XCUITest yet).

Real Okta/OIDC auth, Keychain-backed session persistence, and the post-login
Landing Screen are out of scope for the login screen story — a placeholder
"Signed in as `<firstName>`" view stands in until the Landing Screen ships.
