#!/usr/bin/env python3
"""Write a sanitized, live Codex account-usage snapshot for the desktop card.

Uses the local Codex app-server read APIs. Authentication remains inside Codex;
this process never reads, stores, or prints ChatGPT credentials.
"""
from __future__ import annotations

import argparse
import json
import os
import select
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


OUTPUT = Path("~/.codex/codex-quota-live.json").expanduser()
FALLBACK_CODEX = Path("/Applications/ChatGPT.app/Contents/Resources/codex")


def codex_path() -> str:
    return shutil.which("codex") or str(FALLBACK_CODEX)


def send(process: subprocess.Popen[str], message: dict[str, Any]) -> None:
    assert process.stdin is not None
    process.stdin.write(json.dumps(message) + "\n")
    process.stdin.flush()


def receive(process: subprocess.Popen[str], expected: set[int], timeout: float) -> dict[int, Any]:
    assert process.stdout is not None
    received: dict[int, Any] = {}
    deadline = time.monotonic() + timeout
    while expected - received.keys() and time.monotonic() < deadline:
        ready, _, _ = select.select([process.stdout], [], [], max(0, deadline - time.monotonic()))
        if not ready:
            continue
        line = process.stdout.readline()
        if not line:
            break
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            continue
        message_id = message.get("id")
        if isinstance(message_id, int) and message_id in expected:
            if "error" in message:
                raise RuntimeError(message["error"].get("message", "Codex app-server request failed"))
            received[message_id] = message.get("result")
    missing = expected - received.keys()
    if missing:
        raise TimeoutError(f"Timed out waiting for Codex app-server response: {sorted(missing)}")
    return received


def human_period(minutes: int | None) -> str:
    if minutes == 10_080:
        return "1周"
    if not minutes:
        return "未设置"
    if minutes % 1_440 == 0:
        return f"{minutes // 1_440}天"
    if minutes % 60 == 0:
        return f"{minutes // 60}小时"
    return f"{minutes}分钟"


def fetch_snapshot() -> dict[str, Any]:
    binary = codex_path()
    if not Path(binary).exists() and not shutil.which(binary):
        raise FileNotFoundError("找不到 Codex CLI，无法读取实时用量。")
    process = subprocess.Popen(
        [binary, "app-server", "--stdio"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        bufsize=1,
    )
    try:
        send(process, {"id": 1, "method": "initialize", "params": {"clientInfo": {"name": "codex-quota", "version": "1.0.0"}, "capabilities": {"experimentalApi": True}}})
        receive(process, {1}, 8)
        send(process, {"id": 2, "method": "account/rateLimits/read"})
        send(process, {"id": 3, "method": "account/usage/read"})
        send(process, {"id": 4, "method": "account/read", "params": {"refreshToken": False}})
        response = receive(process, {2, 3, 4}, 15)
    finally:
        if process.stdin:
            process.stdin.close()
        process.terminate()
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            process.kill()

    limits = response[2].get("rateLimitsByLimitId", {}).get("codex") or response[2]["rateLimits"]
    primary = limits.get("primary") or {}
    used = float(primary.get("usedPercent", 0))
    resets_at = primary.get("resetsAt")
    reset_label = "未设置"
    if isinstance(resets_at, (int, float)):
        reset_label = datetime.fromtimestamp(resets_at).strftime("%-m月%-d日 %H:%M")
    account = response[4].get("account") or {}
    plan = str(limits.get("planType") or account.get("planType") or "unknown").upper()
    credits = limits.get("credits") or {}
    usage = response[3].get("summary") or {}
    snapshot = {
        "remainingPercent": max(0, min(100, round(100 - used, 1))),
        "period": human_period(primary.get("windowDurationMins")),
        "resetAt": reset_label,
        "plan": plan,
        "source": "Codex app-server",
        "updatedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "credits": {"hasCredits": bool(credits.get("hasCredits")), "unlimited": bool(credits.get("unlimited")), "balance": credits.get("balance")},
        "usage": {key: usage.get(key) for key in ("lifetimeTokens", "peakDailyTokens", "currentStreakDays", "longestStreakDays")},
    }
    return snapshot


def write_snapshot(snapshot: dict[str, Any]) -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    temp = OUTPUT.with_suffix(".tmp")
    temp.write_text(json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temp.replace(OUTPUT)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--watch", action="store_true")
    parser.add_argument("--interval", type=int, default=60)
    args = parser.parse_args()
    while True:
        try:
            write_snapshot(fetch_snapshot())
        except Exception as exc:
            print(f"codex-quota live update failed: {exc}", file=sys.stderr)
        if not args.watch:
            return 0
        time.sleep(max(args.interval, 15))


if __name__ == "__main__":
    raise SystemExit(main())
