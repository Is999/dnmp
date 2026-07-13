---
name: go-security-route-guard
description: "审查 Go 路由安全和敏感契约。用于 auth、JWT/session、MFA、权限、RouteMeta、签名、加密、公白名单路由、业务鉴权码、前端联动。"
---

# Go 路由安全护栏

## 工作流程

1. 从注册一路追到 middleware、handler、logic、response wrapper、文档和前端调用方。
2. 分类路由：登录态、公开、内网、白名单 token、MFA、签名、加密或混合。
3. 核对 RouteMeta、权限码、审计动作、安全策略、业务码、i18n 和文档是否同步。
4. JWT/session 改动要检查 `jti`、稳定会话 ID、`auth_version`、用户状态、app ID/tenant scope、登出/刷新生命周期和重放边界。数据库认证版本是权威撤销栅栏：禁用、改密等敏感事务先原子递增并提交，再同步 Redis；JWT 必须携带版本，旧版本不能覆盖新版本，请求期仍要证明数据库提交到缓存同步之间失败关闭。Hash、ZSET 和版本 Key 必须使用同一 Redis Cluster hash tag，create/verify/rotate/invalidate 通过 Lua 原子处理，并覆盖同 token 单次刷新、refresh/logout 竞态、每用户会话硬上限和 uint64 精度；Go race 通过不能证明分布式状态无竞态。
5. 登录失败必须检查账号不存在、密码错误、禁用等分支的外部 code/status/message 和可观测耗时，避免账号枚举；不存在账号应执行固定成本的密码哈希校验，内部审计再保留真实原因。
6. CAPTCHA、login、register、reset 等匿名高成本入口必须核对可信客户端 IP、账号/IP 双维度限流、原子计数/TTL、429 契约和 key 基数；阈值没有容量依据时不得猜值。
7. token、ticket、nonce、验证码、重置 key、签名密钥和锁 ownership value 必须使用 CSPRNG；禁止 `math/rand`、时间种子或依赖明确标注为非安全的随机 helper。
8. 签名/加密必须列出明确字段；不要默认签名/加密完整 body、大对象、数组或分页列表。CBC 等非 AEAD 加密启用时必须有完整性保护，配置校验不得允许“只加密不验签”的不安全组合。字段级响应必须满足 `ResponseCipher ⊆ ResponseSign`：签名读取解密前的真实明文点路径，服务端先签名后加密，前端先解密后验签；RouteMeta/manifest、共享测试向量和前端策略必须同步，并用不变量测试阻止漏签。
9. 响应安全中间件仅在真实需要改写时缓冲响应。下载、Range、SSE 或大响应必须保留流式输出和必要的 `Flusher`/`Hijacker`/`Pusher` 能力，禁止无条件整包缓存。
10. 错误消息保持安全：不暴露 SQL、密钥、内部表名、真实下游错误或 key material。
11. 相关时补 handler/middleware smoke test：鉴权 envelope、公开路由兼容、安全失败业务码、字段大小限制、响应加密字段签名子集、refresh/logout 并发终态，以及流式响应不被缓冲的回归测试。

## 验证

- 运行 handler/middleware/security 相关聚焦测试。
- request/response、业务码、文档、前端类型或 i18n 变化时使用 `$api-contract-sync`。
- 运行 `git diff --check` 并检查 `git status --short`。

## 交付证据

说明路由分类、安全字段、权限/业务码/文档同步、测试结果、跳过检查，以及前端或配置后续事项。
