#!/bin/bash
# ================================================
# Xboard-Node systemd 原生版 一键管理脚本（Naive 专用）
# 作者：Grok 团队定制（2026最新版）
# 适用于 GitHub 直接使用
# 支持自动依赖安装 + 彻底干净卸载
# ================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
    print_error "请使用 root 或 sudo 运行此脚本！"
    exit 1
fi

# 自动安装依赖
install_dependencies() {
    print_info "正在检查并安装必要依赖..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq
        apt-get install -y -qq curl wget ca-certificates
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y curl wget ca-certificates
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl wget ca-certificates
    else
        print_warn "无法识别包管理器，请手动安装 curl wget ca-certificates"
    fi
    print_success "依赖安装完成"
}

# 显示菜单
show_menu() {
    clear
    echo -e "${BLUE}=======================================${NC}"
    echo -e "   🚀 Xboard-Node systemd 管理脚本（Naive 专用）"
    echo -e "${BLUE}=======================================${NC}"
    echo "1. 安装 / 重新对接节点（首次使用）"
    echo "2. 重启节点"
    echo "3. 停止节点"
    echo "4. 查看实时日志"
    echo "5. 查看节点状态"
    echo "6. 更新节点到最新版"
    echo "7. 修改配置（面板地址/密钥/NodeID）"
    echo "8. 彻底卸载（干净删除所有文件）"
    echo "9. 退出"
    echo -e "${BLUE}=======================================${NC}"
    read -p "请输入选项 (1-9): " choice
}

# 安装节点
install_node() {
    install_dependencies
    print_info "=== 开始安装 Xboard-Node（systemd 原生版）==="
    read -p "请输入面板地址 (https://你的域名): " PANEL
    read -p "请输入通讯密钥 (ApiKey/Token): " TOKEN
    read -p "请输入节点ID (数字): " NODEID

    print_info "正在调用官方安装脚本..."
    curl -fsSL https://raw.githubusercontent.com/cedar2025/xboard-node/dev/install.sh | \
      sudo bash -s -- --mode node \
      --panel "$PANEL" \
      --token "$TOKEN" \
      --node-id "$NODEID"

    print_success "✅ 安装完成！"
    print_info "请在 Xboard 后台 → 节点管理 刷新状态（应显示在线）"
    print_info "Naive 节点需在面板里把协议类型设为 Naive（sing-box 内核自动支持）"
}

case "$1" in
    install|1)
        install_node
        ;;
    *)
        while true; do
            show_menu
            case $choice in
                1) install_node ;;
                2)
                    systemctl restart xboard-node && print_success "✅ 节点已重启"
                    ;;
                3)
                    systemctl stop xboard-node && print_success "✅ 节点已停止"
                    ;;
                4)
                    journalctl -u xboard-node -f
                    ;;
                5)
                    systemctl status xboard-node --no-pager
                    xbctl status 2>/dev/null || print_info "使用 systemctl 查看"
                    ;;
                6)
                    print_info "正在更新..."
                    # 官方支持通过重新安装实现更新
                    install_node
                    ;;
                7)
                    print_info "打开配置文件（nano）..."
                    nano /etc/xboard-node/config.yml
                    print_info "修改完成后请选 2 重启节点"
                    ;;
                8)
                    print_warn "⚠️ 即将彻底卸载（删除所有文件和服务）"
                    read -p "确认卸载？(y/N): " confirm
                    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                        print_info "停止并禁用服务..."
                        systemctl stop xboard-node 2>/dev/null || true
                        systemctl disable xboard-node 2>/dev/null || true
                        rm -f /etc/systemd/system/xboard-node.service
                        systemctl daemon-reload

                        print_info "删除二进制和 CLI..."
                        rm -f /usr/local/bin/xboard-node /usr/local/bin/xbctl /usr/bin/xbctl

                        print_info "删除配置目录..."
                        rm -rf /etc/xboard-node

                        print_success "✅ 彻底卸载完成！所有文件已清理干净"
                    else
                        print_info "已取消卸载"
                    fi
                    ;;
                9) exit 0 ;;
                *) print_error "输入错误，请重试" ;;
            esac
            echo ""
            read -p "按回车键继续..."
        done
        ;;
esac
