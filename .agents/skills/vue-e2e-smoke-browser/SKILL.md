---
name: vue-e2e-smoke-browser
description: "浏览器冒烟验证 Vue/vben 可见流程。用于 UI、route/menu、form/table/action、响应式布局、auth/security、localhost、截图和交互检查。"
---

# Vue 浏览器冒烟

## 工作流程

1. 先确认仓库本地运行方式：包管理器、dev script、端口、env 文件、proxy、所需后端或 mock 服务。
2. 需要时启动或复用 dev server。端口占用时使用安全备用端口并说明。
3. 有可用工具时，用 in-app browser 或 Playwright 兼容浏览器打开相关路由。
4. 验证真实流程：路由可渲染、表格可加载、筛选/表单可用、主操作打开正确 drawer/modal、提交/取消/重试状态合理、permission/disabled 状态一致。
5. 布局改动要检查桌面和移动端或窄视口。
6. 检查影响变更路径的 console/network 错误，并区分后端/API 不可用与前端回归。
7. 只有在需要证明布局或辅助排查时才截图。

## 验证

- 浏览器冒烟要搭配 typecheck/lint；页面可用不能替代静态检查。
- canvas、3D 或媒体重的页面要确认渲染像素非空且画面构图正确。
- 运行 `git diff --check` 并检查 `git status --short`。

## 交付证据

交付时说明 URL、路由、测试过的操作、视口覆盖、console/network 问题、截图情况，以及跳过检查的原因。
