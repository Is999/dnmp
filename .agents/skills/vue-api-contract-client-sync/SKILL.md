---
name: vue-api-contract-client-sync
description: "同步 Vue/vben API client 与后端契约。用于 route、字段、业务码、权限、MFA、签名/加密、导出、TypeScript 类型、wrapper、i18n。"
---

# Vue API 契约客户端同步

## 工作流程

1. 先读后端契约来源：route、docs、request/response struct、业务码、permission code、安全策略和示例。
2. 同步更新前端 API wrapper、TypeScript 请求/响应类型、调用点、table/form schema、route/menu permission 和 i18n 文案。
3. 以目标项目当前唯一契约确定字段名称，不保留 snake_case/camelCase 双字段解析或旧字段别名；发现后端、文档与调用方不一致时，报告具体差异并按已确认范围同步，不自行增加兼容分支或前端专用命名。
4. 错误处理要对齐后端业务码和消息；不要把非零校验错误误当成功或轮询中状态。
5. MFA、签名、加密只发送文档化字段，大表单、数组、分页参数不要误放进安全中间件负载。请求先加密再签名，响应先验签再解密，签名使用传输密文；加密字段去掉 `json:` 标记后须在同方向签名清单中，嵌套点路径必须一致。验签失败不得解密或更新登录态，调试签名使用 `debugSign`，不占用传输层 `sign`。同步后端 manifest，并验证密文篡改、缺少签名和编码膨胀边界；字段上限和算法以对接后端为准，不照搬其他服务。
6. retry、timeout、batch、concurrency、pageSize 等数值字段必须从后端权威常量或文档同步 min/max/default；只有前端 `min` 或无服务端硬上限都不算契约闭环。
7. JWT/session 契约变化时核对 refresh/logout 并发、稳定会话 ID、`auth_version`、业务码和切账号状态清理；旧异步结果不得覆盖新账号 token、loading、toast 或轮询状态。
8. 前端可见的请求/响应行为变化时，同步更新文档或示例。

## 验证

- 运行 `pnpm -F @vben/web-antd run typecheck` 或仓库等价命令。
- wrapper/type 改动影响 import 排序或导出生成时，运行 lint/pre-commit。
- 变更的 API 路径在 UI 可见时，使用 `$vue-e2e-smoke-browser`。
- 运行 `git diff --check` 并检查 `git status --short`。

## 交付证据

交付时说明已核对的后端来源、已更新的前端文件，type/i18n/permission/security 是否同步，运行了哪些命令，以及是否存在后端契约歧义。
