# 团队采用

## 安装形态

仓库 `.agents/skills` 是项目标准的唯一权威源。个人环境可把缺失的标准 skills 安装到 `$CODEX_HOME/skills` 或 `~/.codex/skills`，让 Codex 在仓库外也能发现。

同名 skill 已由仓库提供时，个人目录不得维护另一份可独立修改的版本；双份来源会造成重复触发和规则漂移。确需兼顾仓库外使用时，只允许通过一次性同步流程从仓库生成个人镜像，并在同步后逐目录执行内容一致性校验。规则变更必须先修改仓库权威源，再整体覆盖个人镜像，禁止双向合并或分别修补。

建议同步流程遵循以下边界：

- 仅覆盖仓库清单中的同名 skill，不能对个人 skills 根目录执行全量删除。
- 同步前冻结仓库 skill 变更集；同步后用递归 diff 确认文件、权限和内容一致。
- 项目审计、交付和 CI 只以仓库 skill 为准，个人镜像是否存在不能改变项目闸门。

- `standard-development-flow`
- `requirement-intent-gate`
- `go-ai-implementation-guard`
- `implementation-closure-review`
- `go-comment-style-audit`
- `redis-key-governance`
- `api-contract-sync`
- `frontend-vben-precommit`
- `go-db-query-performance-guard`
- `go-test-failure-debugger`
- `go-config-runtime-guard`
- `go-worker-concurrency-guard`
- `go-security-route-guard`
- `go-migration-backfill-runbook`
- `vue-vben-feature-delivery`
- `vue-api-contract-client-sync`
- `vue-e2e-smoke-browser`
- `vue-monorepo-ci-guard`
- `vue-permission-state-audit`
- `sibling-repo-sync-review`
- `release-handoff-guard`

仓库内 `.agents/skills` 按项目裁剪，避免不相关 skill 增加 token 和误触发：

- Go 后端仓库：使用通用流程、Go、Redis、API 契约、跨仓库和交付类 skill。
- Vue/vben 前端仓库：使用通用流程、vben、Vue API client、浏览器冒烟、前端 CI/hook、权限状态、跨仓库和交付类 skill；不放通用后端 `api-contract-sync`。
- 工作区入口或共享规范仓库：可放完整集合，用于跨项目维护。

## 仓库入口

在每个仓库的 `AGENTS.md` 中加入一条主规则：

```text
功能开发、问题修复、重构、生产级复核、交付前检查必须优先使用 $standard-development-flow，再按场景调用专项 skill。
```

项目特有规则放在仓库里，不放进共享 skill：

- build、test、lint 和 commit-hook 命令。
- 本地 route、permission、security、Redis、API-doc 和前端约定。
- data migration、backfill、cache invalidation 和生产审批规则。

## 项目画像

新项目使用标准流程前，先创建或更新仓库本地指导：

- `AGENTS.md`：简短硬约束和必跑检查。
- AI 开发文档：代码风格、注释、命名、日志、SQL/Lua、数据、API、前端和交付规则。
- 契约文档：API 格式、业务码、权限、安全字段、i18n 和 RouteMeta。
- 验证命令：package test、full test、typecheck、lint、build、hook 命令和 `git diff --check`。

## 标准运行规则

共享 workflow 负责流程，项目负责具体命令和领域规则。

不要让每个开发者私自 fork workflow。需要变化时更新共享 skill 和仓库入口，让所有开发者使用同一套闸门。
