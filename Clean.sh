#!/bin/bash
# 设置执行权限: chmod +x /root/Clean.sh
# 脚本存放目录: /root/Clean.sh
# 定时规则路径: /etc/crontabs/root
# 定时执行内容: 0 0 * * * /bin/bash /root/Clean.sh

CLEAN_DIR="/overlay/upper/tem/Config"

if [ ! -d "$CLEAN_DIR" ]; then
    mkdir -p "$CLEAN_DIR"
    if [ $? -eq 0 ]; then
        echo "[$(date)] 目录创建成功: $CLEAN_DIR"
    else
        echo "[$(date)] 错误：无法创建目录 $CLEAN_DIR" >&2
        exit 1
    fi
else
    rm -rf "$CLEAN_DIR"/*
    echo "[$(date)] 已清空目录: $CLEAN_DIR"
fi

# 清理 Jellyfin 缓存
rm -rf /overlay/upper/tem/jellyfin/cache/images/resized-images/* /overlay/upper/tem/jellyfin/cache/temp/* /overlay/upper/tem/jellyfin/cache/omdb/*

# 清理 Halo 日志文件
rm -rf /overlay/upper/tem/halo/logs/*
