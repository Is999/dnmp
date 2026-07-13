---
name: vue-permission-state-audit
description: "审计 Vue/vben 权限和安全状态。用于 route guard、menu/button permission、row action、visible/disabled、重复点击、MFA、签名/加密、auth/session。"
---

# Vue 权限状态审计

## 工作流程

1. 一起追踪 route、menu、page、table action、button、API wrapper、permission code 和后端契约。
2. 验证 action 可见性、disabled 状态、确认弹窗、loading 锁、重复点击防护、empty/error 处理和 retry 行为。
3. login、logout、refresh、账号切换或重认证中的每个 `await` 都要绑定来源 token/session identity，并在改写 store、route、弹窗或 toast 前复检；旧异步结果不能覆盖新账号。
4. poller、timer、subscription、jobId 和后台重试必须绑定账号身份，并在会话切换时停止；组件未卸载不代表任务仍属于当前账号。
5. 前端 permission 假设要对齐后端 RouteMeta、业务码、MFA、签名和加密策略。
6. 确保敏感字段不会被日志记录、明文展示、不必要持久化，或进入过宽的签名/加密 payload。运行期身份导致重载后必失效的票据应只存内存。
7. 对有状态资源检查行级 action gate；不要暴露后端必然拒绝的操作。
8. 为 permission/security 错误和确认提示新增或更新 i18n 文案。

## 验证

- 相关时运行前端 typecheck 和 lint/pre-commit。
- 可见 permission 或 security 流程使用 `$vue-e2e-smoke-browser`。
- 运行 `git diff --check` 并检查 `git status --short`。

## 交付证据

交付时说明已检查的 permission、visible/disabled 状态、后端契约对齐、安全字段处理、已测试 UI 状态，以及跳过的浏览器检查。
