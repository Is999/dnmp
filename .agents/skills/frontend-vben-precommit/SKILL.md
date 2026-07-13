---
name: frontend-vben-precommit
description: "复现并修复 vben 前端提交检查。用于 pnpm、lefthook、pre-commit、commitlint、typecheck、lint、oxfmt 和排序规则失败。"
---

# Vben 前端提交前检查

## 工作流程

1. 先读取当前前端 `AGENTS.md` 和 `references/project-map.md`。
2. 修改前检查相关页面、组件、API wrapper、store、i18n 和 route 调用链。
3. 延续 vben 组件组合和现有项目风格；确需新增前端框架能力、目录或依赖时，先说明必要性、替代方案、影响范围和验证方式，并让开发确认后再落地；不要硬编码业务文案。
4. 按问题选择验证命令：
   - 普通前端改动：`pnpm -F @vben/web-antd run typecheck`。
   - 提交失败：`pnpm exec lefthook run pre-commit`。
   - 提交信息失败：`pnpm exec commitlint --edit <tmp-message-file>`。
   - 格式或 lint 阻塞：运行 `pnpm lint`，再修复输出里明确指出的文件和规则。
5. 如果 staged 和 unstaged 内容不一致，先看 `git status --short`。`MM` 表示 hook 可能校验旧 index，而定向命令读取新 worktree；必须先确认 hook 的真实输入，再只暂存本轮最终文件。
6. 最后一次格式化、导入排序或类型修复后重新暂存，并重跑原 hook；不能用修改前或只针对 worktree 的绿色结果替代最终 index 门禁。
7. 仓库声明 Vben 核心固定版本或“核心不动”时，记录官方 tag/commit，并读取仓库 protected-path 列表；未声明时至少检查 `packages/**`、`internal/**`、`scripts/**` 和明确标注的核心根配置。对全部受保护路径做官方基线 diff/checksum，应用层修复不得悄悄漂移到核心。
8. 修复后重新运行失败的 hook，不绕过 hook。

## 常见仓库模式

很多 vben 仓库通过 `lefthook.yml` 执行提交检查：`pre-commit` 通常跑 lint/typecheck，`commit-msg` 通常跑 commitlint。先读当前仓库实际配置和 package scripts，不继承其它仓库假设。

本 skill 负责 hook/index、cspell、commitlint、oxfmt 和 staged 快照问题；若根因位于 install、Node/pnpm、lockfile、postinstall、构建编排或 CI 环境，转用 `$vue-monorepo-ci-guard`。

## 交付检查

- 说明复现了哪个 hook 或检查命令。
- 说明修复了哪个 formatter/lint/type 错误。
- 说明是否需要后端契约同步或数据迁移。
