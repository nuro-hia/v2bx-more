#!/bin/bash
# ================================================
# Xboard-Node systemd 原生版 管理面板（Naive 专用）
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
    for pkg in curl wget ca-certificates nano; do
        if ! command -v $pkg >/dev/null 2>&1; then
            (apt-get update -qq && apt-get install -y -qq $pkg) >/dev/null 2>&1 || (yum install -y -q $pkg) >/dev/null 2>&1
        fi
    done
}

show_menu() {
    clear
    echo -e "${BLUE}=======================================${NC}"
    echo -e "   🚀 Xboard-Node 管理面板（原生 Dev 分支版）"
    echo -e "${BLUE}=======================================${NC}"
    echo "1. 安装 / 重新对接节点"
    echo "2. 重启节点服务"
    echo "3. 停止节点服务"
    echo "4. 查看实时日志"
    echo "5. 查看节点运行状态"
    echo "6. 彻底卸载 (纯净物理抹除)"
    echo "7. 手动修改配置文件"
    echo "8. 退出"
    echo -e "${BLUE}=======================================${NC}"
    read -p "请输入选项 (1-8): " choice </dev/tty
}

install_node() {
    install_dependencies
    print_info "=== 开始安装 Xboard-Node (Naive 专属) ==="
    
    # 核心防御：-r 参数保证复杂密钥在输入阶段不被 Bash 解析
    read -r -p "请输入面板地址 (https://你的域名): " PANEL </dev/tty
    read -r -p "请输入通讯密钥 (Token): " TOKEN </dev/tty
    read -r -p "请输入节点ID (数字): " NODEID </dev/tty

    if [[ -z "$PANEL" || -z "$TOKEN" || -z "$NODEID" ]]; then
        print_error "输入不能为空。"
        return
    fi

    print_info "正在拉取上游 dev 分支核心..."
    
    # 直接将真实的 TOKEN 交给官方 dev 脚本处理，不做任何阻拦
    if curl -fsSL https://raw.githubusercontent.com/cedar2025/xboard-node/dev/install.sh | sudo bash -s -- --mode node --panel "$PANEL" --token "$TOKEN" --node-id "$NODEID"; then
        hash -r 
        print_success "节点核心部署完成！"
        print_warn "如果日志依然提示 404 handshake，说明 Xboard 面板端未开启或未兼容 V2 路由，请排查面板 Nginx 配置。"
    else
        print_error "官方安装流程遭遇异常，已被迫中止。"
    fi
}

edit_config() {
    if [ -f /etc/xboard-node/config.yml ]; then
        nano /etc/xboard-node/config.yml </dev/tty
        print_success "手动修改完成，请选 2 重启。"
    else
        print_error "配置文件不存在。"
    fi
}

while true; do
    show_menu
    case $choice in
        1) install_node ;;
        2) systemctl restart xboard-node 2>/dev/null && print_success "✅ 节点已重启" || print_error "重启失败" ;;
        3) systemctl stop xboard-node 2>/dev/null && print_success "✅ 节点已停止" || print_error "停止失败" ;;
        4) journalctl -u xboard-node -f </dev/tty ;;
        5) systemctl status xboard-node --no-pager ;;
        6)
            print_warn "⚠️ 即将执行物理清除"
            read -r -p "确认？(y/N): " confirm </dev/tty
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                systemctl stop xboard-node >/dev/null 2>&1 || true
                systemctl disable xboard-node >/dev/null 2>&1 || true
                rm -f /etc/systemd/system/xboard-node.service
                systemctl daemon-reload
                rm -f /usr/local/bin/xboard-node /usr/local/bin/xbctl
                rm -rf /etc/xboard-node
                print_success "✅ 已彻底删除。"
            fi
            ;;
        7) edit_config ;;
        8) exit 0 ;;
        *) print_error "非法选项" ;;
    esac
    echo ""
    read -r -p "按回车键返回主菜单..." </dev/tty
done
