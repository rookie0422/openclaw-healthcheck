#!/bin/bash
# OpenClaw Healthcheck - Cron 任务安装脚本
# 用法: ./install-cron.sh [--uninstall] [--interval 15]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
HEALTH_CHECK_SCRIPT="$SCRIPT_DIR/health-check.sh"
LOG_DIR="$PROJECT_DIR/logs"

# 默认检查间隔（分钟）
DEFAULT_INTERVAL=15

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

install_cron() {
    local interval="${1:-$DEFAULT_INTERVAL}"
    
    echo -e "${GREEN}安装 OpenClaw Healthcheck Cron 任务...${NC}"
    
    # 检查脚本是否存在
    if [[ ! -f "$HEALTH_CHECK_SCRIPT" ]]; then
        echo -e "${RED}错误: health-check.sh 脚本未找到${NC}"
        exit 1
    fi
    
    # 确保脚本可执行
    chmod +x "$HEALTH_CHECK_SCRIPT"
    
    # 创建日志目录
    mkdir -p "$LOG_DIR"
    
    # 生成 cron 任务
    local cron_job="*/$interval * * * * $HEALTH_CHECK_SCRIPT --restart --notify >> $LOG_DIR/health-check.log 2>&1"
    
    # 检查是否已存在
    if crontab -l 2>/dev/null | grep -q "health-check.sh"; then
        echo -e "${YELLOW}已存在 health-check cron 任务，正在更新...${NC}"
        # 移除旧的任务
        crontab -l 2>/dev/null | grep -v "health-check.sh" | crontab -
    fi
    
    # 添加新任务
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    
    echo -e "${GREEN}✓ Cron 任务已安装${NC}"
    echo ""
    echo "配置:"
    echo "  检查间隔: 每 $interval 分钟"
    echo "  脚本路径: $HEALTH_CHECK_SCRIPT"
    echo "  日志路径: $LOG_DIR/health-check.log"
    echo ""
    echo "查看任务: crontab -l"
    echo "查看日志: tail -f $LOG_DIR/health-check.log"
    echo ""
    echo "卸载: ./install-cron.sh --uninstall"
}

uninstall_cron() {
    echo -e "${YELLOW}卸载 Cron 任务...${NC}"
    
    if crontab -l 2>/dev/null | grep -q "health-check.sh"; then
        crontab -l 2>/dev/null | grep -v "health-check.sh" | crontab -
        echo -e "${GREEN}✓ Cron 任务已卸载${NC}"
    else
        echo -e "${YELLOW}没有找到 health-check cron 任务${NC}"
    fi
}

show_help() {
    echo "用法: $0 [选项] [间隔分钟]"
    echo ""
    echo "选项:"
    echo "  无参数              安装 cron 任务（默认 15 分钟）"
    echo "  [数字]              安装 cron 任务，指定间隔（如: 30）"
    echo "  --uninstall, -u     卸载 cron 任务"
    echo "  --status, -s        显示 cron 状态"
    echo "  --help, -h          显示帮助"
    echo ""
    echo "示例:"
    echo "  $0                  # 安装，每 15 分钟检查"
    echo "  $0 30               # 安装，每 30 分钟检查"
    echo "  $0 --uninstall      # 卸载"
}

show_status() {
    echo "Cron 任务状态:"
    echo ""
    if crontab -l 2>/dev/null | grep -q "health-check.sh"; then
        crontab -l 2>/dev/null | grep "health-check.sh"
        echo ""
        echo -e "${GREEN}状态: 已安装${NC}"
    else
        echo -e "${YELLOW}状态: 未安装${NC}"
    fi
}

# 主程序
case "${1:-}" in
    --uninstall|-u)
        uninstall_cron
        ;;
    --status|-s)
        show_status
        ;;
    --help|-h)
        show_help
        ;;
    --interval)
        install_cron "${2:-$DEFAULT_INTERVAL}"
        ;;
    *)
        install_cron "${1:-$DEFAULT_INTERVAL}"
        ;;
esac
