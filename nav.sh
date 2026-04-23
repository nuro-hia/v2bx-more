#!/bin/bash
# ================================================
# Xboard-Node systemd 原生版 管理面板（Naive 专用）
# 修复 V2 API 404 断层 / 解决 curl 管道流阻断
# ================================================

# 移除危险的 set -e，确保交互式菜单不死

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查 TTY 交互能力 (防 curl | bash 假死)
if [ ! -t 0 ] && [ ! -c /dev/tty ]; then
    print_error "当前执行环境无 TTY 终端，交互阻断。"
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    print_error "请使用 root 或 sudo 运行此脚本！"
    exit 1
fi

install_dependencies() {
    print_info "正在静默检查并补全底层依赖..."
    for pkg in curl wget ca-certificates nano; do
        if ! command -v $pkg >/dev/null 2>&1; then
            (apt-get update -qq && apt-get install -y -qq $pkg) >/dev/null 2>&1 || (yum install -y -q $pkg) >/dev/null 2>&1
        fi
    done
}

show_menu() {
    clear
    echo -e "${BLUE}=======================================${NC}"
    echo -e "   🚀 Xboard-Node systemd 管理面板（Naive 专用）"
    echo -e "${BLUE}=======================================${NC}"
    echo "1. 安装 / 重新对接节点 (匹配稳定版 API)"
    echo "2. 重启节点"
    echo "3. 停止节点"
    echo "4. 查看实时日志"
    echo "5. 查看节点状态"
    echo "6. 彻底卸载 (纯净物理抹除)"
    echo "7. 修改配置文件"
    echo "8. 退出"
    echo -e "${BLUE}=======================================${NC}"
    read -p "请输入选项 (1-8): " choice </dev/tty
}

install_node() {
    install_dependencies
    print_info "=== 开始安装 Xboard-Node (Naive 稳定版) ==="
    read -p "请输入面板地址 (https://你的域名): " PANEL </dev/tty
    read -p "请输入通讯密钥 (ApiKey/Token): " TOKEN </dev/tty
    read -p "请输入节点ID (数字): " NODEID </dev/tty

    if [[ -z "$PANEL" || -z "$TOKEN" || -z "$NODEID" ]]; then
        print_error "配置不可为空，中止操作。"
        return
    fi

    print_info "正在拉取上游核心 (Master分支)..."
    # 核心降维打击：强行锁定 master 分支，彻底规避 dev 带来的 404 代差
    if curl -fsSL https://raw.githubusercontent.com/cedar2025/xboard-node/master/install.sh | sudo bash -s -- --mode node --panel "$PANEL" --token "$TOKEN" --node-id "$NODEID"; then
        hash -r 
        print_success "安装成功！配置已下发。"
        print_info "请前往 Xboard 后台确认节点在线状态。"
    else
        print_error "拉取上游核心失败，请检查网络。"
    fi
}

edit_config() {
    CONFIG_PATHS=("/etc/xboard-node/config.yml" "/usr/local/xboard-node/config.yml" "/opt/xboard-node/config.yml")
    for path in "${CONFIG_PATHS[@]}"; do
        if [ -f "$path" ]; then
            nano "$path" </dev/tty
            print_success "编辑完成，请选择 2 重启节点以应用。"
            return
        fi
    done
    print_error "未找到配置文件，请确认已安装节点。"
}

while true; do
    show_menu
    case $choice in
        1) install_node ;;
        2) systemctl restart xboard-node 2>/dev/null && print_success "✅ 节点已重启" || print_error "重启失败，服务可能不存在" ;;
        3) systemctl stop xboard-node 2>/dev/null && print_success "✅ 节点已停止" || print_error "停止失败，服务可能已停止" ;;
        4) journalctl -u xboard-node -f </dev/tty ;;
        5) systemctl status xboard-node --no-pager ;;
        6)
            print_warn "⚠️ 即将执行内核级物理摧毁"
            read -p "确认彻底抹除？(y/N): " confirm </dev/tty
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                print_info "撕毁守护进程..."
                systemctl stop xboard-node >/dev/null 2>&1 || true
                systemctl disable xboard-node >/dev/null 2>&1 || true
                rm -f /etc/systemd/system/xboard-node.service
                systemctl daemon-reload
                print_info "焚毁二进制与配置..."
                rm -f /usr/local/bin/xboard-node /usr/local/bin/xbctl /usr/bin/xbctl
                rm -rf /etc/xboard-node
                print_success "✅ 彻底卸载完成！系统重归纯净。"
            else
                print_info "操作取消。"
            fi
            ;;
        7) edit_config ;;
        8) exit 0 ;;
        *) print_error "非法指令" ;;
    esac
    echo ""
    read -p "按回车键返回主菜单..." </dev/tty
done
