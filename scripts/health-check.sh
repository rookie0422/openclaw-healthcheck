#!/bin/bash
# OpenClaw Gateway 健康检查脚本
# 用法: ./health-check.sh [--restart] [--notify] [--status]
# --restart : 如果检测到问题自动重启
# --notify  : 发送飞书通知
# --status  : 仅输出状态报告

set -e

# ============================================================================
# 配置区域 - 根据你的环境修改
# ============================================================================
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
OPENCLAW_BIN="${OPENCLAW_BIN:-$(which openclaw 2>/dev/null || echo '/usr/local/bin/openclaw')}"

# 脚本目录（用于日志和状态文件）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${OPENCLAW_LOG_DIR:-$SCRIPT_DIR/../logs}"
LOG_FILE="$LOG_DIR/health-check.log"
STATUS_FILE="$LOG_DIR/gateway-status.json"

# 飞书通知目标 (open_id 或 user_id)
FEISHU_TARGET="${FEISHU_TARGET:-}"

# ============================================================================
# 日志函数
# ============================================================================
log() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# ============================================================================
# 检测函数
# ============================================================================

check_gateway_process() {
    # WSL/Linux/Mac 通用：优先检查进程
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

check_log_activity() {
    local log_path="$1"
    local seconds="${2:-60}"
    
    if [[ -f "$log_path" ]]; then
        if find "$log_path" -mmin -$((seconds/60)) 2>/dev/null | grep -q .; then
            return 0
        fi
    fi
    return 1
}

# ============================================================================
# 操作函数
# ============================================================================

send_notification() {
    local message="$1"
    
    if [[ -n "$FEISHU_TARGET" ]]; then
        "$OPENCLAW_BIN" message send \
            --channel feishu \
            --target "$FEISHU_TARGET" \
            --message "$message" > /dev/null 2>&1
    else
        "$OPENCLAW_BIN" message send \
            --channel feishu \
            --message "$message" > /dev/null 2>&1
    fi
    
    log "已发送通知"
}

restart_gateway() {
    log "正在重启 Gateway..."
    
    # 停止
    if command -v systemctl &> /dev/null; then
        systemctl --user stop openclaw-gateway 2>/dev/null || true
    fi
    pkill -f "openclaw.*gateway" 2>/dev/null || true
    sleep 2
    
    # 启动
    if command -v systemctl &> /dev/null && systemctl --user is-enabled openclaw-gateway &>/dev/null; then
        systemctl --user restart openclaw-gateway 2>/dev/null || "$OPENCLAW_BIN" gateway start
    else
        "$OPENCLAW_BIN" gateway start
    fi
    sleep 3
    
    # 验证
    if check_gateway_process; then
        log "Gateway 重启成功"
        return 0
    else
        log "错误: Gateway 重启失败"
        return 1
    fi
}

generate_status() {
    local gateway_running="false"
    local api_healthy="false"
    
    check_gateway_process && gateway_running="true"
    check_gateway_api "$GATEWAY_PORT" && api_healthy="true"
    
    mkdir -p "$(dirname "$STATUS_FILE")"
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
    local notify=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --restart|-r)
                auto_restart=true
                shift
                ;;
            --notify|-n)
                notify=true
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
                echo "  --notify,  -n  发送飞书通知"
                echo "  --status,  -s  仅输出状态报告"
                echo "  --help,    -h  显示帮助"
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
            if [[ "$notify" == true ]]; then
                send_notification "✅ Gateway 已自动重启，我可以正常工作了！\n\n如有待处理任务请重新发送。\n时间: $(date '+%Y-%m-%d %H:%M:%S')"
            fi
        else
            if [[ "$notify" == true ]]; then
                send_notification "❌ Gateway 重启失败，请手动检查！\n\n执行: openclaw gateway restart\n时间: $(date '+%Y-%m-%d %H:%M:%S')"
            fi
        fi
    fi
    
    log "=== 健康检查结束 ==="
    
    [[ "$has_issue" == true ]] && exit 1 || exit 0
}

main "$@"
