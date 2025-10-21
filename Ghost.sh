#!/bin/bash
#  OpenWrt 全配置 + Docker 完整备份/还原脚本
#  适配 BusyBox tar：用 -v 代替 --checkpoint，进度可见
set -euo pipefail

#============================ 用户可调路径 ============================
BACKUP_DIR="/list/TEMP"                       # 备份存放目录
DOCKER_ROOT="/opt/docker"                     # Docker 数据根
DOCKER_COMPOSE_DIR="/opt/docker-compose"      # compose 项目目录
DOCKER_VOLUMES="/var/lib/docker/volumes"      # Docker 卷目录
#====================================================================
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="openwrt_full_backup_${DATE}.tar.gz"
LOG_FILE="${BACKUP_DIR}/backup_restore.log"

#-------------------- 工具函数 --------------------
log() {
    echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

check_backup_dir() {
    [ -d "$BACKUP_DIR" ] || mkdir -p "$BACKUP_DIR"
}

#==================== 备份（BusyBox 友好） ====================
full_backup() {
    log "开始完整备份..."
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT

    # 1. 系统配置：先导出有效节点，再手动打包，避免 uci 报错
    log "备份系统配置..."
    uci show 2>/dev/null | grep -E '^\w+\.\w+\=' | cut -d= -f1 | sort -u > "$TEMP_DIR/uci_valid.list"
    mkdir -p "$TEMP_DIR/etc_config"
    while read -r node; do
        cfg_file="/etc/config/${node%%.*}"
        [ -f "$cfg_file" ] && cp "$cfg_file" "$TEMP_DIR/etc_config/"
    done < "$TEMP_DIR/uci_valid.list"
    tar -czf "$TEMP_DIR/sysupgrade_backup.tar.gz" -C "$TEMP_DIR" etc_config

    # 2. 软件列表
    log "备份已安装软件列表..."
    opkg list-installed | cut -f 1 -d ' ' > "$TEMP_DIR/installed_packages.txt"

    # 3. Docker 数据（用 -v 实时打印文件名）
    log "备份 Docker 数据..."
    [ -d "$DOCKER_ROOT" ] && \
        tar -czvf "$TEMP_DIR/docker_data.tar.gz" -C "$DOCKER_ROOT" . >/dev/null 2>&1 || true
    [ -d "$DOCKER_COMPOSE_DIR" ] && \
        tar -czvf "$TEMP_DIR/docker_compose.tar.gz" -C "$DOCKER_COMPOSE_DIR" . >/dev/null 2>&1 || true
    [ -d "$DOCKER_VOLUMES" ] && \
        tar -czvf "$TEMP_DIR/docker_volumes.tar.gz" -C "$DOCKER_VOLUMES" . >/dev/null 2>&1 || true

    # 4. 其余配置
    [ -d /etc/config ] && tar -czvf "$TEMP_DIR/config.tar.gz" -C /etc config >/dev/null 2>&1 || true
    [ -d /etc/init.d ] && tar -czvf "$TEMP_DIR/init.d.tar.gz" -C /etc init.d >/dev/null 2>&1 || true
    [ -d /root ] && tar -czvf "$TEMP_DIR/root.tar.gz" -C / root >/dev/null 2>&1 || true
    for f in network wireless firewall dhcp dockerd; do
        [ -f "/etc/config/$f" ] && cp "/etc/config/$f" "$TEMP_DIR/"
    done
    [ -f /etc/docker/daemon.json ] && cp /etc/docker/daemon.json "$TEMP_DIR/"

    # 5. 备份信息
    cat > "$TEMP_DIR/backup_info.txt" <<EOF
备份时间: $(date)
OpenWrt 版本: $(grep DISTRIB_DESCRIPTION /etc/openwrt_release | cut -d"'" -f2)
内核版本: $(uname -r)
Docker 版本: $(docker --version 2>/dev/null || echo "未安装")
备份文件: $BACKUP_DIR/$BACKUP_NAME
EOF

    # 6. 最终打包（同样用 -v 可见进度）
    log "打包所有备份数据..."
    tar -czvf "$BACKUP_DIR/$BACKUP_NAME" -C "$TEMP_DIR" . >/dev/null 2>&1
    log "备份完成：$BACKUP_DIR/$BACKUP_NAME （$(du -h "$BACKUP_DIR/$BACKUP_NAME" | cut -f1)）"
}

#==================== 还原（成功后 5 秒重启） ====================
full_restore() {
    local backup_file="$1"
    [ -f "$backup_file" ] || { log "备份文件不存在"; exit 1; }

    log "开始还原：$backup_file"
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    tar -xzf "$backup_file" -C "$TEMP_DIR"
    [ -f "$TEMP_DIR/backup_info.txt" ] && cat "$TEMP_DIR/backup_info.txt"

    # 1. 停止 Docker
    /etc/init.d/dockerd stop 2>/dev/null || true
    /etc/init.d/docker stop 2>/dev/null || true

    # 2. 清理旧数据
    rm -rf "$DOCKER_ROOT"/* "$DOCKER_VOLUMES"/* "$DOCKER_COMPOSE_DIR"/*

    # 3. 系统配置
    [ -f "$TEMP_DIR/sysupgrade_backup.tar.gz" ] && sysupgrade -r "$TEMP_DIR/sysupgrade_backup.tar.gz"

    # 4. 还原 Docker / Compose / Volumes
    [ -f "$TEMP_DIR/docker_data.tar.gz" ] && { mkdir -p "$DOCKER_ROOT"; tar -xzf "$TEMP_DIR/docker_data.tar.gz" -C "$DOCKER_ROOT"; }
    [ -f "$TEMP_DIR/docker_compose.tar.gz" ] && { mkdir -p "$DOCKER_COMPOSE_DIR"; tar -xzf "$TEMP_DIR/docker_compose.tar.gz" -C "$DOCKER_COMPOSE_DIR"; }
    [ -f "$TEMP_DIR/docker_volumes.tar.gz" ] && { mkdir -p "$DOCKER_VOLUMES"; tar -xzf "$TEMP_DIR/docker_volumes.tar.gz" -C "$DOCKER_VOLUMES"; }

    # 5. 网络 & Docker 守护进程配置
    for f in network wireless firewall dhcp dockerd; do
        [ -f "$TEMP_DIR/$f" ] && cp "$TEMP_DIR/$f" /etc/config/
    done
    [ -f "$TEMP_DIR/daemon.json" ] && { mkdir -p /etc/docker; cp "$TEMP_DIR/daemon.json" /etc/docker/; }

    # 6. 其它配置
    [ -f "$TEMP_DIR/config.tar.gz" ] && tar -xzf "$TEMP_DIR/config.tar.gz" -C /
    [ -f "$TEMP_DIR/init.d.tar.gz" ] && tar -xzf "$TEMP_DIR/init.d.tar.gz" -C /
    [ -f "$TEMP_DIR/root.tar.gz" ] && tar -xzf "$TEMP_DIR/root.tar.gz" -C /

    # 7. 重装软件
    if [ -f "$TEMP_DIR/installed_packages.txt" ]; then
        while IFS= read -r pkg; do
            opkg install "$pkg" 2>/dev/null || log "警告：无法安装 $pkg"
        done < "$TEMP_DIR/installed_packages.txt"
    fi

    # 8. 启动 Docker
    /etc/init.d/dockerd start
    /etc/init.d/docker start
    for i in {1..30}; do
        docker info >/dev/null 2>&1 && { log "Docker 已启动"; break; }
        sleep 2
    done

    # 9. 启动 Compose 项目
    if [ -d "$DOCKER_COMPOSE_DIR" ]; then
        find "$DOCKER_COMPOSE_DIR" -name docker-compose.yml | while read yml; do
            dir=$(dirname "$yml")
            log "启动 Compose：$dir"
            (cd "$dir" && docker-compose up -d) || log "警告：启动失败 $dir"
        done
    fi

    # 10. 重启网络
    /etc/init.d/network restart
    /etc/init.d/firewall restart
    /etc/init.d/dnsmasq restart

    log "还原完成！"

    # ====== 5 秒倒计时重启 ======
    echo -n ">>> 系统将在 5 秒后重启 "
    for i in {5..1}; do
        echo -n "$i "
        sleep 1
    done
    echo
    reboot
}

#-------------------- Docker 单独备份/还原 --------------------
backup_docker_projects() {
    log "开始 Docker 项目备份..."
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT

    docker ps -aq | while read c; do
        name=$(docker inspect --format='{{.Name}}' "$c" | sed 's/^\///')
        docker export "$c" > "$TEMP_DIR/container_${name}.tar"
    done

    docker images --format "{{.Repository}}:{{.Tag}}" | while read img; do
        [ "$img" = "<none>:<none>" ] && continue
        docker save "$img" > "$TEMP_DIR/image_${img//[\/:]/_}.tar"
    done

    [ -d "$DOCKER_VOLUMES" ] && tar -czf "$TEMP_DIR/docker_volumes_backup.tar.gz" -C "$DOCKER_VOLUMES" .
    local docker_backup="docker_projects_backup_${DATE}.tar.gz"
    tar -czf "$BACKUP_DIR/$docker_backup" -C "$TEMP_DIR" .
    log "Docker 项目备份完成：$BACKUP_DIR/$docker_backup"
}

restore_docker_projects() {
    local back="$1"
    [ -f "$back" ] || { log "Docker 备份文件不存在"; exit 1; }
    log "开始 Docker 项目还原..."
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    tar -xzf "$back" -C "$TEMP_DIR"

    docker stop $(docker ps -aq) 2>/dev/null || true
    docker rm $(docker ps -aq) 2>/dev/null || true

    [ -f "$TEMP_DIR/docker_volumes_backup.tar.gz" ] && {
        rm -rf "$DOCKER_VOLUMES"/*
        tar -xzf "$TEMP_DIR/docker_volumes_backup.tar.gz" -C "$DOCKER_VOLUMES"
    }

    for img in "$TEMP_DIR"/image_*.tar; do
        [ -f "$img" ] && docker load < "$img"
    done

    for con in "$TEMP_DIR"/container_*.tar; do
        [ -f "$con" ] || continue
        name=$(basename "$con" | sed 's/^container_//;s/\.tar$//')
        docker import "$con" "${name}:restored"
    done
    log "Docker 项目还原完成"
}

#-------------------- 辅助 --------------------
list_backups() {
    [ -d "$BACKUP_DIR" ] && ls -lht "$BACKUP_DIR" | grep -E '\.tar\.gz$' || log "备份目录不存在"
}

show_help() {
    cat << EOF
用法：Ghost.sh 命令 [参数]
  backup                    完整备份（实时显示文件名进度）
  backup-docker             仅备份 Docker
  restore <文件>            完整还原（成功后 5 秒重启）
  restore-docker <文件>     仅还原 Docker
  list                      列出已有备份
  help                      显示本帮助
EOF
}

#-------------------- 主入口 --------------------
main() {
    case "${1:-}" in
        backup)           check_backup_dir; full_backup ;;
        backup-docker)    check_backup_dir; backup_docker_projects ;;
        restore)          [ -n "${2:-}" ] && full_restore "$2" || { log "缺少备份文件"; show_help; exit 1; } ;;
        restore-docker)   [ -n "${2:-}" ] && restore_docker_projects "$2" || { log "缺少备份文件"; show_help; exit 1; } ;;
        list)             list_backups ;;
        help|--help|-h)   show_help ;;
        *)                log "未知命令"; show_help; exit 1 ;;
    esac
}

#-------------------- 权限 & 依赖检查 --------------------
[ "$(id -u)" -eq 0 ] || { echo "需 root 运行"; exit 1; }
for cmd in tar docker opkg sysupgrade; do
    command -v "$cmd" >/dev/null || { echo "缺少命令: $cmd"; exit 1; }
done

main "$@"
