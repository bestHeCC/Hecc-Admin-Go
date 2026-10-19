# web — Vue 3 前端

> **当前状态**：目录骨架与布局模板已建立；实现代码待开始（见根目录 `PLAN.md` 阶段 6 起）。

## 技术栈

- Vue 3 + TypeScript
- Vite
- Pinia
- Vue Router
- Element Plus（按需引入、中文 locale、图标）
- axios
- `@microsoft/fetch-event-source`（带 Authorization 头的 SSE）

## 目录规划

```
web/
├── README.md
├── package.json
├── vite.config.ts
├── tsconfig*.json
├── .env.development / .env.production
└── src/
    ├── api/                # 按领域拆分的请求函数
    ├── components/         # DictTag、TreeSelect、PostSelect、分页等
    ├── directives/         # v-hasPerm、v-hasRole
    ├── layout/
    │   ├── BlankLayout.vue # 登录 / 强制改密 / 403 / 404
    │   ├── DefaultLayout.vue # 业务页面主布局
    │   └── components/     # Sidebar / Navbar / Breadcrumb / NoticeBell
    ├── router/             # 路由表、守卫、动态路由
    ├── stores/             # user / permission / app / dict / notice
    ├── utils/              # request / auth / tree / sse
    ├── views/              # login、change-password、dashboard、system/*、monitor/*、file、notice、profile、error
    ├── App.vue
    └── main.ts
```

## 布局模板

- `BlankLayout.vue`：无侧边栏/导航栏，承载登录、强制改密、403/404 等独立页面。
- `DefaultLayout.vue`：业务页面主布局，包含 Sidebar、Navbar、Breadcrumb、NoticeBell、AppMain，内部使用 `<router-view />`。
- 路由约定：登录/改密/错误页使用 `BlankLayout`；登录后的动态菜单路由全部作为 `DefaultLayout` 的子路由。

## 本地运行

```bash
npm install
npm run dev
```

开发代理：`/api` → `http://127.0.0.1:8080`（Vite 配置中重写去掉 `/api` 前缀）。

生产构建：

```bash
npm run type-check
npm run build
```

## 环境变量

| 变量 | 说明 |
|---|---|
| `VITE_API_BASE_URL` | 接口前缀，默认 `/api` |
| `VITE_API_TIMEOUT` | 请求超时（毫秒） |

## 请求与会话

- axios 自动附加 `Authorization: Bearer <token>`。
- 后端恒返回 HTTP 200 + `{code,message,data}`：
  - `10000`：成功，直接返回 `data`；
  - `40003`：会话失效，清理登录态并跳转登录（**无 refresh 流程**）；
  - `40002`：参数校验失败，展示 `message`；
  - 其他：`ElMessage.error(message)`。
- 强制改密：`mustChangePassword=true` 时守卫只允许进入改密页。

## 路由与权限

- 登录后拉取 `info` + `menus`，把后端菜单树转换为动态路由，挂到 Layout 下。
- `component` 字符串通过 `import.meta.glob('../views/**/*.vue')` 映射为懒加载组件。
- 按钮权限：`v-hasPerm="'system:user:add'"`；无权限菜单不渲染、路由不可达。
- 前端隐藏不作为安全边界，后端仍按路由权限码校验。

## 实时通知

- 登录后通过 `fetch-event-source` 连接 `GET /admin/notice/stream`（携带 Bearer）。
- 事件：
  - `init`：未读数 + 最近未读；
  - `notice`：新通知；
  - `unread`：未读数变化；
  - `kick`：被踢下线/封禁，立即清理登录态并提示；
  - `shutdown`：服务停机。
- 登出或切换账号时中止连接；断线自动重连。

## 页面规划

登录、强制改密、仪表盘、用户、角色、菜单、部门、岗位、字典、系统配置、操作日志、登录日志、文件管理、在线会话、通知发布/我的通知、个人中心（资料/改密/我的设备）。
