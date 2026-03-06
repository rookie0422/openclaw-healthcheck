#!/bin/bash
# OpenClaw Gateway 一键诊断脚本
# 用法: ./doctor.sh [--auto]
# --auto: 自动修复，不询问

set -e

# ============================================================================
# 配置区域 - 根据你的环境修改
# ============================================================================
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
OPENCLAW_BIN="${OPENCLAW_BIN:-$(which openclaw 2>/dev/null || echo '')}"

# ============================================================================
# 颜色定义
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# 工具函数
# ============================================================================
log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_ok() { echo -e "${GREEN}✓${NC} $1"; }
log_err() { echo -e "${RED}✗${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }

# ============================================================================
# 检测函数
# ============================================================================

check_process() {
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

check_api() {
    local port="$1"
    if curl -s --max-time 5 "http://localhost:${port}/health" > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

check_network() {
    # WSL 下 ping 可能不稳定，优先用 curl 测试网络
    if curl -s --max-time 3 https://www.baidu.com > /dev/null 2>&1; then
        return 0
    fi
    # 备用：ping 测试
    if ping -c 1 -W 3 8.8.8.8 > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

check_model_api() {
    # 检查 AI 模型 API 是否可达（SiliconFlow）
    # 只检查 SiliconFlow（你用的是这个），OpenAI 在国内会超时
    local response
    response=$(curl -s --max-time 5 https://api.siliconflow.cn/v1/models 2>&1)
    # 返回任何内容都算可达（包括 "Invalid token" 错误信息，说明 API 服务在线）
    if [[ -n "$response" ]]; then
        return 0
    fi
    return 1
}

is_notify_available() {
    if [[ -z "$OPENCLAW_BIN" ]] || [[ ! -x "$OPENCLAW_BIN" ]]; then
        return 1
    fi
    "$OPENCLAW_BIN" message send --help > /dev/null 2>&1
}

restart_gateway() {
    log_info "正在重启 Gateway..."
    
    # 停止
    if command -v systemctl &> /dev/null; then
        systemctl --user stop openclaw-gateway 2>/dev/null || true
    fi
    pkill -f "openclaw.*gateway" 2>/dev/null || true
    sleep 2
    
    # 启动
    if [[ -n "$OPENCLAW_BIN" ]]; then
        if command -v systemctl &> /dev/null && systemctl --user is-enabled openclaw-gateway &>/dev/null; then
            systemctl --user start openclaw-gateway 2>/dev/null || "$OPENCLAW_BIN" gateway start
        else
            "$OPENCLAW_BIN" gateway start
        fi
    else
        log_err "openclaw 命令未找到"
        return 1
    fi
    sleep 3
    
    # 验证
    if check_process && check_api "$GATEWAY_PORT"; then
        log_ok "重启成功"
        return 0
    else
        log_err "重启失败"
        return 1
    fi
}

send_notification() {
    local message="$1"
    
    if ! is_notify_available; then
        log_warn "通知不可用（未配置消息通道）"
        return 1
    fi
    
    if "$OPENCLAW_BIN" message send --message "$message" > /dev/null 2>&1; then
        log_info "已发送通知"
        return 0
    else
        log_warn "发送通知失败"
        return 1
    fi
}

# ============================================================================
# 主程序
# ============================================================================

main() {
    local auto_fix=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto|-a)
                auto_fix=true
                shift
                ;;
            --help|-h)
                echo "用法: $0 [--auto]"
                echo "  --auto, -a : 自动修复，不询问"
                echo "  --help, -h : 显示帮助"
                echo ""
                echo "注意: 通知功能需要 OpenClaw 已配置消息通道"
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
    
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║      OpenClaw Gateway 一键诊断           ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    
    # 1. 检查进程
    echo -en "🔍 Gateway 进程... "
    if check_process; then
        log_ok "运行中"
        process_ok=true
    else
        log_err "未运行"
        process_ok=false
    fi
    
    # 2. 检查 API
    echo -en "🔍 Gateway API (端口 $GATEWAY_PORT)... "
    if check_api "$GATEWAY_PORT"; then
        log_ok "响应正常"
        api_ok=true
    else
        log_err "无响应"
        api_ok=false
    fi
    
    # 3. 检查模型服务
    echo -en "🔍 AI 模型 API... "
    if check_model_api; then
        log_ok "可达"
        model_ok=true
    else
        log_warn "超时或不可达"
        model_ok=false
    fi
    
    # 4. 检查网络
    echo -en "🔍 网络连接... "
    if check_network; then
        log_ok "正常"
        network_ok=true
    else
        log_err "离线"
        network_ok=false
    fi
    
    # 5. 检查通知能力
    echo -en "🔍 通知渠道... "
    if is_notify_available; then
        log_ok "已配置"
        notify_ok=true
    else
        log_warn "未配置（可选）"
        notify_ok=false
    fi
    
    echo ""
    echo "────────────────────────────────────────────"
    
    # 判断状态
    if [[ "$process_ok" == true ]] && [[ "$api_ok" == true ]]; then
        log_ok "状态正常，一切运行良好"
        echo ""
        echo "如果我不回消息，可能是模型响应慢，稍等片刻或发送 /new 开新会话"
        exit 0
    fi
    
    if [[ "$network_ok" == false ]]; then
        log_err "网络问题，请检查网络连接"
        exit 1
    fi
    
    log_warn "需要修复"
    echo ""
    
    if [[ "$auto_fix" == true ]]; then
        if restart_gateway; then
            send_notification "🤖 OpenClaw Gateway 已自动重启\n\n我可以正常工作了！\n时间: $(date '+%Y-%m-%d %H:%M:%S')"
        else
            send_notification "❌ OpenClaw Gateway 重启失败\n\n请手动检查\n时间: $(date '+%Y-%m-%d %H:%M:%S')"
        fi
        exit 0
    fi
    
    # 询问是否修复
    echo "是否立即重启 Gateway？(y/n)"
    read -r answer
    
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        if restart_gateway; then
            if [[ "$notify_ok" == true ]]; then
                echo ""
                echo "是否发送通知？(y/n)"
                read -r notify
                if [[ "$notify" =~ ^[Yy]$ ]]; then
                    send_notification "🤖 OpenClaw Gateway 已重启\n\n我可以正常工作了！\n时间: $(date '+%Y-%m-%d %H:%M:%S')"
                fi
            fi
        fi
    fi
}

main "$@"
