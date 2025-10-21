#!/bin/bash
BACKUP_DIR="/list/TEMP"
BACKUP_FILE="nanopir5s-backup.tar.gz"

echo "开始备份到 $BACKUP_DIR/$BACKUP_FILE..."
mkdir -p $BACKUP_DIR

# 备份系统配置
sysupgrade -b $BACKUP_DIR/$BACKUP_FILE

# 备份Docker数据（先停止容器）
if command -v docker >/dev/null; then
    echo "停止所有Docker容器..."
    docker stop $(docker ps -aq) 2>/dev/null || true
    
    echo "备份Docker卷数据..."
    docker volume ls -q | while read volume; do
        echo "备份卷: $volume"
        docker run --rm -v $volume:/data -v $BACKUP_DIR:/backup alpine \
            tar -czf /backup/${volume}_data.tar.gz -C /data . 2>/dev/null || true
    done
    
    echo "重新启动Docker容器..."
    docker start $(docker ps -aq) 2>/dev/null || true
fi

echo "备份完成: $BACKUP_DIR/$BACKUP_FILE"
