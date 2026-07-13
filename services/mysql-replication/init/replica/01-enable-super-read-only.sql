-- 从库完成初始化后，在正式服务启动时启用 super_read_only。
SET PERSIST_ONLY super_read_only = ON;
