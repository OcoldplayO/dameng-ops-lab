🔄 若依 (RuoYi) 业务系统迁移到达梦 DM8 方言适配手册
一、 核心方言与语法差异
特性 / 语法	MySQL 标准行为	达梦 DM8 适配方案
大小写敏感度	默认大小写不敏感	初始化必须显式设定 CASE_SENSITIVE=0
自增主键插入	允许手动插入固定 ID	必须使用 SET IDENTITY_INSERT <table_name> ON; 开关
大文本字段	TEXT / LONGTEXT	映射为 CLOB 或 VARCHAR
日期时间	DATETIME / NOW()	映射为 DATETIME / SYSDATE

二、 自增列错误 [-2723] 解决方案
若依初始化基础数据时指定了 user_id = 1，在 DM8 中必须包裹开关：
SET IDENTITY_INSERT sys_user ON;
INSERT INTO sys_user (user_id, ...) VALUES (1, ...);
SET IDENTITY_INSERT sys_user OFF;
