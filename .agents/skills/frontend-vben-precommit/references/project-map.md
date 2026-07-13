# 项目地图

## 发现当前前端仓库

不要沿用其它 checkout 的项目名，必须从当前仓库读取：

- `package.json`
- `pnpm-workspace.yaml`
- `lefthook.yml`
- `apps/**`
- `packages/**`
- `src/**`
- locale/i18n 文件

## Hook 形态

运行命令前先读当前 `lefthook.yml` 和 package scripts。

常见模式：

- `pre-commit`: lint and typecheck commands.
- `commit-msg`: `pnpm exec commitlint --edit <commit-msg-file>`.

`pnpm -F @vben/web-antd run typecheck` 在存在时很有用，但 lint/sort hook 失败时，typecheck 通过不代表可以提交。

## 常见修复面

- `perfectionist/sort-imports`
- `perfectionist/sort-switch-case`
- `oxfmt --check`
- stylelint property order
- i18n 文案使用现有 locale helper 或项目动态翻译 helper
- `git status --short` 中显示为 `MM` 的 staged/unstaged 漂移

## 命令

优先使用当前仓库命令。常见示例：

- `pnpm -F @vben/web-antd run typecheck`
- `pnpm lint`
- `pnpm exec lefthook run pre-commit`
- `pnpm exec commitlint --edit <tmp-message-file>`
- `git diff --check`
- 准备或排查提交时运行 `git diff --cached --check`
