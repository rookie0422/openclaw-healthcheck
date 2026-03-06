#!/bin/bash
# OpenClaw Gateway 健康检查脚本
# 用法: ./health-check.sh [--restart] [--notify] [--status]
# --restart : 如果检测到问题自动重启
# --notify  : 发送通知（需要配置 OpenClaw 消息通道）
# --status  : 仅输出状态报告

set -e

# ============================================================================
# 配置区域 - 根据你的环境修改
# ============================================================================
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
OPENCLAW_BIN="${OPENCLAW_BIN:-$(which openclaw 2>/dev/null || echo '')}"

# 脚本目录（用于日志和状态文件）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="${OPENCLAW_LOG_DIR:-$PROJECT_DIR/logs}"
LOG_FILE="$LOG_DIR/health-check.log"
STATUS_FILE="$LOG_DIR/gateway-status.json"

# ============================================================================
# 日志函数
# ============================================================================
log() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null || true
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# ============================================================================
# 检测函数
# ============================================================================

check_gateway_process() {
    # 优先检查进程（跨平台）
    if pgrep -f "openclaw.*gateway" > /dev/null 2>&1; then
        return 0
    fi
    # 备用：检查 systemd 服务状态（Linux）
    if command -v systemctl &> /dev/null; then
        if systemctl --user is-active --quiet openclaw-gateway 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

check_gateway_api() {
    local port="$1"
    local timeout="${2:-10}"
    if curl -s --max-time "$timeout" "http://localhost:${port}/health" > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

is_notify_available() {
    # 检查是否可以发送通知
    # 1. openclaw 命令存在
    # 2. 已配置消息通道
    if [[ -z "$OPENCLAW_BIN" ]] || [[ ! -x "$OPENCLAW_BIN" ]]; then
        return 1
    fi
    
    # 尝试检查配置（静默）
    if "$OPENCLAW_BIN" message send --help > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

# ============================================================================
# 操作函数
# ============================================================================

send_notification() {
    local message="$1"
    
    if ! is_notify_available; then
        log "⚠️  通知不可用，跳过发送（未配置消息通道或 openclaw 命令不可用）"
        return 1
    fi
    
    # 尝试发送通知，失败时静默处理
    if "$OPENCLAW_BIN" message send --message "$message" > /dev/null 2>&1; then
        log "📤 已发送通知"
        return 0
    else
        log "⚠️  发送通知失败"
        return 1
    fi
}

restart_gateway() {
    log "🔄 正在重启 Gateway..."
    
    # 停止
    if command -v systemctl &> /dev/null; then
        systemctl --user stop openclaw-gateway 2>/dev/null || true
    fi
    pkill -f "openclaw.*gateway" 2>/dev/null || true
    sleep 2
    
    # 启动
    if [[ -n "$OPENCLAW_BIN" ]]; then
        if command -v systemctl &> /dev/null && systemctl --user is-enabled openclaw-gateway &>/dev/null; then
            systemctl --user restart openclaw-gateway 2>/dev/null || "$OPENCLAW_BIN" gateway start
        else
            "$OPENCLAW_BIN" gateway start
        fi
    else
        log "❌ openclaw 命令未找到，无法重启"
        return 1
    fi
    sleep 3
    
    # 验证
    if check_gateway_process; then
        log "✅ Gateway 重启成功"
        return 0
    else
        log "❌ Gateway 重启失败"
        return 1
    fi
}

generate_status() {
    local gateway_running="false"
    local api_healthy="false"
    
    check_gateway_process && gateway_running="true"
    check_gateway_api "$GATEWAY_PORT" && api_healthy="true"
    
    mkdir -p "$(dirname "$STATUS_FILE")" 2>/dev/null || true
    cat > "$STATUS_FILE" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "gateway_running": $gateway_running,
    "api_healthy": $api_healthy,
    "port": $GATEWAY_PORT,
    "status": "$([ "$gateway_running" = "true" ] && echo "running" || echo "stopped")"
}
EOF
    
    echo "Gateway 进程: $gateway_running"
    echo "API 响应:     $api_healthy"
    echo "端口:         $GATEWAY_PORT"
}

# ============================================================================
# 主程序
# ============================================================================

main() {
    local auto_restart=false
    local do_notify=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --restart|-r)
                auto_restart=true
                shift
                ;;
            --notify|-n)
                do_notify=true
                shift
                ;;
            --status|-s)
                generate_status
                exit 0
                ;;
            --help|-h)
                echo "用法: $0 [选项]"
                echo ""
                echo "选项:"
                echo "  --restart, -r  检测到问题时自动重启"
                echo "  --notify,  -n  发送通知（需要配置 OpenClaw 消息通道）"
                echo "  --status,  -s  仅输出状态报告"
                echo "  --help,    -h  显示帮助"
                echo ""
                echo "注意:"
                echo "  --notify 需要 OpenClaw 已配置消息通道（如飞书）"
                echo "  如果未配置，将自动跳过通知步骤"
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
    
    log "=== 健康检查开始 ==="
    generate_status
    
    local has_issue=false
    
    if ! check_gateway_process; then
        log "❌ Gateway 进程未运行"
        has_issue=true
    elif ! check_gateway_api "$GATEWAY_PORT"; then
        log "⚠️  Gateway API 无响应"
        has_issue=true
    else
        log "✅ Gateway 状态正常"
    fi
    
    # 自动重启
    if [[ "$has_issue" == true ]] && [[ "$auto_restart" == true ]]; then
        if restart_gateway; then
            if [[ "$do_notify" == true ]]; then
                send_notification "✅ Gateway 已自动重启，我可以正常工作了！

如有待处理任务请重新发送。
时间: $(date '+%Y-%m-%d %H:%M:%S')"
            fi
        else
            if [[ "$do_notify" == true ]]; then
                send_notification "❌ Gateway 重启失败，请手动检查！

执行: openclaw gateway restart
时间: $(date '+%Y-%m-%d %H:%M:%S')"
            fi
        fi
    fi
    
    log "=== 健康检查结束 ==="
    
    [[ "$has_issue" == true ]] && exit 1 || exit 0
}

main "$@"
