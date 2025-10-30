#!/bin/bash
# ===========================================
#   V2bX 多平台 chroot 管理器
#   作者: nuro (https://github.com/nuro-hia)
#   功能: 隔离运行多个 V2bX 面板实例
# ===========================================

BASE_DIR="/srv"
CHROOT_PREFIX="v2bx"
DEBIAN_MIRROR="http://deb.debian.org/debian"

green="\033[32m"
red="\033[31m"
yellow="\033[33m"
plain="\033[0m"

check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${red}必须以 root 身份运行${plain}"
    exit 1
  fi
}

pause() {
  echo ""
  read -rp "按回车返回菜单..." _
}

list_platforms() {
  echo -e "\n📦 当前已创建的平台实例："
  ls -1 ${BASE_DIR} | grep "^${CHROOT_PREFIX}-" | sed "s/^/${green}- /;s/$/${plain}/" || echo "暂无实例"
}

create_platform() {
  read -rp "请输入新平台名称 (例如 mist、cloud、hk): " NAME
  [[ -z "$NAME" ]] && echo -e "${red}平台名称不能为空${plain}" && return

  TARGET="${BASE_DIR}/${CHROOT_PREFIX}-${NAME}"

  if [[ -d "$TARGET" ]]; then
    echo -e "${yellow}该平台已存在: ${TARGET}${plain}"
    return
  fi

  echo -e "${green}正在创建 chroot 环境: ${TARGET}${plain}"
  mkdir -p "$TARGET"

  echo -e "${green}下载并安装最小 Debian 系统...${plain}"
  apt-get update -y >/dev/null 2>&1
  apt-get install -y debootstrap >/dev/null 2>&1

  debootstrap --arch=amd64 stable "$TARGET" "$DEBIAN_MIRROR"

  echo -e "${green}挂载系统目录...${plain}"
  mount --bind /dev "$TARGET/dev"
  mount --bind /proc "$TARGET/proc"
  mount --bind /sys "$TARGET/sys"

  echo "127.0.0.1 localhost" > "$TARGET/etc/hosts"

  echo -e "${green}配置网络共享...${plain}"
  cp /etc/resolv.conf "$TARGET/etc/resolv.conf"

  echo -e "${green}chroot 环境创建完成！${plain}"
  echo -e "👉 使用以下命令进入:\n${yellow}chroot $TARGET /bin/bash${plain}"
  pause
}

enter_platform() {
  echo ""
  echo -e "请选择要进入的平台："
  list=($(ls -1 ${BASE_DIR} | grep "^${CHROOT_PREFIX}-"))
  if [[ ${#list[@]} -eq 0 ]]; then
    echo -e "${red}暂无平台实例${plain}"
    pause
    return
  fi

  i=1
  for name in "${list[@]}"; do
    echo "$i. $name"
    ((i++))
  done

  read -rp "请输入编号: " choice
  idx=$((choice-1))
  [[ -z "${list[$idx]}" ]] && echo -e "${red}无效编号${plain}" && return
  TARGET="${BASE_DIR}/${list[$idx]}"

  echo -e "${green}挂载系统目录中...${plain}"
  mount --bind /dev "$TARGET/dev"
  mount --bind /proc "$TARGET/proc"
  mount --bind /sys "$TARGET/sys"

  echo -e "${green}进入 chroot 环境: ${TARGET}${plain}"
  echo -e "${yellow}在其中可直接执行官方 V2bX 安装命令${plain}"
  echo -e "${yellow}退出请输入 exit${plain}"
  chroot "$TARGET" /bin/bash
}

delete_platform() {
  echo ""
  echo -e "请选择要删除的平台："
  list=($(ls -1 ${BASE_DIR} | grep "^${CHROOT_PREFIX}-"))
  if [[ ${#list[@]} -eq 0 ]]; then
    echo -e "${red}暂无平台实例${plain}"
    pause
    return
  fi

  i=1
  for name in "${list[@]}"; do
    echo "$i. $name"
    ((i++))
  done

  read -rp "请输入编号: " choice
  idx=$((choice-1))
  [[ -z "${list[$idx]}" ]] && echo -e "${red}无效编号${plain}" && return
  TARGET="${BASE_DIR}/${list[$idx]}"

  echo -e "${yellow}确认删除 ${TARGET} ? 此操作不可恢复！(y/N):${plain} "
  read -r confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    umount -lf "$TARGET/dev" 2>/dev/null
    umount -lf "$TARGET/proc" 2>/dev/null
    umount -lf "$TARGET/sys" 2>/dev/null
    rm -rf "$TARGET"
    echo -e "${green}已删除平台 ${TARGET}${plain}"
  else
    echo "已取消"
  fi
  pause
}

main_menu() {
  check_root
  clear
  echo -e "${green}==============================${plain}"
  echo -e "     V2bX 多平台 chroot 管理器"
  echo -e "${green}==============================${plain}"
  echo -e "1. 创建新平台实例"
  echo -e "2. 进入平台终端"
  echo -e "3. 删除平台实例"
  echo -e "4. 查看所有平台"
  echo -e "5. 退出"
  echo ""

  read -rp "请选择 [1-5]: " num
  case "$num" in
    1) create_platform ;;
    2) enter_platform ;;
    3) delete_platform ;;
    4) list_platforms; pause ;;
    5) exit 0 ;;
    *) echo -e "${red}无效选项${plain}"; pause ;;
  esac
}

while true; do
  main_menu
done
