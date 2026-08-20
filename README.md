🏛️ 信创环境（openEuler + 达梦DM8）全栈交付与自动化容灾演练方案

[![Platform](https://img.shields.io/badge/Platform-openEuler%2024.03%20LTS-blue?style=flat-square)](https://openeuler.org/)
[![Database](https://img.shields.io/badge/Database-Dameng%20DM8%20(8.1.5)-red?style=flat-square)](https://www.dameng.com/)
[![Observability](https://img.shields.io/badge/Monitoring-Prometheus%20%2B%20Grafana-orange?style=flat-square)](https://prometheus.io/)
[![License](https://img.shields.io/badge/License-Apache%202.0-green?style=flat-square)](./LICENSE)

本项目模拟国产化替代的核心交付与运维保障场景。

基于 openEuler 24.03 LTS 与 达梦数据库 (DM8)，完成了涵盖业务系统（若依 RuoYi 30+ 表）迁移、10万级数据基准测试、自动化容灾闭环、生产事故应急排障以及云原生监控告警的落地。



一：架构拓扑全景图 (Architecture)

[ Windows 宿主机 (管理端) ] ├── DataGrip 数据库管理客户端 (JDBC: jdbc:dm://172.29.199.115:5236) └── 浏览器 (Grafana 大盘 :3000 / Prometheus 告警中心 :9090) │ ▼ [ L3 虚拟网桥直连 (vEthernet / 绕过宿主机代理) ][ openEuler 24.03 LTS (信创基础设施环境) ] ├── 达梦数据库 (DM8 原生服务) │ ├── 实例参数: PAGE_SIZE=16, CASE_SENSITIVE=0 (MySQL兼容), CHARSET=UTF-8 │ ├── 安全基线: 三权分立独立账户 (dmdba:dinstall), limits.conf 资源限制优化 │ └── 业务载荷: 若依 (RuoYi) 30+ 张系统与 Quartz 分布式调度表 + 100,000 条日志 ├── 工业级自动化灾备套件 │ ├── backup_dm8_pro.sh: Linux 内核文件锁 (flock) + dexp 导出 + Gzip + MD5 完整性哈希 │ ├── send_mail.py: 基于 SMTP/SSL 的每日全量灾备报告自动推送 │ └── Crontab 调度: 每日凌晨 02:30 定时无感执行与 7 天滚动轮转清理 └── 云原生可观测性集群 (Docker Compose) ├── node-exporter (系统指标采集 :9100) ──► Prometheus (:9090) ├── Alertmanager (:9093) ──► 自动触发 CPU >75% / 内存不足 紧急告警邮件 └── Grafana (:3000) ──► 实时性能大盘可视化



二：核心性能基准与实测指标 (Benchmarks)

在单机虚拟化环境下，针对 30 张表 + 100,000 条真实操作审计日志（28.029 MB 原始数据） 的基准性能指标：

评估维度；指标参数 / 实测表现；核心技术点与优势

导出耗时：4.675 秒 (30 Tables / 100,000 Rows)；达梦原生 dexp 逻辑导出

压缩效率原始：28 MB ➡️ 归档 1.2 MB；Gzip 流水线压缩，压缩比 85%+

冷读扫描：1,090 ms (Cold Disk I/O)；CSCN2 聚集索引全表扫描

索引提速：12 ms (Index Range Seek)；SSEK2 复合索引定位，提速 90 倍 

灾难恢复：100% 完整性验证 (dimp)；单表误删恢复 0 警告、0 数据丢失



三：灾备特性设计 (Defensive Architecture)

防重入内核锁保护： 引入 Linux 内核文件描述符锁（flock -n 200），从根源杜绝定时调度重叠引发的磁盘 I/O 拥塞与死锁。

数据完整性 MD5 签名： 备份完成后毫秒级生成 .md5 哈希伴随文件，异地恢复前自动化校验，彻底规避存储坏道与静默损坏（Bit Rot）。

安全配置物理分离： 敏感连接凭据与 Webhook/SMTP 秘钥收口于 chmod 600 独立配置文件，源码与密码彻底解耦。

全链路告警闭环： 支持每日备份成功推送【运维日报】、执行失败自动捕获错误码并触发【紧急告警】。



四：生产排障与性能调优 Runbooks

详细排障案例与复盘收录于 docs/ 目录：

慢查询定位与执行计划分析：分析 CSCN2 全表扫、SSEK2 索引扫、Buffer Pool 缓存命中与网络 fetching 耗时分解。

长事务行锁等待与会话查杀：通过 V$TRXWAIT 视图实时定位阻塞源头，使用 SP_CLOSE_SESSION(sess_id) 实现线上热解卡。

表空间在线动态扩容实操：MAIN 表空间水位实时巡检，通过 ALTER TABLESPACE ADD DATAFILE 动态挂载 MAIN_02.DBF，实现零停机容量热扩充。

Linux CPU 100% 与内核 OOM-Killer 排查：从 top -Hp 线程 TID 转十六进制穿透到应用代码行，提取 dmesg -T 内核级 OOM 击杀与 oom_score_adj 核心服务保护。



五：快速启动与演练指南

1）执行全量灾备并发送邮件

复制并配置环境凭证cp config/backup_dm8.conf.example config/backup_dm8.confchmod 600 config/backup_dm8.conf

运行灾备脚本./scripts/backup_dm8_pro.sh

2）启动监控告警大盘

cd configdocker compose -f docker-compose-monitoring.yml up -d

访问 Grafana: http://<HOST_IP>:3000 (admin/admin)访问 Prometheus: http://<HOST_IP>:9090

本项目所有演练均经过实操校验，符合合规要求。
