# Changelog

All notable changes to Codex Quota Widget are documented here.

## Unreleased

### Added

- Live Codex Credits balance, displayed as points and refreshed every minute.
- A dedicated bottom bar for the 5-hour quota window, which activates automatically when the local Codex API returns that window.
- A lower-left horizontal glass insights card with Token goals, a recent 7-day line chart, and a 90-day daily token heatmap.

### Changed

- Unified the desktop bubble typography with a rounded typeface.
- Enlarged the quota ring and adjusted the bubble to a 250 px layout.
- Increased the spacing between the quota ring and the left-aligned details column.
- Clarified that the Credits value is a point balance, not a converted dollar amount.
- Added daily token buckets to the sanitized live snapshot so the new charts use local Codex usage data.

## 0.1.0

### Added

- A persistent macOS desktop bubble for Codex plan, quota, reset time, and usage progress.
- Live local sync through the Codex app-server.
- A manual snapshot fallback for when live sync is unavailable.
