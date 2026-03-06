#!/bin/bash
# OpenClaw Gateway 服务安装脚本
# 用法: ./install-service.sh [--uninstall]

set -e

SERVICE_NAME="openclaw-gateway"
SERVICE_FILE="$SERVICE_NAME.service"
SYSTEMD_DIR="$HOME/.config/systemd/user"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

install_service() {
    echo -e "${GREEN}安装 OpenClaw Gateway 服务...${NC}"
    
    # 检查 openclaw 命令
    if ! command -v openclaw &> /dev/null; then
        echo -e "${RED}错误: openclaw 命令未找到${NC}"
        echo "请先安装 OpenClaw: npm install -g openclaw"
        exit 1
    fi
    
    # 创建目录
    mkdir -p "$SYSTEMD_DIR"
    
    # 获取 openclaw 路径
    OPENCLAW_PATH=$(which openclaw)
    
    # 生成服务文件
    cat > "$SYSTEMD_DIR/$SERVICE_FILE" << EOF
[Unit]
Description=OpenClaw Gateway - AI Assistant Backend
Documentation=https://docs.openclaw.ai
After=network.target

[Service]
Type=simple
ExecStart=$OPENCLAW_PATH gateway --port 18789
Restart=on-failure
RestartSec=5
Environment=OPENCLAW_GATEWAY_PORT=18789

[Install]
WantedBy=default.target
EOF
    
    echo -e "${GREEN}✓ 服务文件已创建${NC}"
    
    # 重载 systemd
    systemctl --user daemon-reload
    echo -e "${GREEN}✓ systemd 已重载${NC}"
    
    # 启用服务
    systemctl --user enable "$SERVICE_NAME"
    echo -e "${GREEN}✓ 服务已启用${NC}"
    
    # 启动服务
    systemctl --user start "$SERVICE_NAME"
    echo -e "${GREEN}✓ 服务已启动${NC}"
    
    echo ""
    echo -e "${GREEN}安装完成！${NC}"
    echo ""
    echo "常用命令:"
    echo "  查看状态: systemctl --user status $SERVICE_NAME"
    echo "  查看日志: journalctl --user -u $SERVICE_NAME -f"
    echo "  重启服务: systemctl --user restart $SERVICE_NAME"
    echo "  停止服务: systemctl --user stop $SERVICE_NAME"
}

uninstall_service() {
    echo -e "${YELLOW}卸载 OpenClaw Gateway 服务...${NC}"
    
    systemctl --user stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl --user disable "$SERVICE_NAME" 2>/dev/null || true
    rm -f "$SYSTEMD_DIR/$SERVICE_FILE"
    systemctl --user daemon-reload
    
    echo -e "${GREEN}✓ 服务已卸载${NC}"
}

# 主程序
case "${1:-}" in
    --uninstall|-u)
        uninstall_service
        ;;
    --help|-h)
        echo "用法: $0 [--uninstall]"
        echo "  --uninstall, -u  卸载服务"
        exit 0
        ;;
    *)
        install_service
        ;;
esac
