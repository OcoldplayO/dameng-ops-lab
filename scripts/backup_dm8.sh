# 写入原生备份脚本
#!/bin/bash
# ==============================================================
# openEuler + 达梦数据库(DM8) 自动化全库逻辑备份与归档脚本
# ==============================================================

# 配置变量
DM_BIN="/home/dmdba/dmdbms/bin"
BACKUP_DIR="/dmdata/dmbak"
DB_USER="SYSDBA"
DB_PWD="DBA001_Admin"
DB_HOST="127.0.0.1"
DB_PORT="5236"

DATE=$(date +%Y%m%d_%H%M%S)
DMP_FILE="dm_full_${DATE}.dmp"
LOG_FILE="${BACKUP_DIR}/dexp_${DATE}.log"

# 确保备份目录存在
mkdir -p ${BACKUP_DIR}

echo "==========================================================" >> ${LOG_FILE}
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] 开始执行达梦数据库逻辑全备..." >> ${LOG_FILE}

# 调用原生 dexp 工具执行逻辑全备
${DM_BIN}/dexp USERID=${DB_USER}/${DB_PWD}@${DB_HOST}:${DB_PORT} \
  FILE=${DMP_FILE} \
  DIRECTORY=${BACKUP_DIR} \
  LOG=dexp_${DATE}.log \
  FULL=Y

# 检查上一条命令的执行状态
if [ $? -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] 备份成功！正在进行 Gzip 压缩归档..." >> ${LOG_FILE}
    
    # 压缩 .dmp 备份文件，节省磁盘空间
    gzip -f ${BACKUP_DIR}/${DMP_FILE}
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] 归档完成：${BACKUP_DIR}/${DMP_FILE}.gz" >> ${LOG_FILE}
    
    # 自动清理 7 天前的历史备份（根据需要修改天数）
    find ${BACKUP_DIR} -name "dm_full_*.dmp.gz" -mtime +7 -exec rm -f {} \;
    find ${BACKUP_DIR} -name "dexp_*.log" -mtime +7 -exec rm -f {} \;
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] 历史过期备份清理完成。" >> ${LOG_FILE}
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] 备份失败，请检查达梦数据库运行状态与连接！" >> ${LOG_FILE}
    exit 1
fi
echo "==========================================================" >> ${LOG_FILE}
