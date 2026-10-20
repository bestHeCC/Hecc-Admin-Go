# web — Vue 3 前端

> **当前状态**：前端骨架已完成并可构建运行 —— 登录、强制改密、主布局、动态路由、按钮权限、请求封装、SSE 客户端均已就绪。
> 业务页面（用户/角色/菜单等）待按根目录 [PLAN.md](../PLAN.md) 阶段 7 实现。
>
> 已通过：`npm run build`、`npm run test`、`npm run lint`。

## 技术栈

- Vue 3.5 + TypeScript 5.9
- Vite 7
- Pinia 3
- Vue Router 4
- Element Plus 2（组件按需自动引入、中文 locale、图标全量注册）
- axios
- `@microsoft/fetch-event-source`（带 Authorization 头的 SSE）
- Vitest + ESLint 9（flat config）+ Prettier

## 目录结构

```
web/
├── index.html
├── package.json / package-lock.json
├── vite.config.ts               # @ 别名、/api 代理、Element Plus 按需引入
├── vitest.config.ts
├── tsconfig.json / tsconfig.app.json / tsconfig.node.json / tsconfig.vitest.json
├── eslint.config.js
├── .prettierrc.json / .prettierignore
├── .env.d.ts
├── .env.development / .env.production
├── public/
│   └── favicon.svg
└── src/
    ├── main.ts                  # 应用入口
    ├── App.vue                  # ElConfigProvider(zh-cn) + SSE 生命周期
    ├── auto-imports.d.ts        # unplugin-auto-import 生成，提交仓库
    ├── components.d.ts          # unplugin-vue-components 生成，提交仓库
    ├── assets/styles/           # 全局样式
    ├── components/              # AppSidebar / SidebarMenuItem / AppNavbar / AppBreadcrumb / NoticeBell
    │   └── __tests__/           # 权限工具单元测试
    ├── config/                  # 应用配置（标题、接口前缀、存储键、路由常量）
    ├── directives/              # v-hasPerm
    ├── hooks/                   # usePermission
    ├── models/                  # API/登录/菜单类型
    ├── router/
    │   ├── index.ts             # 静态路由
    │   ├── dynamic.ts           # 菜单树 → 动态路由
    │   └── guard.ts             # 登录/强制改密/权限守卫
    ├── services/                # auth、app 请求函数
    ├── stores/                  # auth（会话）、account（资料/权限/菜单）、app（UI/通知）
    ├── types/                   # 路由 meta 类型扩展
    ├── utils/                   # request / auth / storage / sse / tree / permission
    └── views/
        ├── layouts/             # BlankLayout.vue、DefaultLayout.vue
        ├── auth/                # LoginView.vue、ChangePasswordView.vue
        ├── pages/               # HomeView.vue、ForbiddenView.vue
        └── error/               # NotFoundView.vue
```

> 与早期规划的差异：ESLint 使用 9.x flat config（`eslint.config.js`）替代 `.eslintrc.cjs`；
> TypeScript 配置使用 `.json` 后缀（`tsconfig.app.json`）以符合 Vue 官方模板约定。

## 本地运行

```bash
npm install
npm run dev       # http://localhost:5173
```

开发代理：`/api` → `http://127.0.0.1:8080`（Vite 配置中重写去掉 `/api` 前缀）。

常用命令：

| 命令 | 说明 |
|---|---|
| `npm run dev` | 启动开发服务器 |
| `npm run build` | `vue-tsc -b && vite build` |
| `npm run type-check` | 仅类型检查 |
| `npm run test` | Vitest 单次运行 |
| `npm run lint` | ESLint |
| `npm run format` | Prettier 格式化 |

## 环境变量

| 变量 | 说明 |
|---|---|
| `VITE_APP_TITLE` | 页面标题与应用名，默认 `Hecc Admin` |
| `VITE_API_BASE_URL` | 接口前缀，默认 `/api` |
| `VITE_API_TIMEOUT` | 请求超时（毫秒），默认 `15000` |
| `VITE_PROXY_TARGET` | 开发代理目标，默认 `http://127.0.0.1:8080` |

## 布局模板

- `BlankLayout.vue`：无侧边栏/导航栏，承载登录、强制改密、403/404 等独立页面。
- `DefaultLayout.vue`：业务页面主布局，包含 Sidebar、Navbar、Breadcrumb、NoticeBell、AppMain，内部使用 `<router-view />`。
- 路由约定：登录/改密/错误页使用 `BlankLayout`；登录后的动态菜单路由全部作为 `DefaultLayout` 的子路由。

## 请求与会话

- axios 自动附加 `Authorization: Bearer <token>`。
- 后端恒返回 HTTP 200 + `{code,message,data}`：
  - `10000`：成功，直接返回 `data`；
  - `40003`：会话失效，清理登录态并跳转登录（**无 refresh 流程**）；
  - `40002`：参数校验失败，展示 `data` 中的校验文案（为空时回退 `message`）；
  - 其他：展示 `data` 中的业务文案（为空时回退 `message`）。
- hecc-blot 约定失败时 `data` 承载**用户可见文案**、`message` 是通用短语，
  因此 `utils/request.ts` 统一优先读取 `data` 中的字符串。
- 强制改密：`mustChangePassword=true` 时守卫只允许进入改密页；改密接口若返回新 token，前端会替换本地 token 并重新拉取用户信息。
- token 与强制改密标记存放在 localStorage；`40003` 会同时清理 localStorage 与 Pinia 状态。

## 路由与权限

- 静态路由：`/login`、`/change-password`、`/403`、`/404`、`/`（`DefaultLayout` + 首页）。
- 登录后拉取 `info` + `menus`，把后端菜单树转换为动态路由，挂到 `DefaultLayout` 下。
- `component` 字符串通过 `import.meta.glob('../views/**/*.vue')` 映射为懒加载组件；目录型菜单无组件时用内嵌 `<router-view />` 承载子路由。
- 动态路由注册完成后追加 `/:pathMatch(.*)*` 兜底到 404；重新加载菜单时会先移除旧路由。
- 守卫流程：无 token → 登录页；`mustChangePassword` → 改密页；首次进入业务页拉取 info/menus；路由 meta 权限不足 → 403。
- 按钮权限：`v-hasPerm="'system:user:add'"`；超级管理员或 `*` 权限直接放行。
- 前端隐藏不作为安全边界，后端仍按路由权限码校验。

## 实时通知

- 登录后通过 `fetch-event-source` 连接 `GET /admin/notice/stream`（携带 Bearer）。
- 事件：
  - `init`：未读数 + 最近未读；
  - `notice`：新通知；
  - `unread`：未读数变化；
  - `kick`：被踢下线/封禁，立即清理登录态并提示；
  - `shutdown`：服务停机。
- 模块加载时不会自动连接；`App.vue` 监听 token 变化建立/断开连接，登出或切换账号时中止。
- 断线自动重连；未读数与连接状态保存在 `app` store。

## 页面规划（待实现）

登录、强制改密、仪表盘、用户、角色、菜单、部门、岗位、字典、系统配置、操作日志、登录日志、文件管理、在线会话、通知发布/我的通知、个人中心（资料/改密/我的设备）。
