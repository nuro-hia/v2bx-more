#!/bin/bash
# ================================================
# Xboard-Node systemd 原生版 管理面板
# 纯净对接 dev 分支 / 兼容高强度密钥
# ================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [ ! -t 0 ] && [ ! -c /dev/tty ]; then
    print_error "当前执行环境无 TTY 终端，交互阻断。"
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    print_error "请使用 root 或 sudo 运行此脚本！"
    exit 1
fi

install_dependencies() {
    print_info "正在补全底层依赖..."

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
            curl wget ca-certificates nano systemd
    elif command -v yum >/dev/null 2>&1; then
        yum install -y -q \
            curl wget ca-certificates nano systemd
    else
        print_error "不支持的系统：未找到 apt-get 或 yum"
        return 1
    fi
}

show_menu() {
    clear
    echo -e "${BLUE}=======================================${NC}"
    echo -e "   🚀 Xboard-Node 管理面板"
    echo -e "${BLUE}=======================================${NC}"
    echo "1. 安装 / 重新对接节点"
    echo "2. 重启节点服务"
    echo "3. 停止节点服务"
    echo "4. 查看实时日志"
    echo "5. 查看节点运行状态"
    echo "6. 彻底卸载"
    echo "7. 手动修改配置文件"
    echo "8. 退出"
    echo -e "${BLUE}=======================================${NC}"
    read -r -p "请输入选项 (1-8): " choice </dev/tty
}

install_node() {
    install_dependencies || return 1

    print_info "=== 开始安装 Xboard-Node ==="

    read -r -p "请输入面板地址 (https://你的域名): " PANEL </dev/tty
    read -r -p "请输入通讯密钥 (Token): " TOKEN </dev/tty
    read -r -p "请输入节点ID (数字): " NODEID </dev/tty

    if [[ -z "$PANEL" || -z "$TOKEN" || -z "$NODEID" ]]; then
        print_error "输入不能为空。"
        return 1
    fi

    if ! [[ "$PANEL" =~ ^https?:// ]]; then
        print_error "面板地址必须以 http:// 或 https:// 开头。"
        return 1
    fi

    if ! [[ "$NODEID" =~ ^[0-9]+$ ]]; then
        print_error "节点 ID 必须是数字。"
        return 1
    fi

    print_info "正在拉取上游 dev 分支核心..."

    if curl -fsSL https://raw.githubusercontent.com/cedar2025/xboard-node/dev/install.sh | bash -s -- --mode node --panel "$PANEL" --token "$TOKEN" --node-id "$NODEID"; then
        hash -r
        systemctl daemon-reload >/dev/null 2>&1 || true

        print_success "节点核心部署完成！"

        echo ""
        print_info "当前服务状态："
        systemctl status xboard-node --no-pager || true

        echo ""
        print_warn "如果日志提示 404 / handshake / ws disconnected，优先检查："
        print_warn "1. 面板地址是否正确"
        print_warn "2. 通讯密钥 Token 是否正确"
        print_warn "3. 节点 ID 是否对应面板后台真实节点"
        print_warn "4. 面板反代是否支持 WebSocket"
        print_warn "5. Xboard 面板版本是否支持当前 Xboard-Node dev 分支"
    else
        print_error "官方安装流程遭遇异常，已中止。"
        return 1
    fi
}

restart_node() {
    if systemctl restart xboard-node 2>/dev/null; then
        print_success "✅ 节点已重启"
    else
        print_error "重启失败，请查看日志：journalctl -u xboard-node -n 100 --no-pager"
    fi
}

stop_node() {
    if systemctl stop xboard-node 2>/dev/null; then
        print_success "✅ 节点已停止"
    else
        print_error "停止失败，服务可能不存在。"
    fi
}

show_logs() {
    if systemctl list-unit-files | grep -q '^xboard-node\.service'; then
        journalctl -u xboard-node -f </dev/tty
    else
        print_error "xboard-node 服务不存在。"
    fi
}

show_status() {
    if systemctl list-unit-files | grep -q '^xboard-node\.service'; then
        systemctl status xboard-node --no-pager
    else
        print_error "xboard-node 服务不存在。"
    fi
}

edit_config() {
    if [ -f /etc/xboard-node/config.yml ]; then
        nano /etc/xboard-node/config.yml </dev/tty
        print_success "手动修改完成，请选 2 重启服务。"
    else
        print_error "配置文件不存在：/etc/xboard-node/config.yml"
    fi
}

uninstall_node() {
    print_warn "⚠️ 即将彻底卸载 Xboard-Node"
    print_warn "将删除：服务文件、主程序、xbctl、/etc/xboard-node 配置目录"
    read -r -p "确认卸载？(y/N): " confirm </dev/tty

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_warn "已取消卸载。"
        return 0
    fi

    systemctl stop xboard-node >/dev/null 2>&1 || true
    systemctl disable xboard-node >/dev/null 2>&1 || true

    rm -f /etc/systemd/system/xboard-node.service
    rm -f /usr/local/bin/xboard-node
    rm -f /usr/local/bin/xbctl
    rm -rf /etc/xboard-node

    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl reset-failed xboard-node >/dev/null 2>&1 || true

    print_success "✅ Xboard-Node 已彻底删除。"
}

while true; do
    show_menu

    case "$choice" in
        1)
            install_node
            ;;
        2)
            restart_node
            ;;
        3)
            stop_node
            ;;
        4)
            show_logs
            ;;
        5)
            show_status
            ;;
        6)
            uninstall_node
            ;;
        7)
            edit_config
            ;;
        8)
            exit 0
            ;;
        *)
            print_error "非法选项"
            ;;
    esac

    echo ""
    read -r -p "按回车键返回主菜单..." </dev/tty
done
