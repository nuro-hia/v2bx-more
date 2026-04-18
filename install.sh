#!/bin/bash
# ==========================================
#  🌿 V2bX 多平台管理菜单（ss / hy2 / trojan / vless / anytls）
#  作者: nuro 定制版
# ==========================================

CONFIG_FILE="/etc/V2bX/config.json"
BACKUP_DIR="/etc/V2bX/backup"
TEMP_FILE="/tmp/v2bx_config_tmp.json"

# 检查并安装 jq
check_jq() {
  if ! command -v jq &>/dev/null; then
    echo "🌱 正在安装 jq..."
    apt update -y >/dev/null 2>&1
    apt install jq -y >/dev/null 2>&1
  fi
}

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
  echo "✨ 安装完成，请重新进入菜单操作。"
}

# 查看节点
list_nodes() {
  check_jq
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ 未找到配置文件，请先安装 V2bX。"
    return
  fi
  echo "📋 当前节点列表："
  echo "序号 | NodeID | Core | 类型 | 面板地址 | 域名"
  echo "--------------------------------------------------------------"
  jq -r '.Nodes[] | "\(.NodeID) | \(.Core) | \(.NodeType) | \(.ApiHost) | \(.CertConfig.CertDomain // "-")"' "$CONFIG_FILE" | nl -w2 -s'. '
}

# 添加节点
add_node() {
  if ! check_v2bx; then
    echo "❌ 未检测到 V2bX，请先安装。"
    read -rp "是否立即安装？(y/n): " ADD_INSTALL
    if [[ "$ADD_INSTALL" == "y" ]]; then
      install_v2bx
    fi
    return
  fi

  check_jq
  mkdir -p "$(dirname "$CONFIG_FILE")"

  if [[ ! -f "$CONFIG_FILE" ]]; then
    cat >"$CONFIG_FILE" <<'EOF'
{
  "Log": {},
  "Cores": [],
  "Nodes": []
}
EOF
  fi

  echo "=============================="
  echo "⚙️  添加新节点"
  echo "=============================="

  while true; do
    echo "🧠 请选择要使用的核心:"
    echo "  1) sing (默认)"
    echo "  2) xray"
    read -rp "请输入编号 [1-2]: " CORE_CHOICE
    if [[ -z "$CORE_CHOICE" || "$CORE_CHOICE" == "1" ]]; then
      CORE_TYPE="sing"
      break
    elif [[ "$CORE_CHOICE" == "2" ]]; then
      CORE_TYPE="xray"
      break
    else
      echo "❌ 无效输入，请重新选择。"
      echo ""
    fi
  done

  # 2. 选择节点类型 (严格数字校验)
  while true; do
    echo ""
    echo "📦 请选择节点类型:"
    if [[ "$CORE_TYPE" == "sing" ]]; then
      echo "  1) ss (默认)"
      echo "  2) vless"
      echo "  3) hy2"
      echo "  4) trojan"
      echo "  5) anytls"
      read -rp "请输入编号 [1-5]: " NODE_CHOICE
      if [[ -z "$NODE_CHOICE" || "$NODE_CHOICE" == "1" ]]; then
        NODE_TYPE="ss"
        break
      elif [[ "$NODE_CHOICE" == "2" ]]; then
        NODE_TYPE="vless"
        break
      elif [[ "$NODE_CHOICE" == "3" ]]; then
        NODE_TYPE="hy2"
        break
      elif [[ "$NODE_CHOICE" == "4" ]]; then
        NODE_TYPE="trojan"
        break
      elif [[ "$NODE_CHOICE" == "5" ]]; then
        NODE_TYPE="anytls"
        break
      else
        echo "❌ 无效输入，请重新选择。"
      fi
    else
      echo "  1) ss (默认)"
      echo "  2) hy2"
      echo "  3) trojan"
      read -rp "请输入编号 [1-3]: " NODE_CHOICE
      if [[ -z "$NODE_CHOICE" || "$NODE_CHOICE" == "1" ]]; then
        NODE_TYPE="ss"
        break
      elif [[ "$NODE_CHOICE" == "2" ]]; then
        NODE_TYPE="hy2"
        break
      elif [[ "$NODE_CHOICE" == "3" ]]; then
        NODE_TYPE="trojan"
        break
      else
        echo "❌ 无效输入，请重新选择。"
      fi
    fi
  done

  # 严格参数映射
  case "$NODE_TYPE" in
    ss)     NODE_TYPE_FULL="shadowsocks"; TCP="true";  CERT_MODE="http"; LISTEN_IP="0.0.0.0" ;;
    hy2)    NODE_TYPE_FULL="hysteria2";   TCP="false"; CERT_MODE="http"; LISTEN_IP="0.0.0.0" ;;
    trojan) NODE_TYPE_FULL="trojan";      TCP="true";  CERT_MODE="http"; LISTEN_IP="0.0.0.0" ;;
    vless)  NODE_TYPE_FULL="vless";       TCP="true";  CERT_MODE="none"; LISTEN_IP="::"      ;;
    anytls) NODE_TYPE_FULL="anytls";      TCP="false"; CERT_MODE="http"; LISTEN_IP="::"      ;;
  esac

  echo ""
  read -rp "🪧 面板地址 (例: https://api.domain.com): " API_HOST
  read -rp "🔑 API Key: " API_KEY
  read -rp "🆔 节点 ID: " NODE_ID
  
  if [[ "$NODE_TYPE" == "vless" ]]; then
      CERT_DOMAIN="example.com"
  else
      read -rp "🌐 节点域名: " CERT_DOMAIN
  fi

  if [[ -z "$API_HOST" || -z "$API_KEY" || -z "$NODE_ID" || -z "$CERT_DOMAIN" ]]; then
    echo "❌ 参数不能为空，添加失败。"
    return
  fi

  # 4. JSON 配置写入
  if [[ "$CORE_TYPE" == "xray" ]]; then
    NEW_NODE=$(cat <<EOF
{
  "Core": "xray",
  "ApiHost": "$API_HOST",
  "ApiKey": "$API_KEY",
  "NodeID": $NODE_ID,
  "NodeType": "$NODE_TYPE_FULL",
  "Timeout": 30,
  "ListenIP": "$LISTEN_IP",
  "SendIP": "0.0.0.0",
  "DeviceOnlineMinTraffic": 1000,
  "EnableProxyProtocol": false,
  "EnableUot": true,
  "EnableTFO": true,
  "DNSType": "UseIPv4",
  "CertConfig": {
    "CertMode": "$CERT_MODE",
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
  else
    NEW_NODE=$(cat <<EOF
{
  "Core": "sing",
  "ApiHost": "$API_HOST",
  "ApiKey": "$API_KEY",
  "NodeID": $NODE_ID,
  "NodeType": "$NODE_TYPE_FULL",
  "Timeout": 30,
  "ListenIP": "$LISTEN_IP",
  "SendIP": "0.0.0.0",
  "DeviceOnlineMinTraffic": 200,
  "MinReportTraffic": 0,
  "TCPFastOpen": $TCP,
  "SniffEnabled": true,
  "CertConfig": {
    "CertMode": "$CERT_MODE",
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
  fi

  jq ".Nodes += [$NEW_NODE]" "$CONFIG_FILE" >"$TEMP_FILE" && mv "$TEMP_FILE" "$CONFIG_FILE"
  echo "✅ 节点 ($NODE_TYPE_FULL) 添加成功（Core=$CORE_TYPE）。"
  restart_v2bx
}

# 删除节点
delete_node() {
  if ! check_v2bx; then
    echo "❌ 未检测到 V2bX，请先安装。"
    read -rp "是否立即安装？(y/n): " ADD_INSTALL
    if [[ "$ADD_INSTALL" == "y" ]]; then
      install_v2bx
    fi
    return
  fi

  list_nodes
  read -rp "🗑️ 请输入要删除的节点序号: " IDX
  [[ -z "$IDX" ]] && echo "❌ 未输入编号。" && return
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
  FILES=($(ls -1 "$BACKUP_DIR"/config_*.json 2>/dev/null))
  [[ ${#FILES[@]} -eq 0 ]] && echo "❌ 没有备份文件。" && return

  echo "📂 可用备份文件："
  for i in "${!FILES[@]}"; do echo "$((i + 1))) ${FILES[$i]}"; done
  read -rp "📥 请输入要恢复的编号: " IDX
  [[ "$IDX" -lt 1 || "$IDX" -gt ${#FILES[@]} ]] && echo "❌ 无效编号。" && return
  cp "${FILES[$((IDX - 1))]}" "$CONFIG_FILE"
  echo "✅ 已恢复配置：${FILES[$((IDX - 1))]}"
  restart_v2bx
}

# 删除备份
delete_backup() {
  FILES=($(ls -1 "$BACKUP_DIR"/config_*.json 2>/dev/null))
  [[ ${#FILES[@]} -eq 0 ]] && echo "❌ 没有备份文件。" && return

  echo "📂 当前备份文件："
  for i in "${!FILES[@]}"; do echo "$((i + 1))) ${FILES[$i]}"; done
  read -rp "🗑️ 请输入要删除的编号: " IDX
  [[ "$IDX" -lt 1 || "$IDX" -gt ${#FILES[@]} ]] && echo "❌ 无效编号。" && return
  rm -f "${FILES[$((IDX - 1))]}"
  echo "✅ 已删除：${FILES[$((IDX - 1))]}"
}

# 卸载 V2bX
uninstall_v2bx() {
  if check_v2bx; then
    echo "⚠️ 正在卸载 V2bX ..."
    V2bX uninstall
    rm -f /usr/bin/V2bX
    echo "🧹 已卸载 V2bX 主程序。"
  else
    echo "❌ 未检测到 V2bX。"
  fi
  if command -v jq &>/dev/null; then
    read -rp "是否同时卸载 jq？(y/n): " RM_JQ
    [[ "$RM_JQ" == "y" ]] && apt remove -y jq >/dev/null 2>&1 && echo "🧹 已卸载 jq。"
  fi
}

# 重启服务
restart_v2bx() {
  echo "🔁 正在重启 V2bX..."
  V2bX restart
  sleep 2
}

# === 主菜单 ===
while true; do
  clear
  echo "=============================="
  echo "        🌿 V2bX 多平台管理菜单"
  echo "=============================="
  echo "1) 安装 V2bX"
  echo "2) 添加新节点"
  echo "3) 删除节点"
  echo "4) 查看所有节点"
  echo "5) 备份配置"
  echo "6) 恢复配置"
  echo "7) 删除备份文件"
  echo "8) 重启 V2bX"
  echo "9) 查看实时日志"
  echo "10) 卸载 V2bX"
  echo "0) 退出菜单"
  echo "=============================="
  read -rp "请输入选项 [0-10]: " CHOICE
  case "$CHOICE" in
    1) install_v2bx; read -rp "按回车返回菜单..." ;;
    2) add_node; read -rp "按回车返回菜单..." ;;
    3) delete_node; read -rp "按回车返回菜单..." ;;
    4) list_nodes; read -rp "按回车返回菜单..." ;;
    5) backup_config; read -rp "按回车返回菜单..." ;;
    6) restore_config; read -rp "按回车返回菜单..." ;;
    7) delete_backup; read -rp "按回车返回菜单..." ;;
    8) restart_v2bx; read -rp "按回车返回菜单..." ;;
    9) journalctl -u V2bX -f ;;
    10) uninstall_v2bx; read -rp "按回车返回菜单..." ;;
    0) echo "👋 已退出菜单。"; exit 0 ;;
    *) echo "❌ 无效选项，请重新输入。"; sleep 1 ;;
  esac
done
