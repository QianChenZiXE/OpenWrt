#!/bin/bash

echo "=== 一键部署脚本 ==="

# 下载必要的脚本文件
wget -q https://raw.githubusercontent.com/QianChenZiXE/OpenWrt/main/Clean_Temp.sh -O /root/Clean_Temp.sh
wget -q https://raw.githubusercontent.com/QianChenZiXE/OpenWrt/main/PassWall.sh -O /root/PassWall.sh

# 设置权限
chmod +x /root/Clean_Temp.sh
chmod +x /root/PassWall.sh

# 清理现有定时任务并添加新任务
(crontab -l 2>/dev/null | grep -v -e "Clean_Temp.sh" -e "PassWall.sh"; echo "0 0 * * * /bin/bash /root/Clean_Temp.sh"; echo "*/10 * * * * /bin/bash /root/PassWall.sh") | crontab -

# 重启服务
/etc/init.d/cron restart

echo " 部署完成！"
