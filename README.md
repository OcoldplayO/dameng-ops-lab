# 🏛️ 信创环境（openEuler + 达梦DM8）全栈交付与自动化容灾演练方案

[![Platform](https://img.shields.io/badge/Platform-openEuler%2024.03%20LTS-blue?style=flat-square)](https://openeuler.org/)
[![Database](https://img.shields.io/badge/Database-Dameng%20DM8%20(8.1.5)-red?style=flat-square)](https://www.dameng.com/)
[![Gateway](https://img.shields.io/badge/Gateway-Nginx%20(HTTPS%20SNI)-009639?style=flat-square)](https://nginx.org/)
[![Observability](https://img.shields.io/badge/Monitoring-Prometheus%20%2B%20Grafana-orange?style=flat-square)](https://prometheus.io/)
[![License](https://img.shields.io/badge/License-Apache%202.0-green?style=flat-square)](./LICENSE)

本项目模拟“信创国产化替代”交付与运维保障场景。  
基于 openEuler 24.03 LTS 与 达梦数据库 (DM8)，完成了涵盖复杂业务模型（若依 RuoYi 30+ 表）迁移适配、10万级数据基准压测、工业级自动化容灾、全自动健康巡检晨报、生产事故应急排障手册、统一安全网关（Nginx + 私有 PKI）以及云原生监控告警的全栈工程落地。

---

## 📐 一、 架构拓扑全景图 (Architecture)

```mermaid
flowchart TB
    subgraph Client["💻 客户端 / 管理端 (Windows 宿主机)"]
        Browser["🌐 浏览器 (HTTPS 访问)"]
        DataGrip["🗄️ DataGrip (JDBC 直连 :5236)"]
        Email["✉️ QQ 邮箱 (接收告警与晨报)"]
    end

    subgraph Ingress["🛡️ 统一安全反向代理网关 (Nginx :443 / :80)"]
        Nginx["Nginx Ingress (SNI 域名精准分流 + 10年期 SAN 泛域名证书)"]
        R_Grafana["grafana.xinchuang.internal"]
        R_Prom["prometheus.xinchuang.internal"]
        R_Alert["alertmanager.xinchuang.internal"]
    end

    subgraph openEuler["🐧 openEuler 24.03 LTS (信创基础设施环境 / WSL2 D盘定制)"]
        subgraph DB["💾 达梦数据库 (DM8 原生 systemd 托管服务)"]
            DM8["DM8 (CASE_SENSITIVE=0 / 等保2.0三权分立)"]
            RuoYi["若依 30+ 张系统与Quartz表 + 10万条操作日志"]
        end

        subgraph Monitor["📈 云原生可观测性集群 (Docker Compose)"]
            NodeExp["node-exporter (系统探针 :9100)"]
            Prom["Prometheus 时序数据库 (:9090)"]
            AlertMgr["Alertmanager 告警分发 (:9093)"]
            Grafana["Grafana 可视化大盘 (:3000)"]
        end

        subgraph Automation["⚙️ 自动化运维与灾备套件"]
            BackupScript["backup_dm8_pro.sh (Flock内核锁 + Gzip + MD5)"]
            HealthScript["server_health_check.sh (动态加权健康评分晨报)"]
            SendMail["send_mail.py (SMTP/SSL 模块)"]
        end
    end

    Browser -->|443/80| Nginx
    Nginx --> R_Grafana --> Grafana
    Nginx --> R_Prom --> Prom
    Nginx --> R_Alert --> AlertMgr

    DataGrip -->|TCP :5236| DM8
    NodeExp --> Prom --> AlertMgr -->|指标超标/恢复| Email
    BackupScript -->|每日 02:30 全备| SendMail --> Email
    HealthScript -->|每日 08:00 晨报| SendMail --> Email



📊 二、 核心性能基准与实测指标 (Benchmarks)
在单机虚拟化环境下，针对 30 张表 + 100,000 条真实操作审计日志（28.029 MB 原始数据） 的实测性能矩阵：
评估维度	指标参数 / 实测表现	核心技术点与优势
逻辑全备吞吐	4.675 秒 (30 表 / 100,000 行)	达梦原生 dexp 逻辑导出
归档压缩效率	原始 28.0 MB ➡️ 归档 1.2 MB	Gzip 流水线压缩，压缩比 85%+
全表冷读扫描	1,090 ms (Cold Disk I/O)	CSCN2 聚集索引全表扫描
索引范围查询	12 ms (Index Range Seek)	SSEK2 复合索引定位，提速 90 倍 🚀
死锁排查时效	1 秒内完成热解卡	V$TRXWAIT 定位 9 分钟锁等待，SP_CLOSE_SESSION 查杀
表空间热扩容	128 MB 扩容至 192 MB	ALTER TABLESPACE MAIN ADD DATAFILE 零停机在线扩容
灾难恢复验证	100% 完整性验证 (dimp)	单表误删演练，0 警告、0 数据丢失
安全网关证书	10 年超长有效期（至 2036 年）	OpenSSL 自建私有 PKI 签发，SAN 泛域名绑定，标准 443 全绿安全锁



🛡️ 三、 工业级自动化运维与防御性设计 (Defensive Architecture)

防重入内核锁保护： 引入 Linux 内核文件描述符锁（flock -n 200），从根源杜绝定时调度重叠引发的磁盘 I/O 拥塞与死锁；进程崩溃内核自动释放锁，无死锁残留。

数据完整性 MD5 签名： 备份完成后毫秒级生成 .md5 哈希伴随文件，异地灾备机恢复前自动校验，彻底规避存储坏道与静默损坏（Bit Rot）。

安全配置物理分离： 敏感连接凭据与 SMTP 秘钥收口于 chmod 600 独立配置文件，源码与密码彻底解耦。

每日全自动健康巡检晨报： server_health_check.sh 采集 CPU、内存、Swap、磁盘、Inode、服务与端口状态，引入加权扣分算法输出健康分，每天 08:00 自动推送深蓝卡片式 HTML 晨报。

全链路告警与状态闭环： 支持每日备份成功推送【运维日报】、执行失败自动捕获错误码；监控大盘在指标超标时触发【🚨紧急告警】、恢复时触发【✅已恢复】通知。



🌐 四、 统一安全网关与私有 PKI 体系 (Ingress Gateway)

针对企业内网与私有云无备案域名的场景，构建了标准的虚拟主机路由方案：
私有 PKI 泛域名证书： 通过 OpenSSL 自动签发包含 *.xinchuang.internal、xinchuang.internal、localhost 及主机 IP 的泛域名 SAN 扩展证书。
SNI 443 端口多域名复用： 采用模块化 conf.d/ 隔离架构，所有 Web 应用统一汇聚于标准 443 端口，通过域名精准分流，80 端口自动 301 强制跳转 HTTPS。
零停机平滑热重载： 结合 nginx -t 语法自检与 nginx -s reload，实现路由规则毫秒级无感生效。



📖 五、 生产排障与性能调优 Runbooks
详细排障案例与复盘手记收录于 docs/ 目录：
慢查询定位与执行计划分析：深入剖析 CSCN2 全表扫、SSEK2 索引扫、Buffer Pool 缓存命中与网络 fetching 耗时分解。
长事务行锁等待与会话查杀：通过 V$TRXWAIT 视图实时定位长达 9 分钟的阻塞源头，使用 SP_CLOSE_SESSION(sess_id) 实现线上热解卡，推导自动提交与手动事务的状态机差异。
表空间在线动态扩容实操：MAIN 表空间水位实时巡检，通过 ALTER TABLESPACE ADD DATAFILE 动态挂载 MAIN_02.DBF，实现零停机容量热扩充。
Linux CPU 100% 与内核 OOM-Killer 排查：从 top -Hp 线程 TID 转十六进制穿透到应用代码行，提取 dmesg -T 内核级 OOM 击杀铁证与 oom_score_adj -1000 核心服务保护。
企业级 Nginx 统一网关与私有 PKI 实战指南：私有 CA 构建、SAN 扩展配置、Windows 根证书导入与 443 端口多域名分发全解析。



📂 六、 仓库目录结构全貌

dameng-ops-lab/
├── README.md                           # 🏛️ 项目全景架构白皮书
├── LICENSE                             # 📜 Apache License 2.0 许可证
├── push.sh                             # 🚀 一键自动化资产归集与发布流水线
├── .gitignore                          # 🛡️ 敏感密钥与大文件安全过滤配置
│
├── config/                             # ⚙️ 配置文件模板与容器编排
│   ├── backup_dm8.conf.example         # 灾备外部凭证配置模板 (脱敏)
│   ├── docker-compose-monitoring.yml   # Prometheus + Grafana + Alertmanager + Nginx 编排
│   ├── alertmanager/
│   │   └── alertmanager.yml.example    # 告警路由与 SMTP 发信模板
│   ├── prometheus/
│   │   ├── prometheus.yml              # 监控指标采集任务配置
│   │   └── alert.rules.yml             # CPU / 内存告警阈值计算规则
│   └── nginx/
│       └── conf.d/                     # Nginx 模块化域名路由配置
│           ├── 00-http-redirect.conf   # 80 端口 HTTP 自动 301 跳转 HTTPS
│           ├── 01-grafana.conf         # grafana.xinchuang.internal 反向代理
│           ├── 02-prometheus.conf      # prometheus.xinchuang.internal 反向代理
│           └── 03-alertmanager.conf    # alertmanager.xinchuang.internal 反向代理
│
├── scripts/                            # 🛠️ 生产级自动化与发信工具套件
│   ├── backup_dm8_pro.sh               # 达梦数据库全量灾备脚本 (带内核文件锁与 MD5)
│   ├── server_health_check.sh          # 服务器每日健康巡检晨报脚本 (动态加权评分)
│   ├── send_mail.py                    # 基于 Python SMTP/SSL 的 HTML 邮件推送模块
│   ├── generate_ssl.sh                 # OpenSSL 10年期 SAN 泛域名证书一键签发工具
│   └── verify_backup_integrity.sh      # 备份完整性 MD5 自动校验与解压测试工具
│
├── sql/                                # 💾 业务模型、压测与 DBA 诊断脚本
│   ├── ruoyi_dm8_full_schema.sql       # 若依全套 30+ 业务与 Quartz 分布式调度表 DDL
│   ├── sp_generate_mock_logs.sql       # 10 万行操作审计日志批量生成存储过程
│   └── dba_troubleshooting_queries.sql # 锁等待排查、会话查杀与表空间巡检 SQL
│
└── docs/                               # 📖 深度技术白皮书与排障手册 (Runbooks)
    └── 05-nginx-ssl-pki-gateway.md



🚀 七、 快速启动与演练指南

1. 执行全量灾备并发送邮件
复制并配置环境凭证
cp config/backup_dm8.conf.example config/backup_dm8.conf
chmod 600 config/backup_dm8.conf

运行灾备脚本 (自动触发邮件)
./scripts/backup_dm8_pro.sh

2. 执行全自动系统健康巡检晨报
./scripts/server_health_check.sh

3. 启动云原生监控与 Nginx 安全网关
# 签发 10 年期 SAN 证书
./scripts/generate_ssl.sh

# 一键拉起监控大盘与统一网关
cd config
docker compose -f docker-compose-monitoring.yml up -d

# 访问 Grafana:     https://grafana.xinchuang.internal (admin/admin)
# 访问 Prometheus:  https://prometheus.xinchuang.internal
# 访问 Alertmanager: https://alertmanager.xinchuang.internal

本项目所有演练均基于 openEuler 24.03 与达梦 DM8 真实环境校验，符合信创等保 2.0 合规要求。

