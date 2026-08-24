🚨 达梦生产事故排障与性能调优手册 (Runbooks)

案例 1: 慢 SQL 抓取与 EXPLAIN 执行计划调优
现象： 10 万行操作日志表范围查询耗时达 1,090ms。
排查： 执行计划显示 CSCN2（聚集索引全表扫描）。
优化： 建立复合索引 CREATE INDEX idx_oper_status_cost ON sys_oper_log(status, cost_time);。
结果： 执行计划转为 SSEK2（二级索引范围扫描），耗时降至 12ms（提速 90 倍）。


案例 2: 长事务行锁冲突排查与 SP_CLOSE_SESSION 查杀
排查 SQL：
SELECT W.ID AS 等待事务ID, W.WAIT_TIME AS 等待耗时_ms, S2.SESS_ID AS 源头会话ID
FROM V$TRXWAIT W
LEFT JOIN V$SESSIONS S1 ON W.ID = S1.TRX_ID
LEFT JOIN V$SESSIONS S2 ON W.WAIT_FOR_ID = S2.TRX_ID;
热解卡： 调用 CALL SP_CLOSE_SESSION(源头会话ID); 强杀阻塞源头，等待事务瞬间恢复。


案例 3: 表空间水位监控与在线自动扩容
在线扩容 SQL：
ALTER TABLESPACE MAIN ADD DATAFILE '/dmdata/data/DAMENG/MAIN_02.DBF' 
SIZE 64 AUTOEXTEND ON NEXT 32 MAXSIZE 2048;


案例 4: Linux CPU 100% 线程定位与 OOM-Killer 现场取证
CPU 100% 定位： top -c ➡️ top -Hp <PID> 找到高 CPU 线程 TID ➡️ printf "%x\n" <TID> 转换为十六进制 ➡️ 查询 V$THREADS 定位具体 SQL。
OOM 取证： dmesg -T | grep -i "killed process" 抓取内核内存转储快照。
服务免死金牌： echo -1000 > /proc/<PID>/oom_score_adj。
