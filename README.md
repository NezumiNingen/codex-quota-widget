# Codex 额度

一个 macOS 桌面气泡插件，实时展示当前 Codex 套餐、额度剩余、重置时间和用量进度。

## 真实数据边界

实时同步通过本机 Codex app-server 的只读账户接口获取套餐、额度、重置时间、Credits 和 token 用量。它不会读取、保存或显示登录令牌和邮箱；同步结果仅保存在 `~/.codex/codex-quota-live.json`。桌面气泡会自动读取这一快照。

## 常驻桌面卡片

插件附带一个紧凑的常驻桌面玻璃气泡。运行 `scripts/start-desktop-widget.sh` 后，它会像 macOS 桌面小组件一样只显示在桌面、自动跟随到所有桌面空间，并记住拖动位置；本地快照变更后最多两秒同步到卡片。

可将 `scripts/start-desktop-widget.sh` 配置为 macOS 登录启动项，以便重启后自动恢复到上次停留的位置。

## 使用

安装后，在新任务中说“查看我的 Codex 实时额度”。实时同步服务可运行：

```bash
python3 scripts/codex_usage_live.py --watch
```

如果实时服务暂不可用，插件也支持手动快照。可说：

> 把我的 Codex 剩余额度设为 87%，周期 1 周，重置时间 2026-07-25 11:24，套餐 PRO。

插件会把数据保存为 `~/.codex/codex-quota.json`。也可以自行写入：

```json
{
  "remainingPercent": 87,
  "period": "1 周",
  "resetAt": "2026-07-25T11:24:00+08:00",
  "plan": "PRO",
  "source": "manual"
}
```

如未来 Codex 提供受支持的官方额度 API，可将数据源接入该 API，并把 `source` 设为 API 名称。
