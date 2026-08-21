🌐 Nginx 统一安全网关与私有 PKI 泛域名证书实战指南

本项目在缺乏公网 IP 与未备案域名的本地/私有云环境下，完整模拟了微服务与基础设施的 “统一安全网关” 架构。


📐 1. 架构拓扑设计


[ 客户端 Windows 浏览器 ]
   ├── https://grafana.xinchuang.internal       (直达 Grafana 监控大盘)
   ├── https://prometheus.xinchuang.internal    (直达 Prometheus 规则与指标)
   └── https://alertmanager.xinchuang.internal  (直达 Alertmanager 告警中心)
                            │
                            ▼ (所有流量统一汇聚到标准 443 端口)

[ Nginx 模块化安全反向代理网关 (SNI 域名精准分流) ]
   ├── conf.d/00-http-redirect.conf  ──► 80 端口 HTTP 全局 301 强制跳转 HTTPS
   ├── conf.d/01-grafana.conf        ──► 代理至 mon_grafana:3000
   ├── conf.d/02-prometheus.conf     ──► 代理至 mon_prometheus:9090
   └── conf.d/03-alertmanager.conf   ──► 代理至 mon_alertmanager:9093
