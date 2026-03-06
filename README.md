# OpenClaw Healthcheck

OpenClaw Gateway 健康检查工具 - 监控、诊断、自动恢复。

## 解决什么问题？

当你在使用 OpenClaw（AI 助手）时，可能会遇到以下情况：

1. **Gateway 进程意外退出** - AI 助手停止响应
2. **API 卡死** - 发消息后无响应
3. **不知道该怎么排查** - 不确定是网络问题还是服务问题

这个工具帮你：
- 🔍 **快速诊断** - 一键检查 Gateway 状态、API、网络连通性
- 🔄 **自动恢复** - 检测到问题时自动重启 Gateway
- 📢 **及时通知** - 重启后通过飞书等渠道通知你
- ⏰ **定时监控** - 通过 cron 定时检查，无需人工干预

## 功能

| 脚本 | 功能 | 用途 |
|------|------|------|
| `doctor.sh` | 一键诊断 | 手动排查问题，交互式修复 |
| `health-check.sh` | 健康检查 | 定时任务用，自动检测+重启 |
| `install-cron.sh` | 安装定时任务 | 配置定时健康检查 |

> ⚠️ **注意：本工具不会安装或卸载 OpenClaw，也不会修改 OpenClaw 的配置。**
> 它只监控现有的 OpenClaw Gateway 服务，在检测到问题时尝试重启。

## 快速开始

### 1. 下载

```bash
git clone https://github.com/rookie0422/openclaw-healthcheck.git
cd openclaw-healthcheck
chmod +x scripts/*.sh
```

### 2. 一键诊断

当你发现 AI 助手不响应时，运行：

```bash
./scripts/doctor.sh
```

输出示例：
```
╔══════════════════════════════════════════╗
║      OpenClaw Gateway 一键诊断           ║
╚══════════════════════════════════════════╝

🔍 Gateway 进程... ✓ 运行中
🔍 Gateway API (端口 18789)... ✓ 响应正常
🔍 AI 模型 API... ✓ 可达
🔍 网络连接... ✓ 正常
🔍 通知渠道... ✓ 已配置

────────────────────────────────────────────
✓ 状态正常，一切运行良好
```

如果发现问题，脚本会提示你是否重启 Gateway。

### 3. 设置定时监控（推荐）

让脚本每 15 分钟自动检查一次，发现问题自动重启并发通知：

```bash
./scripts/install-cron.sh
```

## 脚本详细说明

### doctor.sh - 一键诊断

交互式诊断工具，适合手动排查问题。

```bash
./scripts/doctor.sh           # 交互式诊断
./scripts/doctor.sh --auto    # 自动修复，不询问
./scripts/doctor.sh --help    # 显示帮助
```

检查项：
- ✅ Gateway 进程状态
- ✅ API 响应状态
- ✅ AI 模型 API 可达性
- ✅ 网络连接
- ✅ 通知渠道配置

### health-check.sh - 健康检查

非交互式，适合 cron 定时任务。

```bash
./scripts/health-check.sh              # 仅检查并记录日志
./scripts/health-check.sh --status     # 输出状态报告
./scripts/health-check.sh --restart    # 有问题时自动重启
./scripts/health-check.sh --restart --notify  # 重启并发送通知
```

### install-cron.sh - 安装定时任务

```bash
./scripts/install-cron.sh              # 安装，每 15 分钟检查
./scripts/install-cron.sh --interval 30   # 每 30 分钟检查
./scripts/install-cron.sh --uninstall  # 卸载
./scripts/install-cron.sh --status     # 查看状态
```

## 配置

### 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `OPENCLAW_GATEWAY_PORT` | 18789 | Gateway 端口 |
| `OPENCLAW_BIN` | 自动检测 | openclaw 命令路径 |

可在脚本头部直接修改，或通过环境变量传入：

```bash
export OPENCLAW_GATEWAY_PORT=18789
./scripts/doctor.sh
```

### 通知配置

脚本通过 OpenClaw 已配置的消息通道发送通知。如果未配置通知渠道，脚本会**自动跳过通知步骤**，不影响其他功能。

**检查通知是否可用：**
```bash
openclaw message send --message "测试通知"
```

## 文件结构

```
openclaw-healthcheck/
├── README.md                           # 使用文档
├── LICENSE                             # MIT
├── scripts/
│   ├── doctor.sh                       # 一键诊断
│   ├── health-check.sh                 # 健康检查
│   └── install-cron.sh                 # 安装定时任务
├── docs/                               # 更多文档（预留）
└── logs/                               # 日志目录（自动创建）
    ├── health-check.log                # 健康检查日志
    └── gateway-status.json             # 状态快照
```

## 系统要求

| 系统 | 支持 | 说明 |
|------|------|------|
| Linux | ✅ 完全支持 | 支持 systemd 服务 |
| macOS | ✅ 基本支持 | 不支持 systemd，其他功能正常 |
| WSL | ✅ 支持 | systemd 可能不稳定，但检测功能正常 |

依赖：
- `curl` - HTTP 请求（必需）
- `pgrep` - 进程检测（必需）
- `systemctl` - 服务管理（仅 Linux，可选）

## 常见问题

### Gateway 进程检测失败但 API 正常？

这是 WSL 环境下 systemd 不稳定导致的。脚本会优先使用进程检测（`pgrep`），备用 systemd 检测。如果 API 正常，说明服务实际上在运行。

### 通知不工作？

确保 OpenClaw 已配置消息通道：
```bash
# 测试通知
openclaw message send --message "测试"
```

如果未配置，脚本会显示"通知渠道未配置"，但不会影响诊断和重启功能。

### 如何查看日志？

```bash
# 查看健康检查日志
tail -f logs/health-check.log

# 查看状态快照
cat logs/gateway-status.json
```

### 定时任务没执行？

检查 cron 服务：
```bash
# 查看定时任务
crontab -l

# 检查 cron 日志
grep CRON /var/log/syslog | tail -20
```

## 相关链接

- [OpenClaw 文档](https://docs.openclaw.ai)
- [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [社区 Discord](https://discord.com/invite/clawd)
- [问题反馈](https://github.com/rookie0422/openclaw-healthcheck/issues)

## License

MIT
