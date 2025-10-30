#!/bin/bash
# ==========================================
#  V2bX 多平台管理菜单版（支持添加/删除节点）
#  作者: nuro 定制版
# ==========================================

CONFIG_FILE="/etc/V2bX/config.json"
TEMP_FILE="/tmp/v2bx_config_tmp.json"

# 检查 jq
if ! command -v jq &>/dev/null; then
  echo "安装 jq 中..."
  apt update -y >/dev/null 2>&1
  apt install jq -y >/dev/null 2>&1
fi

# 确保配置存在
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ 找不到配置文件: $CONFIG_FILE"
  exit 1
fi

# === 功能函数 ===
list_nodes() {
  echo -e "\n📋 当前节点列表："
  jq -r '.Nodes[] | "\(.NodeID) | \(.NodeType) | \(.ApiHost)"' "$CONFIG_FILE" | nl -w2 -s'. '
  echo ""
}

add_node() {
  echo "=============================="
  echo "     ⚙️  添加新节点"
  echo "=============================="
  echo ""

  read -rp "请输入节点类型 [ss/hy2] (默认 ss): " NODE_TYPE
  NODE_TYPE=${NODE_TYPE:-ss}

  if [[ "$NODE_TYPE" != "ss" && "$NODE_TYPE" != "hy2" ]]; then
    echo "❌ 节点类型必须是 ss 或 hy2"
    return
  fi

  read -rp "请输入面板地址: " API_HOST
  read -rp "请输入面板 API Key: " API_KEY
  read -rp "请输入节点 ID: " NODE_ID
  read -rp "请输入节点域名: " CERT_DOMAIN

  if [[ -z "$API_HOST" || -z "$API_KEY" || -z "$NODE_ID" || -z "$CERT_DOMAIN" ]]; then
    echo "❌ 参数不能为空"
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

  jq ".Nodes += [$NEW_NODE]" "$CONFIG_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$CONFIG_FILE"
  echo "✅ 节点已添加成功！"
}

delete_node() {
  list_nodes
  read -rp "请输入要删除的节点序号: " IDX
  if [[ -z "$IDX" ]]; then
    echo "❌ 未输入编号"
    return
  fi
  IDX=$((IDX-1))
  jq "del(.Nodes[$IDX])" "$CONFIG_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$CONFIG_FILE"
  echo "🗑️ 节点已删除！"
}

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
  echo "        🧩 V2bX 平台管理菜单"
  echo "=============================="
  echo "1️⃣  查看所有节点"
  echo "2️⃣  添加新节点"
  echo "3️⃣  删除节点"
  echo "4️⃣  重启 V2bX 服务"
  echo "5️⃣  查看实时日志"
  echo "0️⃣  退出"
  echo "=============================="
  read -rp "请输入选项 [0-5]: " CHOICE
  case "$CHOICE" in
    1) list_nodes; read -rp "按回车返回菜单..." ;;
    2) add_node; restart_v2bx; read -rp "按回车返回菜单..." ;;
    3) delete_node; restart_v2bx; read -rp "按回车返回菜单..." ;;
    4) restart_v2bx; read -rp "按回车返回菜单..." ;;
    5) journalctl -u V2bX -f ;;
    0) echo "已退出。"; exit 0 ;;
    *) echo "❌ 无效选项"; sleep 1 ;;
  esac
done
