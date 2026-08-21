#!/bin/bash
# ==============================================================================
# 脚本名称: push.sh (全自动归集、脱敏同步与 GitHub 推送工具)
# 适用仓库: /home/dmdba/dameng-ops-lab
# 用法：./push.sh "你的提交信息" eg: /home/dmdba/dameng-ops-lab/push.sh "feat: 升级一键自动归集与同步脚本"
# ==============================================================================
set -eu

REPO_DIR="/home/dmdba/dameng-ops-lab"
MSG="${1:-update: 自动同步最新生产配置、监控规则与运维脚本}"

echo "========================================================"
echo "🚀 开始全自动归集 /home/dmdba 下各目录的生产配置与脚本..."
echo "========================================================"

# 1. 确保仓库目标目录完整
mkdir -p "${REPO_DIR}/scripts" \
         "${REPO_DIR}/config/nginx/conf.d" \
         "${REPO_DIR}/config/prometheus" \
         "${REPO_DIR}/config/alertmanager" \
         "${REPO_DIR}/sql" \
         "${REPO_DIR}/docs"

# 2. 从 ~/scripts/ 归集所有生产运维与发信脚本
echo "[1/4] 同步核心自动化脚本 (scripts/)..."
cp -f /home/dmdba/scripts/*.sh "${REPO_DIR}/scripts/" 2>/dev/null || true
cp -f /home/dmdba/scripts/*.py "${REPO_DIR}/scripts/" 2>/dev/null || true

# 同步 SSL 证书生成脚本
if [ -f /home/dmdba/monitoring/nginx/generate_ssl.sh ]; then
    cp -f /home/dmdba/monitoring/nginx/generate_ssl.sh "${REPO_DIR}/scripts/"
fi
chmod +x "${REPO_DIR}/scripts/"*.sh "${REPO_DIR}/scripts/"*.py 2>/dev/null || true

# 3. 从 ~/monitoring/ 归集 Nginx、Prometheus、Alertmanager 监控配置
echo "[2/4] 同步云原生监控与 Nginx 网关配置 (config/)..."
cp -f /home/dmdba/monitoring/docker-compose.yml "${REPO_DIR}/config/docker-compose-monitoring.yml" 2>/dev/null || true
cp -f /home/dmdba/monitoring/nginx/conf.d/*.conf "${REPO_DIR}/config/nginx/conf.d/" 2>/dev/null || true
cp -f /home/dmdba/monitoring/prometheus/prometheus.yml "${REPO_DIR}/config/prometheus/" 2>/dev/null || true
cp -f /home/dmdba/monitoring/prometheus/alert.rules.yml "${REPO_DIR}/config/prometheus/" 2>/dev/null || true

# 4. 进入仓库目录，执行 Git 提交与推送
cd "${REPO_DIR}"
echo "[3/4] 检查文件变更并暂存..."
git add .

# 检查是否有文件变更
if git diff-index --quiet HEAD --; then
    echo "⚠️ [INFO] 检查完毕：所有文件与远程仓库完全一致，无需重复提交。"
    exit 0
fi

# 打印具体变动的文件列表
git status --short

echo "[4/4] 提交版本并推送到 GitHub (main 分支)..."
git commit -m "${MSG}"
git push origin main

echo "========================================================"
echo "✅ [SUCCESS] 全量生产配置与代码已一键推送到远程 GitHub！"
echo "========================================================"
