---
name: redis-key-governance
description: "治理 Go Redis Key 使用。用于 key 收口、共享缓存、TTL、失效、SCAN/KEYS 压力、helper、registry/static check 和跨服务兼容。"
---

# Redis Key 治理

## 工作流程

1. 先读取生效的 `AGENTS.md`、AI 文档和 `references/project-map.md`。
2. 修改调用点前，先定位现有 key helper 和 registry。
3. 保持 admin/api/money/stat 等服务间共享缓存语义；除非用户明确要求隔离，不要加入 repo-name 前缀导致缓存隔离。
4. 优先使用集中 helper 和模板 registry，避免业务代码内联字符串拼接。
5. 将高基数 `SCAN`/`KEYS` 替换为精确 Key、索引集合、白名单模板、异步任务或静态 registry。
6. 缓存失效、miss 语义、重建路径、TTL 和归属要一起检查。
7. 规则需要长期保持时，补静态测试或扫描。
8. 多 Key Lua/CAS 必须逐项检查 Redis Cluster hash tag，保证 Hash、索引、版本、计数与锁等同一原子操作涉及的 Key 位于同槽；同时覆盖低版本覆盖、高并发精确计数、TTL 和失败补偿。

## 脚本

Redis Key 重构前后使用建议扫描器：

```bash
python3 <skill-dir>/scripts/redis_key_scan.py <repo-or-dir>
```

默认跳过 `*_test.go`，只检查生产 Go/Lua 中的 Redis/Rds 调用、`redis.call/pcall` 和 Key 变量赋值；需要复核测试 fixture 时显式增加 `--include-tests`。扫描结果只作为审查线索，修改前必须结合本地 helper 包确认每个命中。

脚本变更后运行 `python3 -m unittest discover -s <skill-dir>/scripts -p 'test_*.py'`。

## 交付预期

- Key 改动时更新集中 helper 或 registry。
- 扫描并清理直接拼接 Key 和通配扫描调用点。
- 为新的治理规则补聚焦测试或静态检查。
- 交付说明覆盖缓存兼容性、TTL/失效策略，以及是否需要回填或清缓存。
