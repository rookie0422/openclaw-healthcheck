# OpenClaw Healthcheck

OpenClaw Gateway 健康检查工具 - 监控、诊断、自动恢复。

## 功能

- **健康检查** - 定时检测 Gateway 状态，支持自动重启和飞书通知
- **一键诊断** - 快速诊断问题，交互式修复
- **服务安装** - 一键安装 systemd 服务（Linux）

## 快速开始

### 1. 下载

```bash
git clone https://github.com/rookie0422/openclaw-healthcheck.git
cd openclaw-healthcheck
chmod +x scripts/*.sh
```

### 2. 一键诊断

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

────────────────────────────────────────────
✓ 状态正常，一切运行良好
```

### 3. 定时健康检查（可选）

添加到 crontab：

```bash
# 每 15 分钟检查一次，有问题自动重启并发送飞书通知
*/15 * * * * /path/to/openclaw-gateway-tools/scripts/health-check.sh --restart --notify
```

## 脚本说明

### doctor.sh - 一键诊断

```bash
./scripts/doctor.sh           # 交互式诊断
./scripts/doctor.sh --auto    # 自动修复，不询问
```

检查项：
- Gateway 进程状态
- API 响应状态
- AI 模型 API 可达性
- 网络连接

### health-check.sh - 健康检查

```bash
./scripts/health-check.sh              # 仅检查
./scripts/health-check.sh --status     # 输出状态报告
./scripts/health-check.sh --restart    # 有问题时自动重启
./scripts/health-check.sh --restart --notify  # 重启并发送飞书通知
```

### install-service.sh - 安装服务（Linux）

```bash
./scripts/install-service.sh           # 安装 systemd 服务
./scripts/install-service.sh --uninstall  # 卸载服务
```

安装后可用：
```bash
systemctl --user status openclaw-gateway   # 查看状态
journalctl --user -u openclaw-gateway -f   # 查看日志
systemctl --user restart openclaw-gateway  # 重启服务
```

## 配置

通过环境变量配置：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `OPENCLAW_GATEWAY_PORT` | 18789 | Gateway 端口 |
| `OPENCLAW_BIN` | 自动检测 | openclaw 命令路径 |
| `FEISHU_TARGET` | 无 | 飞书通知目标 |

可在脚本头部直接修改，或通过环境变量传入：

```bash
export OPENCLAW_GATEWAY_PORT=18789
export FEISHU_TARGET="user:ou_xxxx"
./scripts/health-check.sh --restart --notify
```

## 文件结构

```
openclaw-gateway-tools/
├── README.md
├── scripts/
│   ├── doctor.sh         # 一键诊断
│   ├── health-check.sh   # 健康检查
│   └── install-service.sh # 安装服务
├── systemd/
│   └── openclaw-gateway.service  # systemd 服务模板
├── docs/
│   └── ...              # 更多文档
└── logs/                # 日志目录（自动创建）
    ├── health-check.log
    └── gateway-status.json
```

## 系统要求

- **Linux** (推荐，支持 systemd 服务)
- **macOS** (支持健康检查和诊断，不支持 systemd)
- **WSL** (支持，但 systemd 可能不稳定)

依赖：
- `curl` - HTTP 请求
- `pgrep` - 进程检测
- `systemctl` - 服务管理（仅 Linux，可选）

## 常见问题

### Gateway 进程检测失败但 API 正常？

这是 WSL 环境下 systemd 不稳定导致的。脚本会优先使用进程检测（`pgrep`），备用 systemd 检测。

### 如何调试？

查看日志：
```bash
tail -f logs/health-check.log
cat logs/gateway-status.json
```

### 飞书通知不工作？

确保 OpenClaw 已配置飞书通道：
```bash
openclaw message send --channel feishu --message "测试通知"
```

## 相关链接

- [OpenClaw 文档](https://docs.openclaw.ai)
- [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [社区 Discord](https://discord.com/invite/clawd)

## License

MIT
