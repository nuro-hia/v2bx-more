#!/bin/bash
# Xboard-Node 管理终端 (支持 ss/hy2/trojan 原生对接)

SCRIPT_URL="https://raw.githubusercontent.com/您的用户名/您的仓库名/main/xboard.sh"
CLI_CMD="xbmenu"

GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

if [ ! -t 0 ] && [ ! -c /dev/tty ]; then
    echo -e "${RED}Fatal: No TTY attached.${RESET}"
    exit 1
fi

for pkg in curl sudo nano; do
    if ! command -v $pkg >/dev/null 2>&1; then
        (apt-get update && apt-get install -y $pkg) >/dev/null 2>&1 || (yum install -y $pkg) >/dev/null 2>&1
    fi
done

if ! command -v $CLI_CMD >/dev/null 2>&1 && [[ "$0" != "/usr/local/bin/$CLI_CMD" ]]; then
    if curl -fsSL "$SCRIPT_URL" -o /usr/local/bin/$CLI_CMD; then
        chmod +x /usr/local/bin/$CLI_CMD
        echo -e "${GREEN}✅ 面板已固化。全局命令: ${CLI_CMD}${RESET}"
    fi
fi

get_xbctl() {
    if [ -x "/usr/local/bin/xbctl" ]; then
        echo "/usr/local/bin/xbctl"
    elif command -v xbctl >/dev/null 2>&1; then
        command -v xbctl
    fi
}

check_xbctl() {
    if [ -z "$(get_xbctl)" ]; then
        echo -e "${RED}未检测到 xbctl，请先执行安装。${RESET}"
        return 1
    fi
    return 0
}

show_menu() {
    clear
    echo "================================================="
    echo -e "   ${GREEN}Xboard-Node 管理终端${RESET}"
    echo "================================================="
    echo "1. 安装并对接节点"
    echo "2. 重启节点服务"
    echo "3. 停止节点服务"
    echo "4. 查看实时日志"
    echo "5. 更新节点程序"
    echo "6. 彻底卸载节点 (底层清理)"
    echo "7. 修改配置文件"
    echo "8. 退出"
    echo "================================================="
    read -p "请输入指令编号 (1-8): " choice </dev/tty
}

install_node() {
    read -p "面板地址 (如 https://panel.com): " PANEL </dev/tty
    read -p "通讯密钥 (Token): " TOKEN </dev/tty
    read -p "节点ID (数字): " NODEID </dev/tty

    if [[ -z "$PANEL" || -z "$TOKEN" || -z "$NODEID" ]]; then
        echo -e "${RED}参数不可为空。${RESET}"
        return
    fi

    if curl -fsSL https://raw.githubusercontent.com/cedar2025/xboard-node/dev/install.sh | sudo bash -s -- --mode node --panel "$PANEL" --token "$TOKEN" --node-id "$NODEID"; then
        hash -r 
        source /etc/profile >/dev/null 2>&1
        echo -e "${GREEN}✅ 部署指令下发完成！若日志提示 404，请检查面板端伪静态。${RESET}"
    else
        echo -e "${RED}❌ 安装异常退出。${RESET}"
    fi
}

edit_config() {
    CONFIG_PATHS=("/etc/xboard-node/config.yml" "/usr/local/xboard-node/config.yml" "/opt/xboard-node/config.yml")
    for path in "${CONFIG_PATHS[@]}"; do
        if [ -f "$path" ]; then
            sudo nano "$path" </dev/tty
            return
        fi
    done
    echo -e "${RED}❌ 未找到配置文件。${RESET}"
}

# 物理级抹除逻辑，直接绕过无能的 xbctl
uninstall_node() {
    echo -e "${YELLOW}正在接管系统内核，执行物理级抹除...${RESET}"
    sudo systemctl stop xboard-node >/dev/null 2>&1
    sudo systemctl disable xboard-node >/dev/null 2>&1
    sudo rm -f /etc/systemd/system/xboard-node.service
    sudo systemctl daemon-reload
    sudo rm -rf /etc/xboard-node
    XB_PATH=$(get_xbctl)
    if [ -n "$XB_PATH" ]; then
        sudo rm -f "$XB_PATH"
    fi
    echo -e "${GREEN}✅ 节点进程、配置及残留核心已全部摧毁。${RESET}"
}

while true; do
    show_menu
    XB=$(get_xbctl)
    case $choice in
        1) install_node ;;
        2) check_xbctl && sudo "$XB" service restart && echo -e "${GREEN}✅ 已重启${RESET}" ;;
        3) check_xbctl && sudo "$XB" service stop && echo -e "${GREEN}✅ 已停止${RESET}" ;;
        4) check_xbctl && sudo "$XB" service logs -f </dev/tty ;;
        5) check_xbctl && sudo "$XB" self-update && echo -e "${GREEN}✅ 已更新${RESET}" ;;
        6) uninstall_node ;;
        7) edit_config ;;
        8) exit 0 ;;
        *) echo -e "${RED}非法指令。${RESET}" ;;
    esac
    read -p "按回车键返回..." </dev/tty
done
