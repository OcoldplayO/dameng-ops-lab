#!/bin/bash
# ==============================================================================
# 脚本名称: server_health_check.sh (Grafana 可视化复刻增强版)
# ==============================================================================

set -u

# 加载配置
CONF_FILE="/home/dmdba/config/backup_dm8.conf"
if [ -f "${CONF_FILE}" ]; then
    source "${CONF_FILE}"
fi

MAIL_SCRIPT="/home/dmdba/scripts/send_mail.py"
HOST_NAME=$(hostname)
HOST_IP=$(hostname -I | awk '{print $1}')
REPORT_DATE=$(date '+%Y-%m-%d %H:%M:%S')

# 1. 采集 CPU、核心数、负载与使用率
CPU_CORES=$(nproc)
LOAD_1MIN=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' ')
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d'.' -f1)
CPU_USAGE=$((100 - CPU_IDLE))

# 2. 采集 内存 与 Swap
MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
MEM_USED=$(free -m | awk '/Mem:/ {print $3}')
MEM_AVAIL=$(free -m | awk '/Mem:/ {print $7}')
MEM_USAGE_PCT=$(awk "BEGIN {printf \"%.1f\", (${MEM_USED}/${MEM_TOTAL})*100}")

# 3. 采集 磁盘使用率
DISK_ROOT_USAGE=$(df -h / | awk 'NR==2 {print $5}')
DISK_ROOT_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
DISK_DM_USAGE=$(df -h /dmdata 2>/dev/null | awk 'NR==2 {print $5}' || echo "N/A")
DISK_PCT_NUM=$(df / | awk 'NR==2 {print $5}' | tr -d '%')

# 4. 采集 TCP 活跃连接数与开机时间
TCP_ESTAB=$(ss -t state established | grep -v Recv-Q | wc -l)
UPTIME_DAYS=$(awk '{printf "%.2f", $1/86400}' /proc/uptime)

# 5. 动态健康分加权计算算法 (复刻 Grafana 扣分模型)
HEALTH_SCORE=100
# CPU 扣分项
if [ ${CPU_USAGE} -gt 50 ]; then
    HEALTH_SCORE=$((HEALTH_SCORE - (CPU_USAGE - 50) * 4 / 10))
fi
# 内存扣分项
MEM_PCT_INT=${MEM_USAGE_PCT%.*}
if [ ${MEM_PCT_INT} -gt 60 ]; then
    HEALTH_SCORE=$((HEALTH_SCORE - (MEM_PCT_INT - 60) * 4 / 10))
fi
# 磁盘扣分项
if [ ${DISK_PCT_NUM} -gt 80 ]; then
    HEALTH_SCORE=$((HEALTH_SCORE - (DISK_PCT_NUM - 80) * 5 / 10))
fi
if [ ${HEALTH_SCORE} -lt 0 ]; then HEALTH_SCORE=0; fi

# 6. 服务与端口检查
check_service() {
    local srv="$1"
    if systemctl is-active --quiet "${srv}"; then
        echo "<span style='color:#2e7d32;font-weight:bold;'>运行中 (Active)</span>"
    else
        HEALTH_SCORE=$((HEALTH_SCORE - 20))
        echo "<span style='color:#d32f2f;font-weight:bold;'>已停止 (Stopped)</span>"
    fi
}
STATUS_DM=$(check_service "DmServiceDMSERVER")
STATUS_DOCKER=$(check_service "docker")
STATUS_CRON=$(check_service "crond")

check_port() {
    local port="$1"
    local name="$2"
    if ss -tulpn | grep -q ":${port} "; then
        echo "<code>:${port}</code> (${name}) - <span style='color:#2e7d32;'>正常监听</span>"
    else
        HEALTH_SCORE=$((HEALTH_SCORE - 15))
        echo "<code>:${port}</code> (${name}) - <span style='color:#d32f2f;'>未监听</span>"
    fi
}
PORT_DM=$(check_port 5236 "达梦DM8")
PORT_NGINX=$(check_port 443 "HTTPS安全网关")
PORT_PROM=$(check_port 9090 "Prometheus")
PORT_GRAFANA=$(check_port 3000 "Grafana大盘")

# 7. 标题判断
SUB_PREFIX="✅【每日巡检晨报-系统健康】"
HEALTH_COLOR="#2e7d32"
if [ ${HEALTH_SCORE} -lt 80 ]; then
    SUB_PREFIX="🚨【每日巡检晨报-异常预警】"
    HEALTH_COLOR="#d32f2f"
fi

# 8. 构造 Grafana 风格的 HTML 大屏邮件模板
HTML_MSG="
<div style='font-family: Arial, Microsoft YaHei, sans-serif; max-width: 720px; margin: 0 auto; border: 1px solid #dcdfe6; border-radius: 8px; overflow: hidden;'>
    <div style='background-color: #1f2937; color: #fff; padding: 16px 20px;'>
        <h2 style='margin: 0; font-size: 18px;'>📊 openEuler 信创主机每日运维巡检看板</h2>
        <div style='font-size: 12px; color: #9ca3af; margin-top: 4px;'>巡检节点: ${HOST_NAME} (${HOST_IP}) | 报告时间: ${REPORT_DATE}</div>
    </div>

    <!-- 顶部核心指标看板卡片 (复刻 Grafana 概览表) -->
    <div style='padding: 16px; background-color: #f8fafc;'>
        <table style='width: 100%; border-collapse: collapse; text-align: center; background: white; border: 1px solid #e2e8f0; border-radius: 6px;'>
            <tr style='background-color: #0f172a; color: white; font-size: 12px;'>
                <th style='padding: 8px;'>健康值</th>
                <th style='padding: 8px;'>内存总量</th>
                <th style='padding: 8px;'>CPU核心</th>
                <th style='padding: 8px;'>1分负载</th>
                <th style='padding: 8px;'>CPU使用率</th>
                <th style='padding: 8px;'>内存使用率</th>
                <th style='padding: 8px;'>根分区使用率</th>
                <th style='padding: 8px;'>连接数</th>
            </tr>
            <tr style='font-size: 13px; font-weight: bold;'>
                <td style='padding: 10px; color: ${HEALTH_COLOR}; font-size: 15px;'>${HEALTH_SCORE} 分</td>
                <td style='padding: 10px; color: #2563eb;'>${MEM_TOTAL} MB</td>
                <td style='padding: 10px;'>${CPU_CORES} 核</td>
                <td style='padding: 10px;'>${LOAD_1MIN}</td>
                <td style='padding: 10px; color: #0284c7;'>${CPU_USAGE}%</td>
                <td style='padding: 10px; color: #0284c7;'>${MEM_USAGE_PCT}%</td>
                <td style='padding: 10px; color: #475569;'>${DISK_ROOT_USAGE}</td>
                <td style='padding: 10px; color: #16a34a;'>${TCP_ESTAB}</td>
            </tr>
        </table>
    </div>

    <!-- 详细监控数据明细表 -->
    <div style='padding: 0 16px 16px;'>
        <table style='width: 100%; border-collapse: collapse; font-size: 13px;' border='1' bordercolor='#e2e8f0'>
            <tr style='background-color: #f1f5f9; color: #334155;'>
                <th style='padding: 8px; text-align: left;'>监控维度</th>
                <th style='padding: 8px; text-align: left;'>当前水位实测值</th>
                <th style='padding: 8px; text-align: left;'>安全阈值</th>
            </tr>
            <tr>
                <td style='padding: 8px;'><b>CPU 负载</b></td>
                <td style='padding: 8px;'>1分钟负载: <code>${LOAD_1MIN}</code> | 当前占用: <b>${CPU_USAGE}%</b></td>
                <td style='padding: 8px;'><span style='color: #16a34a;'>&lt; 75% (安全)</span></td>
            </tr>
            <tr>
                <td style='padding: 8px;'><b>物理内存</b></td>
                <td style='padding: 8px;'>总计: ${MEM_TOTAL}MB | 已用: ${MEM_USED}MB (<b>${MEM_USAGE_PCT}%</b>) | 剩余: ${MEM_AVAIL}MB</td>
                <td style='padding: 8px;'><span style='color: #16a34a;'>&lt; 85% (充足)</span></td>
            </tr>
            <tr>
                <td style='padding: 8px;'><b>磁盘与数据盘</b></td>
                <td style='padding: 8px;'>根分区 <code>/</code>: <b>${DISK_ROOT_USAGE}</b> (可用: ${DISK_ROOT_AVAIL}) | 达梦数据盘 <code>/dmdata</code>: <b>${DISK_DM_USAGE}</b></td>
                <td style='padding: 8px;'><span style='color: #16a34a;'>&lt; 85% (安全)</span></td>
            </tr>
            <tr>
                <td style='padding: 8px;'><b>系统开机时长</b></td>
                <td style='padding: 8px;'>已平稳运行: <b>${UPTIME_DAYS} 天</b></td>
                <td style='padding: 8px;'><span style='color: #16a34a;'>运行平稳</span></td>
            </tr>
        </table>

        <!-- 服务与端口状态 -->
        <div style='margin-top: 15px; padding: 12px; background-color: #f8fafc; border-left: 4px solid #2563eb; font-size: 13px;'>
            <b>🛡️ 核心服务存活状态：</b><br>
            • 达梦数据库 (DmServiceDMSERVER): ${STATUS_DM}<br>
            • 容器引擎 (Docker Daemon): ${STATUS_DOCKER}<br>
            • 定时任务服务 (Crond Daemon): ${STATUS_CRON}
        </div>

        <div style='margin-top: 10px; padding: 12px; background-color: #f8fafc; border-left: 4px solid #16a34a; font-size: 13px;'>
            <b>🔌 业务端口监听与网关：</b><br>
            • ${PORT_DM}<br>
            • ${PORT_NGINX}<br>
            • ${PORT_PROM}<br>
            • ${PORT_GRAFANA}
        </div>
    </div>
</div>
"

if [ "${MAIL_ENABLED:-0}" -eq 1 ] && [ -f "${MAIL_SCRIPT}" ]; then
    echo "[INFO] 正在推送 Grafana 增强版巡检晨报..."
    python3 "${MAIL_SCRIPT}" "${SUB_PREFIX} ${HOST_NAME} (${HOST_IP})" "${HTML_MSG}" "${MAIL_SENDER}" "${MAIL_AUTH_CODE}" "${MAIL_RECEIVER}"
fi
