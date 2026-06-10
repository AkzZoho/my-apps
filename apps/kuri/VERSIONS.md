# Kuri App — Version History

## Current Version: 1.0.1+8

---

| Version Code | Version Name | Track          | Date       | Notes                                      |
|:------------:|:------------:|----------------|------------|--------------------------------------------|
| +8           | 1.0.1        | Closed Testing | 2026-06-10 | Fix Google Sign-In (Play App Signing OAuth client) |
| +7           | 1.0.1        | Closed Testing | 2026-06-10 | Light theme icon, latest feature fixes     |
| +6           | 1.0.1        | —              | 2026-06-10 | Skipped (not uploaded)                     |
| +5           | 1.0.1        | Closed Testing | 2026-06-10 | google-services.json fix for Android login |
| +4           | 1.0.1        | —              | 2026-06-10 | Skipped (not uploaded)                     |
| +3           | 1.0.1        | Closed Testing | 2026-06-08 | First closed testing release               |
| +2           | 1.0.1        | —              | —          | Initial build (not uploaded)               |

---

## Release Notes

### 1.0.1+7 — Closed Testing
- Light theme app icon
- Allow Moopan to reopen a closed auction
- Allow Moopan to place bids on behalf of members
- Allow Moopan to upload payment proof on behalf of members

### 1.0.1+5 — Closed Testing
- Fixed Google Sign-In on Android (google-services.json)
- Admin can upload payment proof on behalf of members
- Fixed "no user found" error when adding participant by email

### 1.0.1+3 — Closed Testing
- First closed testing release
- Lelam (auction) and Changatha (lottery) kuri types
- URL-based routing (browser refresh stays on correct page)
- Moopan can manually choose auction winner
- Refresh / auto-refresh on Auction Management screen

---

## How to Build

```bash
git pull origin claude/committee-app-ui-testing-YTw60
cd apps/kuri
flutter pub get
flutter build appbundle --release
# AAB: build/app/outputs/bundle/release/app-release.aab
```

## Before Each Release
1. Increment version code in `pubspec.yaml` (e.g. `1.0.1+7` → `1.0.1+8`)
2. Update this file — bump **Current Version** and add a row to the table
3. Commit and push, then build
