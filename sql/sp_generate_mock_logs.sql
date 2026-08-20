-- ============================================================================
-- 达梦 DM8: 生产级操作日志批量生成存储过程（带分批事务提交）
-- ============================================================================
CREATE OR REPLACE PROCEDURE SP_GENERATE_MOCK_LOGS(IN NUM_ROWS INT)
AS
  V_STATUS INT;
  V_COST_TIME BIGINT;
  V_URL VARCHAR(255);
  V_METHOD VARCHAR(10);
  V_TITLE VARCHAR(50);
  V_IP VARCHAR(128);
  V_OPER_TIME DATETIME;
  V_ERR_MSG VARCHAR(500);
  V_RAND INT;
BEGIN
  FOR i IN 1..NUM_ROWS LOOP
    V_RAND := CAST(RAND() * 100 AS INT);

    IF V_RAND < 5 THEN
      V_STATUS := 1;
      V_ERR_MSG := 'java.lang.NullPointerException: Connection reset by peer';
    ELSE
      V_STATUS := 0;
      V_ERR_MSG := '';
    END IF;

    V_COST_TIME := CAST(RAND() * 3490 + 10 AS BIGINT);

    IF MOD(i, 5) = 0 THEN
      V_TITLE := '用户数据全量查询';
      V_URL := '/system/user/list';
      V_METHOD := 'GET';
    ELSIF MOD(i, 5) = 1 THEN
      V_TITLE := '批量修改角色权限';
      V_URL := '/system/role/update';
      V_METHOD := 'PUT';
    ELSIF MOD(i, 5) = 2 THEN
      V_TITLE := '导出信创操作审计日志';
      V_URL := '/system/operlog/export';
      V_METHOD := 'POST';
    ELSIF MOD(i, 5) = 3 THEN
      V_TITLE := 'Quartz分布式集群调度';
      V_URL := '/monitor/job/run';
      V_METHOD := 'POST';
    ELSE
      V_TITLE := '统一身份认证与授权';
      V_URL := '/auth/login';
      V_METHOD := 'POST';
    END IF;

    V_IP := '192.168.1.' || CAST(MOD(i * 17, 250) + 1 AS VARCHAR);
    V_OPER_TIME := SYSDATE - (MOD(i, 30) + (RAND()));

    INSERT INTO sys_oper_log (
      title, business_type, method, request_method, operator_type,
      oper_name, dept_name, oper_url, oper_ip, oper_location,
      oper_param, json_result, status, error_msg, oper_time, cost_time
    ) VALUES (
      V_TITLE, MOD(i, 5) + 1, 'com.ruoyi.web.controller.SysOperlogController', V_METHOD, 1,
      CASE WHEN MOD(i, 2) = 0 THEN 'admin' ELSE 'devops' END,
      '信创运维支持部', V_URL, V_IP, '昆明政企机房内网',
      '{"pageNum":1,"pageSize":50}', '{"code":200,"msg":"操作成功"}',
      V_STATUS, V_ERR_MSG, V_OPER_TIME, V_COST_TIME
    );

    IF MOD(i, 5000) = 0 THEN
      COMMIT;
    END IF;
  END LOOP;
  COMMIT;
END;
/
