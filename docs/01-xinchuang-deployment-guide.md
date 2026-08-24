🐧 openEuler 24.03 LTS 与达梦 DM8 基础环境交付指南

一、 openEuler 24.03 WSL2 虚拟化定制
1. Rootfs 提取：解包微软商店 AppxBundle 嵌套结构，精准提取 x86_64 架构的 `install.tar.gz`，避免 ARM64 架构冲突。
2. 存储路径隔离：规避 C 盘膨胀，通过 `wsl --import` 将系统及虚拟磁盘重定向至 D 盘或任意磁盘。
3. 依赖源补齐：配置华为云 Docker-CE 软件源，安装 `cronie` 补齐定时调度守护进程。

二、 达梦数据库 (DM8) 企业级合规安装
1. 权限隔离：创建独立专用账户 `dmdba:dinstall`，严禁 root 运行数据库。
2. 存储划分：规划 `/dmdata/data`、`/dmdata/arch`、`/dmdata/dmbak` 物理隔离目录。
3. 等保 2.0 合规初始化：
   ```bash
   /home/dmdba/dmdbms/bin/dminit path=/dmdata/data \
     PAGE_SIZE=16 CASE_SENSITIVE=0 CHARSET=1 \
     SYSDBA_PWD=YOUR_STRONG_PASSWORD \
     SYSAUDITOR_PWD=YOUR_STRONG_PASSWORD
服务托管： 注册为 systemd 原生系统服务 DmServiceDMSERVER。
