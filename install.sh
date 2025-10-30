#!/bin/bash
# ==========================================
#  V2bX 多平台管理菜单（安装 / 添加 / 删除 / 备份）
#  作者: nuro 定制版
# ==========================================

CONFIG_FILE="/etc/V2bX/config.json"
BACKUP_DIR="/etc/V2bX/backup"
TEMP_FILE="/tmp/v2bx_config_tmp.json"

# 检查 jq
if ! command -v jq &>/dev/null; then
  echo "🌱 正在安装 jq..."
  apt update -y >/dev/null 2>&1
  apt install jq -y >/dev/null 2>&1
fi

# 检查 V2bX 是否安装
check_v2bx() {
  [[ -f /usr/local/V2bX/V2bX ]]
}

# 安装 V2bX
install_v2bx() {
  echo "=============================="
  echo "🚀 安装 V2bX 主程序"
  echo "=============================="
  if check_v2bx; then
    echo "✅ 已检测到 V2bX，无需重复安装。"
    return
  fi
  wget -N https://raw.githubusercontent.com/wyx2685/V2bX-script/master/install.sh && bash install.sh
  echo "✨ 安装完成。"
}

# 查看节点
list_nodes() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ 未找到配置文件，请先安装 V2bX。"
    return
  fi
  echo -e "\n📋 当前节点列表："
  jq -r '.Nodes[] | "\(.NodeID) | \(.NodeType) | \(.ApiHost) | \(.CertConfig.CertDomain)"' "$CONFIG_FILE" | nl -w2 -s'. '
  echo ""
}

# 添加节点
add_node() {
  if ! check_v2bx; then
    echo "❌ 未检测到 V2bX，请先安装。"
    read -rp "是否立即安装？(y/n): " ADD_INSTALL
    if [[ "$ADD_INSTALL" == "y" ]]; then
      install_v2bx
    else
      return
    fi
  fi

  mkdir -p "$(dirname "$CONFIG_FILE")"
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo '{"Nodes":[]}' >"$CONFIG_FILE"
  fi

  echo "=============================="
  echo "⚙️  添加新节点"
  echo "=============================="
  echo ""

  read -rp "📦 节点类型 [ss/hy2] (默认 ss): " NODE_TYPE
  NODE_TYPE=${NODE_TYPE:-ss}

  if [[ "$NODE_TYPE" != "ss" && "$NODE_TYPE" != "hy2" ]]; then
    echo "❌ 节点类型必须是 ss 或 hy2"
    return
  fi

  read -rp "🪧 请输入面板地址: " API_HOST
  read -rp "🔑 请输入面板 API Key: " API_KEY
  read -rp "🆔 请输入节点 ID: " NODE_ID
  read -rp "🌐 请输入节点域名: " CERT_DOMAIN

  if [[ -z "$API_HOST" || -z "$API_KEY" || -z "$NODE_ID" || -z "$CERT_DOMAIN" ]]; then
    echo "❌ 参数不能为空。"
    return
  fi

  if [[ "$NODE_TYPE" == "ss" ]]; then
    NODE_TYPE_FULL="shadowsocks"
    TCP="true"
  else
    NODE_TYPE_FULL="hysteria2"
    TCP="false"
  fi

  NEW_NODE=$(cat <<EOF
{
  "Core": "sing",
  "ApiHost": "$API_HOST",
  "ApiKey": "$API_KEY",
  "NodeID": $NODE_ID,
  "NodeType": "$NODE_TYPE_FULL",
  "Timeout": 30,
  "ListenIP": "0.0.0.0",
  "SendIP": "0.0.0.0",
  "DeviceOnlineMinTraffic": 200,
  "MinReportTraffic": 0,
  "TCPFastOpen": $TCP,
  "SniffEnabled": true,
  "CertConfig": {
    "CertMode": "http",
    "RejectUnknownSni": false,
    "CertDomain": "$CERT_DOMAIN",
    "CertFile": "/etc/V2bX/fullchain.cer",
    "KeyFile": "/etc/V2bX/cert.key",
    "Email": "v2bx@github.com",
    "Provider": "cloudflare",
    "DNSEnv": { "EnvName": "env1" }
  }
}
EOF
)

  jq ".Nodes += [$NEW_NODE]" "$CONFIG_FILE" >"$TEMP_FILE" && mv "$TEMP_FILE" "$CONFIG_FILE"
  echo "✅ 节点添加成功。"
  restart_v2bx
}

# 删除节点
delete_node() {
  list_nodes
  read -rp "🗑️ 请输入要删除的节点序号: " IDX
  if [[ -z "$IDX" ]]; then
    echo "❌ 未输入编号。"
    return
  fi
  IDX=$((IDX - 1))
  jq "del(.Nodes[$IDX])" "$CONFIG_FILE" >"$TEMP_FILE" && mv "$TEMP_FILE" "$CONFIG_FILE"
  echo "✅ 节点已删除。"
  restart_v2bx
}

# 备份配置
backup_config() {
  mkdir -p "$BACKUP_DIR"
  cp "$CONFIG_FILE" "$BACKUP_DIR/config_$(date +%Y%m%d_%H%M%S).json"
  echo "💾 配置已备份到 $BACKUP_DIR"
}

# 恢复配置
restore_config() {
  echo "📂 可用备份文件："
  ls -1 "$BACKUP_DIR"/config_*.json 2>/dev/null || echo "无备份文件"
  echo ""
  read -rp "📥 请输入要恢复的文件名（仅文件名）: " FILE
  if [[ -f "$BACKUP_DIR/$FILE" ]]; then
    cp "$BACKUP_DIR/$FILE" "$CONFIG_FILE"
    echo "✅ 已恢复配置：$FILE"
    restart_v2bx
  else
    echo "❌ 未找到该文件。"
  fi
}

# 重启服务
restart_v2bx() {
  echo "🔁 正在重启 V2bX..."
  systemctl restart V2bX
  sleep 2
  systemctl status V2bX --no-pager | grep Active
}

# === 主菜单 ===
while true; do
  clear
  echo "=============================="
  echo "     🌿 V2bX 多平台管理菜单"
  echo "=============================="
  echo "1️⃣  安装 V2bX"
  echo "2️⃣  添加新节点"
  echo "3️⃣  删除节点"
  echo "4️⃣  查看所有节点"
  echo "5️⃣  备份配置"
  echo "6️⃣  恢复配置"
  echo "7️⃣  重启 V2bX"
  echo "8️⃣  查看实时日志"
  echo "0️⃣  退出菜单"
  echo "=============================="
  read -rp "请输入选项 [0-8]: " CHOICE
  case "$CHOICE" in
  1) install_v2bx; read -rp "按回车返回菜单..." ;;
  2) add_node; read -rp "按回车返回菜单..." ;;
  3) delete_node; read -rp "按回车返回菜单..." ;;
  4) list_nodes; read -rp "按回车返回菜单..." ;;
  5) backup_config; read -rp "按回车返回菜单..." ;;
  6) restore_config; read -rp "按回车返回菜单..." ;;
  7) restart_v2bx; read -rp "按回车返回菜单..." ;;
  8) journalctl -u V2bX -f ;;
  0) echo "👋 已退出菜单。"; exit 0 ;;
  *) echo "❌ 无效选项，请重新输入。"; sleep 1 ;;
  esac
done
