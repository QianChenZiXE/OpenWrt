#!/bin/bash
#设置执行权限: chmod +x /root/Clean_Temp.sh
#脚本存放目录: /root/Clean_Temp.sh
#定时规则路径: /etc/crontabs/root
#定时执行内容: 0 0 * * * /bin/bash /root/Clean_Temp.sh

TEMP_DIR="/list/TEMP"
if [ ! -d "$TEMP_DIR" ]; then
    mkdir -p "$TEMP_DIR"
    if [ $? -eq 0 ]; then
        echo "[$(date)] 目录创建成功: $TEMP_DIR"
    else
        echo "[$(date)] 错误：无法创建目录 $TEMP_DIR" >&2
        exit 1
    fi
else
    rm -rf "$TEMP_DIR"/*
    echo "[$(date)] 已清空目录: $TEMP_DIR"
fi
