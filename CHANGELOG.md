# Changelog

All notable changes to Codex Quota Widget are documented here.

## Unreleased

### Added

- Live Codex Credits balance, displayed as points and refreshed every minute.
- A dedicated bottom bar for the 5-hour quota window, which activates automatically when the local Codex API returns that window.
- A lower-left horizontal glass insights card with Token goals, a recent 7-day line chart, and a 90-day daily token heatmap.
- Replaced the temporary Token goals with live today, current-week, and lifetime usage totals.
- Aligned the 90-day heatmap by calendar week and weekday to match Codex's daily usage view.

### Changed

- Unified the desktop bubble typography with a rounded typeface.
- Enlarged the quota ring and adjusted the bubble to a 250 px layout.
- Increased the spacing between the quota ring and the left-aligned details column.
- Clarified that the Credits value is a point balance, not a converted dollar amount.
- Added daily token buckets to the sanitized live snapshot so the new charts use local Codex usage data.
- Kept the lifetime token total from the usage summary as the source for the new cumulative row.
- Split the original quota bubble and the usage insights bubble into separate widget folders and processes.
- Put both widget windows at the macOS desktop window level so they stay beneath app windows.
- Corrected the Token heatmap to use real calendar weeks, weekday rows, month boundaries, and only the dates returned by Codex.
- Removed the daily/weekly/cumulative switch; hovering or clicking a cell now reveals that date's live Token count.

## 0.1.0

### Added

- A persistent macOS desktop bubble for Codex plan, quota, reset time, and usage progress.
- Live local sync through the Codex app-server.
- A manual snapshot fallback for when live sync is unavailable.
