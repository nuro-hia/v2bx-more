#!/bin/bash
# =====================================================
# V2bX 多平台独立安装脚本（多路径不冲突版）
# 每个平台一套独立 V2bX 环境，可共存运行
# =====================================================

set -e
red='\033[0;31m'; green='\033[0;32m'; yellow='\033[0;33m'; plain='\033[0m'
cur_dir=$(pwd)

# ---------------------------
# 权限检查
# ---------------------------
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用 root 用户运行此脚本！" && exit 1

# ---------------------------
# 自定义平台名称与路径
# ---------------------------
echo ""
echo "请输入平台标识（仅限字母、数字、下划线、中横线，不可含空格）"
read -rp "平台名（如: mist, cloud, shop；默认 default）: " PLATFORM_NAME
PLATFORM_NAME=${PLATFORM_NAME:-default}

if [[ ! $PLATFORM_NAME =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo -e "${red}错误：平台名仅能包含字母、数字、下划线或中横线！${plain}"
  exit 1
fi

# 定义独立路径与服务名
INSTALL_DIR="/usr/local/V2bX-${PLATFORM_NAME}"
CONF_DIR="/etc/V2bX-${PLATFORM_NAME}"
SERVICE_NAME="V2bX-${PLATFORM_NAME}.service"
CMD_NAME="v2bx-${PLATFORM_NAME}"

echo ""
echo -e "🧩 平台名称: ${green}${PLATFORM_NAME}${plain}"
echo -e "📁 安装目录: ${yellow}${INSTALL_DIR}${plain}"
echo -e "⚙️ 配置目录: ${yellow}${CONF_DIR}${plain}"
echo -e "🔧 服务名称: ${yellow}${SERVICE_NAME}${plain}"
echo -e "📦 命令名称: ${yellow}${CMD_NAME}${plain}"
echo ""
read -rp "确认开始安装? (y/n): " confirm
[[ $confirm != [Yy] ]] && echo "已取消。" && exit 0

# ---------------------------
# 系统检测
# ---------------------------
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif grep -Eqi "alpine" /etc/issue; then
    release="alpine"
elif grep -Eqi "debian" /etc/issue || grep -Eqi "debian" /proc/version; then
    release="debian"
elif grep -Eqi "ubuntu" /etc/issue || grep -Eqi "ubuntu" /proc/version; then
    release="ubuntu"
else
    release="other"
fi

arch=$(uname -m)
if [[ $arch == "x86_64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
else
    arch="64"
fi

# ---------------------------
# 安装基础依赖
# ---------------------------
install_base() {
    echo -e "${green}正在安装基础依赖...${plain}"
    case $release in
      centos) yum install -y wget curl unzip tar socat ca-certificates >/dev/null 2>&1 ;;
      debian|ubuntu)
        apt update -y >/dev/null 2>&1
        apt install -y wget curl unzip tar cron socat ca-certificates >/dev/null 2>&1 ;;
      alpine) apk add wget curl unzip tar socat ca-certificates >/dev/null 2>&1 ;;
    esac
}

# ---------------------------
# 安装 V2bX 独立实例
# ---------------------------
install_v2bx() {
    mkdir -p "${INSTALL_DIR}" "${CONF_DIR}"
    cd "${INSTALL_DIR}"

    echo -e "${green}检测 V2bX 最新版本中...${plain}"
    last_version=$(curl -Ls "https://api.github.com/repos/wyx2685/V2bX/releases/latest" \
        | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    [[ -z "$last_version" ]] && echo -e "${red}检测版本失败，请稍后再试。${plain}" && exit 1

    echo -e "检测到最新版本：${green}${last_version}${plain}"
    wget -q -O "${INSTALL_DIR}/V2bX-linux.zip" \
        "https://github.com/wyx2685/V2bX/releases/download/${last_version}/V2bX-linux-${arch}.zip"
    unzip -q V2bX-linux.zip && rm -f V2bX-linux.zip
    chmod +x V2bX

    # 拷贝必要配置文件
    cp geoip.dat geosite.dat "${CONF_DIR}/" 2>/dev/null || true
    [[ ! -f "${CONF_DIR}/config.json" ]] && cp config.json "${CONF_DIR}/"

    # systemd 服务
    echo -e "${green}创建独立 systemd 服务...${plain}"
    cat <<EOF >/etc/systemd/system/${SERVICE_NAME}
[Unit]
Description=V2bX Platform Instance (${PLATFORM_NAME})
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/V2bX server -c ${CONF_DIR}/config.json
Restart=always
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now ${SERVICE_NAME}

    # 独立命令入口
    curl -sSL -o "/usr/bin/${CMD_NAME}" \
      https://raw.githubusercontent.com/wyx2685/V2bX-script/master/V2bX.sh
    chmod +x "/usr/bin/${CMD_NAME}"

    echo -e "\n✅ ${green}V2bX 平台实例 ${PLATFORM_NAME}${plain} 安装完成！"
    echo -e "------------------------------------------"
    echo -e "配置路径: ${yellow}${CONF_DIR}${plain}"
    echo -e "程序路径: ${yellow}${INSTALL_DIR}${plain}"
    echo -e "systemd 服务: ${yellow}${SERVICE_NAME}${plain}"
    echo -e "启动命令: systemctl start ${SERVICE_NAME}"
    echo -e "查看日志: journalctl -u ${SERVICE_NAME} -f"
    echo -e "管理命令: ${yellow}${CMD_NAME}${plain}"
    echo -e "------------------------------------------"
}

install_base
install_v2bx
