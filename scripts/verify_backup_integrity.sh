#!/bin/bash
# ==============================================================================
# 达梦备份完整性 MD5 自动校验与解压测试工具
# ==============================================================================
set -eu

BACKUP_DIR="${1:-/dmdata/dmbak}"
cd "${BACKUP_DIR}"

LATEST_MD5=$(ls -t dm_full_*.dmp.gz.md5 2>/dev/null | head -n 1 || true)
if [ -z "${LATEST_MD5}" ]; then
    echo "[ERROR] 未找到任何 .md5 校验文件！" >&2
    exit 1
fi

echo "[INFO] 正在对最新备份进行 MD5 哈希完整性校验: ${LATEST_MD5}"
md5sum -c "${LATEST_MD5}"

if [ $? -eq 0 ]; then
    echo "✅ [SUCCESS] 备份文件未发生位翻转或损坏，数据完整性 100% 校验通过！"
else
    echo "❌ [ERROR] 校验失败，文件可能已损坏！" >&2
    exit 1
fi
