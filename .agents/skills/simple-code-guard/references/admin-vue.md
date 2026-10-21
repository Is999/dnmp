# admin-vue 项目边界

## 真实结构

- 可见功能沿 `views`、`router`、`api`、`store`、`components` 和 `locales` 闭环。
- 优先复用现有 Vben 组件、schema、hooks 和请求客户端，不另建平行 UI 或状态框架。
- 前端只承载交互状态和展示规则；后端权限、安全和数据规则不复制成第二套业务实现。
- 注释与维护质量按[本 skill 的规则入口](../SKILL.md)引用的公共规范验收；核对声明/状态的真实语义与受影响的旧说明，复杂规则及关键流程解释充分，直观操作不机械翻译，不用注释掩盖缺口。

## 简化重点

- 单页面使用的状态优先留在页面；没有稳定复用时不提取 composable、store 或通用组件。
- API wrapper 直接映射后端契约，不叠加只转发参数或改名的多层 wrapper。
- 表格、表单、弹窗和 action 优先使用现有 schema 与组件能力；不要为少量字段制造配置生成器。
- 避免无边界的 deep watch、重复请求、全量前端过滤和大数组复制；分页、取消和 loading 状态直接可见。
- 无路由或当前调用方只代表未启用；删除前还须排除动态注册、共享契约、脚本、测试与运维入口，不能误删有独立职责的基础能力。
- 性能优化优先减少网络请求、重复渲染和大对象响应式开销，不用难读的缓存技巧优化普通页面。

## 验证

按下列触发条件在最终候选版本运行：

- `pnpm -F @vben/web-antd run typecheck`
- 提交就绪时运行 `pnpm exec lefthook run pre-commit`
- TypeScript 源码或规则变化时运行受影响 package 的 lint；依赖、构建配置或产物边界变化时运行 build；页面、路由、表单、弹窗、权限或可见交互变化时运行浏览器冒烟
- `git diff --check`、`git diff --cached --check`、`git status --short`
