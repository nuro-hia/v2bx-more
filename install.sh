#!/bin/bash
# =====================================================
# V2bX 多平台独立管理脚本（安装 / 卸载 / 管理一体）
# 支持多路径、互不冲突
# by nuro-hia
# =====================================================

set -e
red='\033[0;31m'; green='\033[0;32m'; yellow='\033[0;33m'; plain='\033[0m'

pause(){ read -rp "按回车返回菜单..." _; }

print_header(){
  clear
  echo -e "${green}==============================${plain}"
  echo -e "         V2bX 多平台管理脚本"
  echo -e "==============================${plain}\n"
}

# ---------------------------
# 安装依赖
# ---------------------------
install_base(){
  echo -e "${green}正在安装依赖...${plain}"
  if [[ -f /etc/redhat-release ]]; then
    yum install -y wget curl unzip tar socat ca-certificates >/dev/null 2>&1
  elif grep -Eqi "debian" /etc/issue || grep -Eqi "debian" /proc/version; then
    apt update -y >/dev/null 2>&1
    apt install -y wget curl unzip tar socat ca-certificates >/dev/null 2>&1
  elif grep -Eqi "ubuntu" /etc/issue || grep -Eqi "ubuntu" /proc/version; then
    apt update -y >/dev/null 2>&1
    apt install -y wget curl unzip tar socat ca-certificates >/dev/null 2>&1
  elif grep -Eqi "alpine" /etc/issue; then
    apk add wget curl unzip tar socat ca-certificates >/dev/null 2>&1
  fi
}

# ---------------------------
# 安装新平台
# ---------------------------
install_platform(){
  print_header
  echo "请输入平台标识（仅限字母、数字、下划线、中横线）"
  read -rp "平台名（如 mist、cloud、hk，默认 default）: " PLATFORM_NAME
  PLATFORM_NAME=${PLATFORM_NAME:-default}
  if [[ ! $PLATFORM_NAME =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo -e "${red}错误：平台名仅能包含字母、数字、下划线或中横线！${plain}"
    pause; return
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
  echo -e "📦 命令名称: ${yellow}${CMD_NAME}${plain}\n"
  read -rp "确认开始安装? (y/n): " confirm
  [[ $confirm != [Yy] ]] && echo "已取消。" && pause && return

  arch=$(uname -m)
  if [[ $arch == "x86_64" || $arch == "amd64" ]]; then arch="64"
  elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then arch="arm64-v8a"
  else arch="64"; fi

  install_base
  mkdir -p "${INSTALL_DIR}" "${CONF_DIR}"
  cd "${INSTALL_DIR}"

  echo -e "${green}检测 V2bX 最新版本...${plain}"
  last_version=$(curl -Ls "https://api.github.com/repos/wyx2685/V2bX/releases/latest" \
      | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  [[ -z "$last_version" ]] && echo -e "${red}检测版本失败！${plain}" && pause && return

  echo -e "检测到版本: ${yellow}${last_version}${plain}"
  wget -q -O "${INSTALL_DIR}/V2bX-linux.zip" \
    "https://github.com/wyx2685/V2bX/releases/download/${last_version}/V2bX-linux-${arch}.zip"
  unzip -q V2bX-linux.zip && rm -f V2bX-linux.zip
  chmod +x V2bX
  cp geoip.dat geosite.dat "${CONF_DIR}/" 2>/dev/null || true
  [[ ! -f "${CONF_DIR}/config.json" ]] && cp config.json "${CONF_DIR}/"

  echo -e "${green}创建 systemd 服务...${plain}"
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
  curl -sSL -o "/usr/bin/${CMD_NAME}" \
    https://raw.githubusercontent.com/wyx2685/V2bX-script/master/V2bX.sh
  chmod +x "/usr/bin/${CMD_NAME}"
  sed -i "1iINSTANCE='${PLATFORM_NAME}'\nWORK_DIR='${INSTALL_DIR}'\nCONF_DIR='${CONF_DIR}'\nSERVICE_NAME='${SERVICE_NAME}'\n" "/usr/bin/${CMD_NAME}"

  echo -e "\n✅ ${green}平台 ${PLATFORM_NAME} 安装完成！${plain}"
  pause
}

# ---------------------------
# 卸载平台
# ---------------------------
uninstall_platform(){
  print_header
  mapfile -t PLATFORMS < <(ls -d /usr/local/V2bX-* 2>/dev/null || true)
  [[ ${#PLATFORMS[@]} -eq 0 ]] && echo -e "${yellow}未检测到已安装平台。${plain}" && pause && return

  echo "请选择要卸载的平台："
  for i in "${!PLATFORMS[@]}"; do
    name=$(basename "${PLATFORMS[$i]}")
    echo "$((i+1)). ${name}"
  done
  read -rp "输入序号选择: " choice
  ((choice>=1 && choice<=${#PLATFORMS[@]})) || { echo -e "${red}无效选择${plain}"; pause; return; }

  TARGET=${PLATFORMS[$((choice-1))]}
  PLATFORM_NAME=$(basename "$TARGET" | sed 's/^V2bX-//')
  SERVICE_NAME="V2bX-${PLATFORM_NAME}.service"
  CMD_NAME="/usr/bin/v2bx-${PLATFORM_NAME}"

  echo ""
  read -rp "确认卸载 ${PLATFORM_NAME}? (y/n): " confirm
  [[ $confirm != [Yy] ]] && echo "已取消。" && pause && return

  systemctl stop ${SERVICE_NAME} 2>/dev/null || true
  systemctl disable ${SERVICE_NAME} 2>/dev/null || true
  rm -f /etc/systemd/system/${SERVICE_NAME}
  rm -rf "/usr/local/V2bX-${PLATFORM_NAME}" "/etc/V2bX-${PLATFORM_NAME}" "${CMD_NAME}"
  systemctl daemon-reload
  echo -e "${green}平台 ${PLATFORM_NAME} 已彻底卸载。${plain}"
  pause
}

# ---------------------------
# 管理平台
# ---------------------------
manage_platform(){
  print_header
  mapfile -t PLATFORMS < <(ls -d /usr/local/V2bX-* 2>/dev/null || true)
  [[ ${#PLATFORMS[@]} -eq 0 ]] && echo -e "${yellow}未检测到已安装平台。${plain}" && pause && return

  echo "请选择要管理的平台："
  for i in "${!PLATFORMS[@]}"; do
    name=$(basename "${PLATFORMS[$i]}")
    echo "$((i+1)). ${name}"
  done
  read -rp "输入序号选择: " choice
  ((choice>=1 && choice<=${#PLATFORMS[@]})) || { echo -e "${red}无效选择${plain}"; pause; return; }

  PLATFORM_NAME=$(basename "${PLATFORMS[$((choice-1))]}" | sed 's/^V2bX-//')
  SERVICE="V2bX-${PLATFORM_NAME}.service"
  CMD="/usr/bin/v2bx-${PLATFORM_NAME}"

  while true; do
    print_header
    echo "📦 管理平台: ${yellow}${PLATFORM_NAME}${plain}"
    echo "----------------------------------"
    echo "1. 启动服务"
    echo "2. 停止服务"
    echo "3. 重启服务"
    echo "4. 查看运行状态"
    echo "5. 查看实时日志"
    echo "6. 打开配置菜单 (${CMD})"
    echo "7. 返回上级菜单"
    echo "----------------------------------"
    read -rp "请选择 [1-7]: " opt
    case $opt in
      1) systemctl start ${SERVICE}; echo -e "${green}已启动${plain}"; pause ;;
      2) systemctl stop ${SERVICE}; echo -e "${green}已停止${plain}"; pause ;;
      3) systemctl restart ${SERVICE}; echo -e "${green}已重启${plain}"; pause ;;
      4) systemctl status ${SERVICE} --no-pager; pause ;;
      5) journalctl -u ${SERVICE} -f ;;
      6) [[ -x ${CMD} ]] && ${CMD} || echo -e "${red}未找到管理命令。${plain}"; pause ;;
      7) return ;;
      *) echo -e "${red}无效选项${plain}"; sleep 1 ;;
    esac
  done
}

# ---------------------------
# 主菜单
# ---------------------------
main_menu(){
  while true; do
    print_header
    echo "1. 安装新平台实例"
    echo "2. 卸载已有平台实例"
    echo "3. 管理已安装平台"
    echo "4. 退出"
    echo ""
    read -rp "请输入选项 [1-4]: " num
    case $num in
      1) install_platform ;;
      2) uninstall_platform ;;
      3) manage_platform ;;
      4) echo "已退出。"; exit 0 ;;
      *) echo -e "${red}无效选项！${plain}" && sleep 1 ;;
    esac
  done
}

main_menu
