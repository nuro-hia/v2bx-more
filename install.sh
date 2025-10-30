#!/bin/bash
# =====================================================
# V2bX 多平台独立安装与卸载脚本
# 支持多路径安装、多面板共存、序号选择卸载
# by nuro-hia
# =====================================================

set -e
red='\033[0;31m'; green='\033[0;32m'; yellow='\033[0;33m'; plain='\033[0m'

# ---------------------------
# 基础函数
# ---------------------------
pause(){ read -rp "按回车键继续..." _; }

print_header(){
  clear
  echo -e "${green}==============================${plain}"
  echo -e "       V2bX 多平台管理脚本"
  echo -e "==============================${plain}"
  echo ""
}

# ---------------------------
# 系统与依赖检测
# ---------------------------
install_base(){
  echo -e "${green}正在安装必要依赖...${plain}"
  if [[ -f /etc/redhat-release ]]; then
    release="centos"
  elif grep -Eqi "debian" /etc/issue || grep -Eqi "debian" /proc/version; then
    release="debian"
  elif grep -Eqi "ubuntu" /etc/issue || grep -Eqi "ubuntu" /proc/version; then
    release="ubuntu"
  elif grep -Eqi "alpine" /etc/issue; then
    release="alpine"
  else
    release="other"
  fi

  case $release in
    centos) yum install -y wget curl unzip tar socat ca-certificates >/dev/null 2>&1 ;;
    debian|ubuntu)
      apt update -y >/dev/null 2>&1
      apt install -y wget curl unzip tar cron socat ca-certificates >/dev/null 2>&1 ;;
    alpine) apk add wget curl unzip tar socat ca-certificates >/dev/null 2>&1 ;;
  esac
}

# ---------------------------
# 安装新平台
# ---------------------------
install_platform(){
  print_header
  echo "请输入平台标识（仅限字母、数字、下划线、中横线，不可含空格）"
  read -rp "平台名（如 mist、cloud、hk，默认 default）: " PLATFORM_NAME
  PLATFORM_NAME=${PLATFORM_NAME:-default}

  if [[ ! $PLATFORM_NAME =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo -e "${red}错误：平台名仅能包含字母、数字、下划线或中横线！${plain}"
    exit 1
  fi

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

  arch=$(uname -m)
  if [[ $arch == "x86_64" || $arch == "amd64" ]]; then
      arch="64"
  elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
      arch="arm64-v8a"
  else
      arch="64"
  fi

  install_base
  mkdir -p "${INSTALL_DIR}" "${CONF_DIR}"
  cd "${INSTALL_DIR}"

  echo -e "${green}检测 V2bX 最新版本中...${plain}"
  last_version=$(curl -Ls "https://api.github.com/repos/wyx2685/V2bX/releases/latest" |
      grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  [[ -z "$last_version" ]] && echo -e "${red}检测版本失败，请稍后再试。${plain}" && exit 1

  echo -e "检测到版本：${green}${last_version}${plain}"
  wget -q -O "${INSTALL_DIR}/V2bX-linux.zip" \
      "https://github.com/wyx2685/V2bX/releases/download/${last_version}/V2bX-linux-${arch}.zip"
  unzip -q V2bX-linux.zip && rm -f V2bX-linux.zip
  chmod +x V2bX
  cp geoip.dat geosite.dat "${CONF_DIR}/" 2>/dev/null || true
  [[ ! -f "${CONF_DIR}/config.json" ]] && cp config.json "${CONF_DIR}/"

  echo -e "${green}创建独立 systemd 服务...${plain}"
  cat <<EOF >/etc/systemd/system/${SERVICE_NAME}
[Unit]
Description=V2bX Platform (${PLATFORM_NAME})
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

  echo -e "${green}创建独立管理命令...${plain}"
  curl -sSL -o "/usr/bin/${CMD_NAME}" https://raw.githubusercontent.com/wyx2685/V2bX-script/master/V2bX.sh
  chmod +x "/usr/bin/${CMD_NAME}"
  sed -i "1iINSTANCE='${PLATFORM_NAME}'\nWORK_DIR='${INSTALL_DIR}'\nCONF_DIR='${CONF_DIR}'\nSERVICE_NAME='${SERVICE_NAME}'\n" "/usr/bin/${CMD_NAME}"

  echo -e "\n✅ ${green}V2bX 平台 ${PLATFORM_NAME}${plain} 安装完成！"
  echo -e "------------------------------------------"
  echo -e "配置路径: ${yellow}${CONF_DIR}${plain}"
  echo -e "程序路径: ${yellow}${INSTALL_DIR}${plain}"
  echo -e "systemd 服务: ${yellow}${SERVICE_NAME}${plain}"
  echo -e "启动命令: systemctl start ${SERVICE_NAME}"
  echo -e "查看日志: journalctl -u ${SERVICE_NAME} -f"
  echo -e "管理命令: ${yellow}${CMD_NAME}${plain}"
  echo -e "------------------------------------------"
  pause
}

# ---------------------------
# 卸载平台
# ---------------------------
uninstall_platform(){
  print_header
  mapfile -t PLATFORMS < <(ls -d /usr/local/V2bX-* 2>/dev/null || true)
  if [[ ${#PLATFORMS[@]} -eq 0 ]]; then
    echo -e "${yellow}未检测到任何已安装的平台实例。${plain}"
    pause
    return
  fi

  echo "请选择要卸载的平台："
  for i in "${!PLATFORMS[@]}"; do
    name=$(basename "${PLATFORMS[$i]}")
    echo "$((i+1)). ${name}"
  done

  read -rp "输入序号选择: " choice
  if ! [[ $choice =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#PLATFORMS[@]})); then
    echo -e "${red}输入无效。${plain}"
    pause
    return
  fi

  TARGET=${PLATFORMS[$((choice-1))]}
  PLATFORM_NAME=$(basename "$TARGET" | sed 's/^V2bX-//')
  CONF_DIR="/etc/V2bX-${PLATFORM_NAME}"
  SERVICE_NAME="V2bX-${PLATFORM_NAME}.service"
  CMD_NAME="/usr/bin/v2bx-${PLATFORM_NAME}"

  echo ""
  echo -e "确认要${red}彻底卸载${plain}平台 ${yellow}${PLATFORM_NAME}${plain} 吗? (y/n)"
  read -rp "> " confirm
  [[ $confirm != [Yy] ]] && echo "已取消卸载。" && pause && return

  echo -e "${yellow}正在停止并删除服务...${plain}"
  systemctl stop ${SERVICE_NAME} 2>/dev/null || true
  systemctl disable ${SERVICE_NAME} 2>/dev/null || true
  rm -f /etc/systemd/system/${SERVICE_NAME}
  systemctl daemon-reload

  echo -e "${yellow}正在删除文件...${plain}"
  rm -rf "${TARGET}" "${CONF_DIR}" "${CMD_NAME}"

  echo -e "\n✅ ${green}平台 ${PLATFORM_NAME} 已彻底卸载完成！${plain}"
  pause
}

# ---------------------------
# 主菜单
# ---------------------------
main_menu(){
  while true; do
    print_header
    echo "1. 安装新平台实例"
    echo "2. 卸载已有平台实例"
    echo "3. 退出"
    echo ""
    read -rp "请输入选项 [1-3]: " num
    case $num in
      1) install_platform ;;
      2) uninstall_platform ;;
      3) echo "已退出。"; exit 0 ;;
      *) echo -e "${red}无效选项！${plain}" && sleep 1 ;;
    esac
  done
}

main_menu
