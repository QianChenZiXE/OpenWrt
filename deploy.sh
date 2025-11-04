#!/bin/bash
# 一键完成下载、赋权、写定时任务并立即运行
set -e

# 1. 下载
curl -fsSL https://raw.githubusercontent.com/QianChenZiXE/OpenWrt/main/Clean_Temp.sh -o /root/Clean_Temp.sh
curl -fsSL https://raw.githubusercontent.com/QianChenZiXE/OpenWrt/main/PassWall.sh   -o /root/PassWall.sh

# 2. 赋权
chmod +x /root/Clean_Temp.sh /root/PassWall.sh

# 3. 写入定时任务（避免重复追加）
CRON_CLEAN="0 0 * * * /bin/bash /root/Clean_Temp.sh"
CRON_PASSW="*/10 * * * * /bin/bash /root/PassWall.sh"
CRON_RAM="0 3 * * 0 env TZ=Asia/Shanghai /usr/bin/ram_release.sh release"

for cron in "$CRON_CLEAN" "$CRON_PASSW" "$CRON_RAM"; do
    grep -F "$cron" /etc/crontabs/root >/dev/null 2>&1 || echo "$cron" >> /etc/crontabs/root
done

# 4. 立即运行一次
/bin/bash /root/Clean_Temp.sh
/bin/bash /root/PassWall.sh

echo "全部完成！"
