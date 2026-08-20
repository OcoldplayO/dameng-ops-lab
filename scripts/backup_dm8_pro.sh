#!/bin/bash
# ==============================================================================
# 脚本名称: backup_dm8_pro.sh (修复日志冲突与交互阻塞版)
# ==============================================================================

set -u

# 加载外部配置
CONF_FILE="/home/dmdba/config/backup_dm8.conf"
if [ ! -f "${CONF_FILE}" ]; then
    echo "[ERROR] 配置文件不存在: ${CONF_FILE}" >&2
    exit 1
fi
source "${CONF_FILE}"

# 初始化基础变量
DATE_STR=$(date +%Y%m%d_%H%M%S)
HOST_NAME=$(hostname)
HOST_IP=$(hostname -I | awk '{print $1}')
DMP_BASE_NAME="dm_full_${DATE_STR}"
DMP_FILE="${DMP_BASE_NAME}.dmp"
GZ_FILE="${DMP_BASE_NAME}.dmp.gz"
MD5_FILE="${DMP_BASE_NAME}.dmp.gz.md5"

# 关键修复：运维总日志 与 dexp 导出日志彻底分离
SCRIPT_LOG="${BACKUP_DIR}/backup_task_${DATE_STR}.log"
DEXP_LOG_NAME="dexp_db_${DATE_STR}.log"
DEXP_LOG_PATH="${BACKUP_DIR}/${DEXP_LOG_NAME}"
MAIL_SCRIPT="/home/dmdba/scripts/send_mail.py"

mkdir -p "${BACKUP_DIR}"

# 日志输出函数
log() {
    local level="$1"
    local msg="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$$] [${level}] ${msg}" | tee -a "${SCRIPT_LOG}"
}

# 告警分发函数
send_notification() {
    local status="$1"
    local duration="$2"
    local file_size="$3"
    local md5_val="$4"
    local error_detail="$5"

    local sub_title="✅【运维日报】达梦数据库全量灾备成功 (${HOST_NAME})"
    local status_badge="<span style='color: green; font-weight: bold;'>【备份成功】</span>"
    if [ "${status}" != "SUCCESS" ]; then
        sub_title="🚨【紧急告警】达梦数据库灾备异常 (${HOST_NAME})"
        status_badge="<span style='color: red; font-weight: bold;'>【备份失败 / 异常】</span>"
    fi

    local msg_body="
    <p><strong>执行状态：</strong>${status_badge}</p>
    <p><strong>主机节点：</strong><code>${HOST_NAME} (${HOST_IP})</code></p>
    <p><strong>归档文件：</strong><code>${GZ_FILE}</code></p>
    <p><strong>归档体积：</strong><b>${file_size}</b></p>
    <p><strong>备份耗时：</strong><b>${duration} 秒</b></p>
    <p><strong>MD5 签名校验码：</strong><code>${md5_val}</code></p>
    <p><strong>日志排查：</strong>${error_detail}</p>
    <p><strong>调度周期：</strong>每日凌晨 02:30 | 保留策略: ${RETENTION_DAYS} 天滚动清理</p>
    "

    # 1. 发送 Python 邮件
    if [ "${MAIL_ENABLED:-0}" -eq 1 ] && [ -f "${MAIL_SCRIPT}" ]; then
        log "INFO" "正在通过 SMTP 推送运维邮件通知..."
        python3 "${MAIL_SCRIPT}" "${sub_title}" "${msg_body}" "${MAIL_SENDER}" "${MAIL_AUTH_CODE}" "${MAIL_RECEIVER}" >> "${SCRIPT_LOG}" 2>&1
    fi

    # 2. 发送 Webhook (如果配置了有效地址)
    if [ "${ALERT_ENABLED:-0}" -eq 1 ] && [ -n "${WEBHOOK_URL:-}" ] && [[ "${WEBHOOK_URL}" != *"YOUR_BOT_KEY"* ]]; then
        local payload="{\"msgtype\":\"markdown\",\"markdown\":{\"content\":\"### 🏛️ 信创达梦 (DM8) 灾备报告\n> 状态: ${status}\n> 主机: ${HOST_NAME}\n> 文件: ${GZ_FILE} (${file_size})\n> 耗时: ${duration}s\"}}"
        curl -s -H "Content-Type: application/json" -X POST -d "${payload}" "${WEBHOOK_URL}" > /dev/null 2>&1
    fi
}

# ==============================================================================
# 核心执行流程 (文件锁保护)
# ==============================================================================
exec 200>"${LOCK_FILE}"
flock -n 200 || {
    log "ERROR" "检测到另一个备份任务正在执行，触发防重入锁，终止当前进程！"
    send_notification "FAILED" "0" "0B" "N/A" "触发防重入锁冲突"
    exit 1
}

START_TIME=$(date +%s)
log "INFO" "================ 达梦数据库全量灾备任务启动 ================"
log "INFO" "目标数据源: ${DB_HOST}:${DB_PORT} | 用户: ${DB_USER}"

# 1. 调用 dexp 原生工具导出（日志单独命名，绝不覆盖已有文件）
"${DM_BIN_DIR}/dexp" USERID="${DB_USER}/${DB_PWD}@${DB_HOST}:${DB_PORT}" \
    FILE="${DMP_FILE}" \
    DIRECTORY="${BACKUP_DIR}" \
    LOG="${DEXP_LOG_NAME}" \
    FULL=Y

DEXP_EXIT_CODE=$?

if [ ${DEXP_EXIT_CODE} -eq 0 ] && [ -f "${BACKUP_DIR}/${DMP_FILE}" ]; then
    log "INFO" "逻辑导出完毕，正在执行 Gzip 压缩..."
    
    # 2. 执行压缩
    gzip -f "${BACKUP_DIR}/${DMP_FILE}"
    
    # 3. 计算 MD5
    cd "${BACKUP_DIR}"
    md5sum "${GZ_FILE}" > "${MD5_FILE}"
    MD5_VALUE=$(awk '{print $1}' "${MD5_FILE}")
    FILE_SIZE=$(ls -lh "${GZ_FILE}" | awk '{print $5}')
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    log "INFO" "备份成功归档！文件: ${GZ_FILE} (大小: ${FILE_SIZE})"
    log "INFO" "MD5 签名校验码: ${MD5_VALUE}"
    log "INFO" "全流程耗时: ${DURATION} 秒"
    
    # 4. 清理 7 天前过期文件
    find "${BACKUP_DIR}" -name "dm_full_*.dmp.gz" -mtime +"${RETENTION_DAYS}" -delete
    find "${BACKUP_DIR}" -name "dm_full_*.dmp.gz.md5" -mtime +"${RETENTION_DAYS}" -delete
    find "${BACKUP_DIR}" -name "dexp_db_*.log" -mtime +"${RETENTION_DAYS}" -delete
    find "${BACKUP_DIR}" -name "backup_task_*.log" -mtime +"${RETENTION_DAYS}" -delete
    log "INFO" "历史过期数据滚动清理完成。"
    
    # 5. 发送成功通知
    send_notification "SUCCESS" "${DURATION}" "${FILE_SIZE}" "${MD5_VALUE}" "无异常"
else
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    log "ERROR" "达梦数据库 dexp 导出失败，退出代码: ${DEXP_EXIT_CODE}！"
    send_notification "FAILED" "${DURATION}" "0B" "N/A" "dexp 导出异常退出 (Code: ${DEXP_EXIT_CODE})"
    exit 1
fi

log "INFO" "================ 灾备任务顺利结束 ================"
