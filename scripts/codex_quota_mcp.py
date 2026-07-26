#!/usr/bin/env python3
"""Small, dependency-free MCP server for a local Codex quota snapshot.

The Codex client does not expose a public account-usage API to plugins. This
server therefore only reads a user-managed JSON snapshot; it never reads
credentials or claims the numbers are live.
"""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


MANUAL_DATA_FILE = Path("~/.codex/codex-quota.json").expanduser()
LIVE_DATA_FILE = Path("~/.codex/codex-quota-live.json").expanduser()
DATA_FILE = Path(os.environ.get("CODEX_QUOTA_FILE", str(MANUAL_DATA_FILE))).expanduser()

SCHEMA = {
    "type": "object",
    "properties": {
        "remainingPercent": {
            "type": "number",
            "minimum": 0,
            "maximum": 100,
            "description": "Remaining quota, from 0 to 100.",
        },
        "period": {"type": "string", "description": "For example: 1 周."},
        "resetAt": {
            "type": "string",
            "description": "Reset time, preferably ISO 8601 with timezone.",
        },
        "plan": {"type": "string", "description": "For example: PRO."},
        "source": {
            "type": "string",
            "description": "How the snapshot was obtained. Default: manual.",
        },
    },
    "required": ["remainingPercent"],
    "additionalProperties": False,
}


def now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def load_snapshot() -> dict[str, Any] | None:
    files = [DATA_FILE] if "CODEX_QUOTA_FILE" in os.environ else [LIVE_DATA_FILE, MANUAL_DATA_FILE]
    for file in files:
        if not file.exists():
            continue
        try:
            raw = json.loads(file.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise ValueError(f"无法读取额度文件 {file}: {exc}") from exc
        if not isinstance(raw, dict):
            raise ValueError("额度文件必须是 JSON 对象。")
        return raw
    return None


def validate(snapshot: dict[str, Any]) -> dict[str, Any]:
    value = snapshot.get("remainingPercent")
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not 0 <= value <= 100:
        raise ValueError("remainingPercent 必须是 0 到 100 之间的数字。")
    snapshot["remainingPercent"] = round(float(value), 1)
    for key in ("period", "resetAt", "plan", "source", "updatedAt"):
        if key in snapshot and not isinstance(snapshot[key], str):
            raise ValueError(f"{key} 必须是字符串。")
    snapshot.setdefault("source", "manual")
    return snapshot


def card(snapshot: dict[str, Any]) -> str:
    remaining = snapshot["remainingPercent"]
    used = round(100 - remaining, 1)
    filled = round(remaining / 10)
    bar = "●" * filled + "○" * (10 - filled)
    lines = [
        "Codex 额度  ·  手动快照",
        f"{bar}  {remaining:g}% 剩余（已用 {used:g}%）",
        f"周期：{snapshot.get('period', '未设置')}",
        f"重置：{snapshot.get('resetAt', '未设置')}",
        f"套餐：{snapshot.get('plan', '未设置')}",
        f"来源：{snapshot.get('source', 'manual')}",
        f"更新：{snapshot.get('updatedAt', '未知')}",
    ]
    return "\n".join(lines)


def result(text: str, data: dict[str, Any] | None = None, is_error: bool = False) -> dict[str, Any]:
    response: dict[str, Any] = {"content": [{"type": "text", "text": text}]}
    if data is not None:
        response["structuredContent"] = data
    if is_error:
        response["isError"] = True
    return response


def handle_tool(name: str, arguments: dict[str, Any]) -> dict[str, Any]:
    if name == "get_codex_quota":
        snapshot = load_snapshot()
        if snapshot is None:
            return result(
                "尚未配置额度快照。请调用 set_codex_quota，或在 "
                f"{MANUAL_DATA_FILE} 创建 JSON 文件，或启动实时同步服务。"
                "因此本插件不会猜测或伪造实时额度。"
            )
        snapshot = validate(snapshot)
        return result(card(snapshot), snapshot)

    if name == "set_codex_quota":
        snapshot = validate(dict(arguments))
        snapshot["updatedAt"] = now()
        DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
        DATA_FILE.write_text(json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        return result("已保存本地额度快照。\n\n" + card(snapshot), snapshot)

    return result(f"未知工具：{name}", is_error=True)


TOOLS = [
    {
        "name": "get_codex_quota",
        "description": "读取本地 Codex 额度快照并生成一张简洁的额度卡片。",
        "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
    },
    {
        "name": "set_codex_quota",
        "description": "保存用户提供的 Codex 额度快照。数值不会被当作官方实时数据。",
        "inputSchema": SCHEMA,
    },
]


def send(message: dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(message, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def main() -> None:
    for line in sys.stdin:
        try:
            request = json.loads(line)
            method = request.get("method")
            request_id = request.get("id")
            if method == "initialize":
                response = {
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "result": {
                        "protocolVersion": request.get("params", {}).get("protocolVersion", "2024-11-05"),
                        "capabilities": {"tools": {}},
                        "serverInfo": {"name": "codex-quota", "version": "0.1.0"},
                    },
                }
            elif method == "tools/list":
                response = {"jsonrpc": "2.0", "id": request_id, "result": {"tools": TOOLS}}
            elif method == "tools/call":
                params = request.get("params", {})
                response = {
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "result": handle_tool(params.get("name", ""), params.get("arguments", {})),
                }
            elif request_id is not None:
                response = {"jsonrpc": "2.0", "id": request_id, "error": {"code": -32601, "message": "Method not found"}}
            else:
                continue
            send(response)
        except Exception as exc:  # Keep MCP transport alive on malformed input.
            if "request_id" in locals() and request_id is not None:
                send({"jsonrpc": "2.0", "id": request_id, "error": {"code": -32603, "message": str(exc)}})


if __name__ == "__main__":
    main()
