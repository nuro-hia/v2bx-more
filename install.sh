#!/bin/bash
# =====================================================
# V2bX 多实例安装脚本（规范版）
# 支持自定义实例名 / 独立路径 / 多面板共存
# =====================================================

set -e
red='\033[0;31m'; green='\033[0;32m'; yellow='\033[0;33m'; plain='\033[0m'
cur_dir=$(pwd)

# 检查 root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用 root 用户运行此脚本！" && exit 1

# ---------------------------
# 实例命名交互（规范版）
# ---------------------------
echo ""
echo "请输入实例标识名称（仅限字母、数字、下划线、中横线，不可含空格或特殊字符）"
read -rp "实例名（默认: default）: " INSTANCE_NAME
INSTANCE_NAME=${INSTANCE_NAME:-default}

if [[ ! $INSTANCE_NAME =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo -e "${red}错误：实例名仅能包含字母、数字、下划线或中横线！${plain}"
  exit 1
fi

if [[ $INSTANCE_NAME != v2bx-* ]]; then
  INSTANCE_NAME="v2bx-${INSTANCE_NAME}"
fi

INSTALL_DIR="/usr/local/${INSTANCE_NAME}"
CONF_DIR="/etc/${INSTANCE_NAME}"
SERVICE_NAME="${INSTANCE_NAME}.service"

echo -e "🧩 实例名称: ${green}${INSTANCE_NAME}${plain}"
echo -e "📁 安装目录: ${yellow}${INSTALL_DIR}${plain}"
echo -e "⚙️ 配置目录: ${yellow}${CONF_DIR}${plain}"
echo -e "🔧 服务名称: ${yellow}${SERVICE_NAME}${plain}"
echo ""
read -rp "确认开始安装? (y/n): " confirm
[[ $confirm != [Yy] ]] && echo "已取消。" && exit 0

# ---------------------------
# 系统与架构检测
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
    if [[ $release == "centos" ]]; then
        yum install -y wget curl unzip tar socat ca-certificates >/dev/null 2>&1
    elif [[ $release == "debian" || $release == "ubuntu" ]]; then
        apt update -y >/dev/null 2>&1
        apt install -y wget curl unzip tar cron socat ca-certificates >/dev/null 2>&1
    elif [[ $release == "alpine" ]]; then
        apk add wget curl unzip tar socat ca-certificates >/dev/null 2>&1
    fi
}

# ---------------------------
# 安装 V2bX 实例
# ---------------------------
install_v2bx() {
    mkdir -p "${INSTALL_DIR}" "${CONF_DIR}"
    cd "${INSTALL_DIR}"

    echo -e "${green}检测 V2bX 最新版本中...${plain}"
    last_version=$(curl -Ls "https://api.github.com/repos/wyx2685/V2bX/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    [[ -z "$last_version" ]] && echo -e "${red}检测版本失败，请稍后再试。${plain}" && exit 1

    echo -e "检测到最新版本：${green}${last_version}${plain}"
    wget --no-check-certificate -q -O "${INSTALL_DIR}/V2bX-linux.zip" \
        "https://github.com/wyx2685/V2bX/releases/download/${last_version}/V2bX-linux-${arch}.zip"
    unzip -q V2bX-linux.zip && rm -f V2bX-linux.zip
    chmod +x V2bX

    cp geoip.dat geosite.dat "${CONF_DIR}/" || true
    [[ ! -f "${CONF_DIR}/config.json" ]] && cp config.json "${CONF_DIR}/"

    echo -e "${green}正在创建 systemd 服务...${plain}"
    cat <<EOF >/etc/systemd/system/${SERVICE_NAME}
[Unit]
Description=V2bX Instance (${INSTANCE_NAME})
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

    curl -sSL -o "/usr/bin/${INSTANCE_NAME}" https://raw.githubusercontent.com/wyx2685/V2bX-script/master/V2bX.sh
    chmod +x "/usr/bin/${INSTANCE_NAME}"

    echo -e "\n✅ ${green}V2bX 实例 ${INSTANCE_NAME}${plain} 安装完成！"
    echo -e "------------------------------------------"
    echo -e "配置路径: ${yellow}${CONF_DIR}${plain}"
    echo -e "程序路径: ${yellow}${INSTALL_DIR}${plain}"
    echo -e "systemd 服务: ${yellow}${SERVICE_NAME}${plain}"
    echo -e "启动命令: systemctl start ${SERVICE_NAME}"
    echo -e "查看日志: journalctl -u ${SERVICE_NAME} -f"
    echo -e "管理命令: ${yellow}${INSTANCE_NAME}${plain}"
    echo -e "------------------------------------------"
}

install_base
install_v2bx
