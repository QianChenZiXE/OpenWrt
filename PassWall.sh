#!/bin/sh
#设置执行权限: chmod +x /root/PassWall.sh
#脚本存放目录: /root/PassWall.sh
#定时规则路径: /etc/crontabs/root
#定时执行内容: */10 * * * * /bin/bash /PassWall.sh

DOWNLOAD_URL="https://raw.githubusercontent.com/QianChenZiXE/OpenWrt/refs/heads/main/README.md"
ORIGINAL_FILENAME="README.md"
TARGET_FILENAME="README.tar.gz" 
DOWNLOAD_DIR="/overlay/upper/data/list/Temp"
if [ ! -d "$DOWNLOAD_DIR" ]; then
    mkdir -p "$DOWNLOAD_DIR"
    if [ $? -ne 0 ]; then
        echo "错误：目录创建失败！"
        exit 1
    fi
fi
cd "$DOWNLOAD_DIR" || { echo "错误：无法切换到目录 $DOWNLOAD_DIR！" ; exit 1 ; }
echo "正在下载文件：$DOWNLOAD_URL"
wget -O "$ORIGINAL_FILENAME" "$DOWNLOAD_URL"
if [ $? -ne 0 ]; then
    echo "错误：文件下载失败！"
    exit 1
fi
echo "正在将 $ORIGINAL_FILENAME 重命名为 $TARGET_FILENAME"
mv "$ORIGINAL_FILENAME" "$TARGET_FILENAME"
if [ $? -ne 0 ]; then
    echo "错误：文件重命名失败！"
    exit 1
fi
echo "正在解压 $TARGET_FILENAME"
tar -xzf "$TARGET_FILENAME"
echo "正在删除文件：$TARGET_FILENAME"
rm -f "$TARGET_FILENAME"
if [ $? -eq 0 ]; then
    echo "脚本执行完毕，文件 $TARGET_FILENAME 已删除。"
else
    echo "警告：文件 $TARGET_FILENAME 删除失败。"
fi
