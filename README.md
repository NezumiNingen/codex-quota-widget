# Codex Quota Widget

A compact macOS desktop bubble that shows your live Codex plan, remaining quota, reset time, and usage progress.

See [CHANGELOG.md](CHANGELOG.md) for version-by-version updates.

## Latest update

- Shows the live Credits count returned by Codex as points, refreshed every minute.
- Reserves the bottom progress bar for the live 5-hour quota window when Codex provides it.
- Uses one rounded typeface throughout the bubble.
- Enlarges the quota ring and adjusts the bubble to a roomier 250 px layout.
- Adds spacing between the ring and the detail column for better readability.

## Live data and privacy

Live sync uses read-only account requests from the local Codex `app-server` to retrieve plan, quota, reset time, Credits, and token usage. It does not read, save, or display sign-in tokens or email addresses. The sanitized result is stored only in `~/.codex/codex-quota-live.json`, which the desktop bubble reads automatically.

The bubble displays the live Credits count reported by Codex as points (for example, `238.06 点`), not as a converted dollar balance.

## Persistent desktop bubble

The plugin includes a compact frosted-glass desktop bubble. After running `scripts/start-desktop-widget.sh`, it behaves like a macOS desktop widget: it appears only on the desktop, follows every desktop space, and remembers its dragged position. Snapshot changes are reflected in the bubble within two seconds.

You can add `scripts/start-desktop-widget.sh` as a macOS login item to restore the bubble in its previous position after restarting your Mac.

## Usage

After installation, start a new Codex task and say: “Show my live Codex quota”. Run the live-sync service with:

```bash
python3 scripts/codex_usage_live.py --watch
```

If live sync is temporarily unavailable, the plugin also accepts a manual snapshot. For example:

> Set my Codex remaining quota to 87%, period to 1 week, reset time to 2026-07-25 11:24, and plan to PRO.

The plugin stores manual data in `~/.codex/codex-quota.json`. You can also write it directly:

```json
{
  "remainingPercent": 87,
  "period": "1 week",
  "resetAt": "2026-07-25T11:24:00+08:00",
  "plan": "PRO",
  "source": "manual"
}
```

If Codex provides a supported official quota API in the future, you can use it as the data source and set `source` to that API name.
