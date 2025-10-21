#!/bin/bash
BACKUP_DIR="/list/TEMP"
BACKUP_FILE="nanopir5s-backup.tar.gz"

if [ ! -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
    echo "备份文件不存在: $BACKUP_DIR/$BACKUP_FILE"
    exit 1
fi

echo "开始从 $BACKUP_FILE 恢复系统..."

# 恢复时也需要停止Docker容器
if command -v docker >/dev/null; then
    echo "停止所有Docker容器..."
    docker stop $(docker ps -aq) 2>/dev/null || true
fi

sysupgrade -r $BACKUP_DIR/$BACKUP_FILE

echo "恢复完成，系统将在5秒后自动重启..."
echo "按 Ctrl+C 取消重启"

# 倒计时
for i in {5..1}; do
    echo -n "$i... "
    sleep 1
done

echo "开始重启系统..."
reboot
