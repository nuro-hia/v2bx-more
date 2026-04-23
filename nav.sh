#!/bin/bash
# ================================================
# Xboard-Node systemd 原生版 管理面板（Naive 专用）
# 【核弹级修复】强制接管配置生成，封杀所有特殊字符转义
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
    echo -e "   🚀 Xboard-Node 管理面板（Naive 终极防弹版）"
    echo -e "${BLUE}=======================================${NC}"
    echo "1. 安装 / 重新对接节点 (彻底解决 Token 报错)"
    echo "2. 重启节点服务"
    echo "3. 停止节点服务"
    echo "4. 查看实时崩溃日志"
    echo "5. 查看节点运行状态"
    echo "6. 彻底卸载 (纯净物理抹除)"
    echo "7. 手动修改配置文件"
    echo "8. 退出"
    echo -e "${BLUE}=======================================${NC}"
    read -p "请输入选项 (1-8): " choice </dev/tty
}

# 暴力重写配置文件，杜绝上游脚本的转义 BUG
force_write_config() {
    local panel="$1"
    local token="$2"
    local nodeid="$3"

    print_info "正在暴力重写配置文件，锁定强引用格式..."

    # 使用 printf 配合单引号，确保 $ 和 # 被当做纯文本处理
    sudo mkdir -p /etc/xboard-node
    
    # 1. 重写 config.yml
    cat > /etc/xboard-node/config.yml << EOF
nodes:
  - panel: '$panel'
    token: '$token'
    node_id: $nodeid
EOF

    # 2. 重写 credentials.env (双重保险)
    cat > /etc/xboard-node/credentials.env << EOF
XBOARD_PANEL_URL='$panel'
XBOARD_PANEL_TOKEN='$token'
XBOARD_NODE_ID=$nodeid
EOF

    chmod 600 /etc/xboard-node/config.yml /etc/xboard-node/credentials.env
    
    print_info "配置文件已重构。正在尝试拉起服务..."
    systemctl restart xboard-node
    sleep 2
    
    if systemctl is-active --quiet xboard-node; then
        print_success "节点已成功拉起！Token 识别正常。"
    else
        print_error "启动依然失败，请选 4 查看最新报错。"
    fi
}

install_node() {
    install_dependencies
    print_info "=== 开始安装 Xboard-Node (Naive 稳定版) ==="
    
    # 使用 -r 确保输入的特殊符号不被 shell 预处理
    read -r -p "请输入面板地址 (https://你的域名): " PANEL </dev/tty
    read -r -p "请输入通讯密钥 (Token): " TOKEN </dev/tty
    read -r -p "请输入节点ID (数字): " NODEID </dev/tty

    if [[ -z "$PANEL" || -z "$TOKEN" || -z "$NODEID" ]]; then
        print_error "输入不能为空。"
        return
    fi

    print_info "正在执行官方基础安装..."
    # 我们依然调用官方脚本拉取二进制，但不再信任它的配置生成
    if curl -fsSL https://raw.githubusercontent.com/cedar2025/xboard-node/master/install.sh | sudo bash -s -- --mode node --panel "$PANEL" --token "temp_token" --node-id "$NODEID"; then
        hash -r 
        # 核心步骤：立刻执行我们的暴力覆盖函数
        force_write_config "$PANEL" "$TOKEN" "$NODEID"
    else
        print_error "官方脚本拉取失败，请检查网络。"
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
