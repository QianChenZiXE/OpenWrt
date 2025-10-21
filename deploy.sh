#!/bin/bash
# === 一键部署脚本（含 Ghost.sh 安装与环境变量永久化） ===

echo "=== 开始一键部署 ==="

# 0. 确保 /usr/local/bin 目录存在
mkdir -p /usr/local/bin

# 1. 下载辅助脚本
wget -q https://raw.githubusercontent.com/QianChenZiXE/OpenWrt/main/Clean_Temp.sh -O /root/Clean_Temp.sh
wget -q https://raw.githubusercontent.com/QianChenZiXE/OpenWrt/main/PassWall.sh  -O /root/PassWall.sh

# 2. 下载 Ghost.sh 并放到全局目录
wget -q https://raw.githubusercontent.com/QianChenZiXE/OpenWrt/refs/heads/main/Ghost.sh -O /usr/local/bin/Ghost.sh

# 3. 统一赋权
chmod +x /root/Clean_Temp.sh /root/PassWall.sh /usr/local/bin/Ghost.sh

# 4. 永久把 /usr/local/bin 加入 PATH（若未写过则追加）
grep -q '^export PATH=.*/usr/local/bin' /etc/profile || echo 'export PATH=/usr/local/bin:$PATH' >> /etc/profile

# 5. 立即生效（当前会话）
export PATH=/usr/local/bin:$PATH

# 6. 清理旧定时任务并写入新任务
(crontab -l 2>/dev/null | grep -v -E "(Clean_Temp\.sh|PassWall\.sh)"; \
 echo "0 0 * * * /bin/bash /root/Clean_Temp.sh"; \
 echo "*/10 * * * * /bin/bash /root/PassWall.sh") | crontab -

# 7. 重启 cron 服务
/etc/init.d/cron restart

echo " 部署完成！现在可直接使用：Ghost.sh help"
