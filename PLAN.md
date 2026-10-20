# Hecc-Admin-Go 开发计划

本文档记录项目目标、当前进度、阶段任务与验收标准。项目概览见 [README.md](README.md)，后端与前端的使用说明分别见 [server/README.md](server/README.md) 与 [web/README.md](web/README.md)。

## 1. 项目目标

通用管理后台：后端 Go 1.26.1（hecc-blot 框架、PostgreSQL、Redis、Kafka），前端 Vue 3 + TypeScript + Vite + Element Plus。

**首版范围**

- 会话登录、强制首次改密、在线会话、踢下线、封禁/解封
- 用户、角色、菜单、部门、岗位
- RBAC：菜单 + 按钮级权限
- 数据权限：按当前用户的部门/岗位自动过滤业务数据
- 字典、系统配置、操作日志、登录日志
- 文件上传/下载
- 站内通知：SSE 实时推送 + 离线未读补拉
- 通用 CRUD 基类

**不做**：代码生成器、多租户、OAuth/SSO。

**依赖方式**：`server/go.mod` 直接引用 hecc-blot 已发布模块，不使用 `replace` / `go.work` / 本地源码。框架未提供认证、RBAC、配置加载与迁移工具，这些由本项目自建（迁移以 `init.sql` 手工维护）；CORS 由 nginx 或开发代理处理，Go 侧不添加跨域头。

## 2. 当前进度

| 阶段 | 内容 | 状态 |
|---|---|---|
| 1 | 仓库与运行骨架 | 已完成 |
| 2 | 数据层与通用 CRUD 原型 | 进行中 |
| 3 | 会话认证与 RBAC | 未开始 |
| 4 | 数据权限与核心 CRUD | 未开始 |
| 5 | 扩展模块与 SSE/Kafka | 未开始 |
| 6 | 前端骨架 | 已完成 |
| 7 | 前端业务页 | 未开始 |
| 8 | 交付 | 未开始 |

**已具备**

- 后端：YAML 配置加载与校验、日志/Trace、PostgreSQL/Redis/Kafka 初始化、IOC 装配、访问日志、`GET /health`；Redis 启动探测失败即退出，Kafka 不可用时降级。
- 数据库：`server/scripts/init.sql` 已包含全部 `sys_*` 表、索引与默认账号（`admin / Admin@123456`，首次登录强制改密）；脚本可重复执行。
- 基础代码：`entity/model` 的 `BaseModel` / `SoftDeleteModel` / `DataOwner`，`entity/config` 配置结构，`enum` 业务码/状态/Redis 键，`contract.ISessionStore` 会话契约，密码哈希与随机 token 工具。
- 前端：登录、强制改密、主布局、动态路由、按钮权限、请求封装、SSE 客户端；`npm run build`、`npm run test`、`npm run lint` 通过。
- 工程：根目录 Makefile、双端 README、`.gitignore`。

**待补齐**

- 各业务领域的 GORM 模型与通用 CRUD 基类。
- 会话存储实现、认证/RBAC/数据权限中间件与业务接口。
- 菜单/按钮权限种子数据（`init.sql` 目前只含部门、角色、admin 用户）。
- 前端业务页面与后端接口联调。

## 3. 关键约定

这些约定贯穿后续阶段，实现时以本节为准。

### 3.1 项目结构

- 仓库只保留 `server/`、`web/` 两个应用目录，根目录放 README、PLAN、Makefile。
- 后端分层：`api/`（API 结构体）、`service/`（业务实现）、`entity/`（api/config/model/response）、`contract/`（接口）、`enum/`（常量）、`router/`、`middleware/`、`util/`。
- 新增应用层包按需建立：`crud/`（通用 CRUD）、`sse/`（通知端点与本地连接表）。依赖装配暂放在 `cmd/server/main.go`，路由统一在 `router/router.go` 注册。

### 3.2 数据库

- 表结构以 `server/scripts/init.sql` 为准，不使用 Go 迁移工具；修改表结构时同步修改 `init.sql` 与 `entity/model`，并保持脚本可重复执行。
- ID 使用 `BIGSERIAL`/`int64`；软删除使用 `gorm.DeletedAt`；关系使用逻辑外键，不做数据库外键约束。
- 业务模型嵌入 `BaseModel`（或 `SoftDeleteModel`）与 `DataOwner{DeptID, PostID}`；模型实现 `GetID() int`，表名显式 `TableName()`，查询前必须 `WithContext(ctx)`。
- 业务数据写入时由当前会话用户填充 `dept_id/post_id`；两字段都为空视为全局数据。

### 3.3 认证与会话

- 不使用 JWT。登录生成 32 字节随机 token（base64url），Redis 只保存 `sha256(token)`；删除会话即吊销 token，无 refresh 流程。
- Redis 键统一从 `enum` 取：`admin:session:{hash}`（Hash）、`admin:user:sessions:{userID}`（Set）、`admin:sessions:active`（ZSet）。
- 滑动空闲过期（默认 2h）+ 绝对过期（默认 12h）；`session.max_per_user` 控制同账号会话数，0 表示不限。
- 密码使用 bcrypt；连续失败 5 次锁定 15 分钟；登录限流 10 次/分钟（Redis 计数）。
- 强制改密期间仅放行 `info`、`password`、`logout`；改密成功后轮换当前 token 并删除该用户其他会话。
- 封禁/踢下线通过删除会话即时生效，同时广播 `kick` 事件；账号禁用或 `banned_until` 到期前校验在登录时执行。

### 3.4 RBAC 与数据权限

- 菜单类型：`dir` 目录、`menu` 页面、`button` 按钮；按钮节点只承载权限码。
- 路由注册器登记 `FullPath -> {Permission, Module, Action}`，权限中间件按表校验；未登记路由仅需登录；超级管理员放行。
- 角色只控制菜单/按钮，不配置数据范围。
- 数据权限规则：

  | 用户配置 | 可见数据 |
  |---|---|
  | `is_super` | 全部 |
  | 未设置部门且未设置岗位 | 全部数据 |
  | 仅设置部门 | 本部门及下级部门数据 + 全局数据 |
  | 仅设置岗位 | 本岗位数据 + 全局数据 |
  | 部门 + 岗位 | 部门范围 ∪ 岗位范围 + 全局数据 |

- 受数据权限约束：用户、部门树、文件、通知、操作日志、登录日志；不受约束：角色、菜单、字典、系统配置、岗位（仅受按钮权限控制）。
- 列表与详情统一走 `util/scope`；越权详情返回 40005 `NoDataPermission`。

### 3.5 通用 CRUD

- `crud.Service[T]` 提供 `Create/Get/Update/Delete/Page`，支持钩子、软删除、按模型配置数据权限函数。
- 通用 API：`PageApi[T,R]`、`GetApi[T]`、`CreateApi[T]`、`UpdateApi[T]`、`DeleteApi[T]`；POST DTO 通过自定义 `UnmarshalJSON` 保持扁平绑定。
- `crud.Register[T]` 自动注册标准端点与权限码：
  - `POST {resource}/page` → `{prefix}:list`
  - `POST {resource}/get` → `{prefix}:query`
  - `POST {resource}/create` → `{prefix}:add`
  - `POST {resource}/update` → `{prefix}:edit`
  - `POST {resource}/delete` → `{prefix}:remove`
- 新增模型只需“模型 + 分页/创建/更新 DTO + 一行注册”；树形、分配关系、封禁、重置密码、上传等特殊动作另写自定义 API。

### 3.6 API 约定

- 路由只有 `Get` / `Post`，写操作统一 POST。
- 响应恒为 HTTP 200：`{code, message, data}`；成功码 10000，框架协议码见 `enum/code.go`，业务错误码 60000+。
- 业务错误通过 `errorSvc.New(code, "用户可见文案")` 返回，文案放在 `data`。
- 分页请求 `page/pageSize`，响应 `{list, page, pageSize, total}`。
- CORS 由 nginx 或开发代理处理，Go 侧不添加 CORS 头；生产环境前端静态文件与 `/api` 同源部署。
- 文件存储使用 `Storage` 接口 + 本地驱动（`server/storage/uploads/YYYY/MM/`），预留 OSS 实现。

### 3.7 SSE 与 Kafka

- Topic `admin.events`，消息 `{id,type,userIDs,sessionID,payload,ts}`；Key 用 userID 保持同一用户事件有序。
- 每个实例使用稳定唯一消费组 `admin-sse-{instanceID}`，确保收到全量事件而不是同组分摊；`mq.kafka.start_offset: last`。
- 消费端丢弃 `ts` 早于进程启动时间 30 秒的消息，避免异常回放；Kafka 不可用时服务继续运行，通知降级为离线补拉。
- SSE 事件：`init`、`notice`、`unread`、`kick`、`shutdown`；框架并发连接上限 1000。
- 前端使用 `@microsoft/fetch-event-source`（原生 EventSource 不能携带 Authorization 头）。

## 4. 开发阶段

### 阶段 1：仓库与运行骨架（已完成）

**完成内容**

- 建立 `server/`、`web/` 双目录与根目录工程文件。
- 后端完成配置加载、日志/Trace、PostgreSQL/Redis/Kafka 接入、IOC 装配、访问日志、`GET /health`、密码与 token 工具。
- `scripts/init.sql` 完成建库、全部业务表、索引与默认账号；`scripts/create-topics.sh` 创建 Kafka 主题。
- 根目录 Makefile 聚合双端常用命令。

**验收**：`go run ./cmd/server` 启动成功，`/health` 返回 `code=10000`。

### 阶段 2：数据层与通用 CRUD 原型（进行中）

**目标**：补齐 GORM 模型，并用 `Post` 验证通用 CRUD 基类。

**任务**

1. 按 `init.sql` 补齐 `entity/model`：user、post、user_post、role、menu、user_role、role_menu、dept、dict_type、dict_item、config、oper_log、login_log、file、notice、notice_receiver。
2. 实现 `crud` 包：模型约束、泛型 Service、通用 API、注册器、`PageRequest` 与分页结果。
3. 以 `Post` 为原型接入路由与 IOC，验证泛型实例化、`inject` 反射、扁平 JSON 绑定、`binding` 校验和权限码登记。
4. 补齐 DTO 与必要的字段白名单；模型与 `init.sql` 双向核对。
5. 为通用 CRUD 与模型写单元测试。

**验收**

- `go build ./...`、`go vet ./...`、`go test ./...` 通过。
- `init.sql` 重复执行无副作用。
- 岗位分页/详情/新增/修改/删除全部由基类完成，无需手写 Handler/Service。
- 若泛型 API 与框架反射/IOC 不兼容，退化为“泛型 Service + 每个模型一个薄 API 包装”（Call 内一行委托）。

### 阶段 3：会话认证与 RBAC（未开始）

**目标**：完成登录闭环与按钮级权限。

**任务**

1. 基于 go-redis 实现 `contract.ISessionStore`：创建、读取、滑动续期、删除、按用户删除、按用户列出；维护在线会话索引。
2. 实现认证服务：登录、登出、`info`、`menus`、`profile`/改资料、改密、个人设备列表与踢出；登录成功/失败写 `sys_login_log`。
3. 登录安全：bcrypt 校验、失败计数与锁定、Redis 登录限流、账号状态与封禁时间校验。
4. 中间件：`SessionMiddleware`（Bearer → SHA-256 → Redis → 续期 → 绝对过期/状态/强制改密校验 → 写入 `IContext` 与 Request.Context）、`PermissionMiddleware`（路由权限表）、访问日志已有。
5. 路由权限注册器：登记 `path -> {permission, module, action}`；超级管理员放行。
6. 用户上下文缓存：`admin:ctx:{globalVersion}:{userID}`（5 分钟）+ 全局版本 `INCR`；用户、部门、岗位、角色、菜单变更时失效。
7. 在线会话管理与踢人、封禁/解封接口；接入 `kick` 事件（SSE 在阶段 5 落地，本阶段先完成会话删除与事件发布预留）。
8. 补充登录、强制改密与基础菜单/按钮种子。

**验收**

- admin 首次登录被强制改密；改密后 token 轮换并正常进入系统。
- 未登录访问业务接口返回 40003；无权限返回 40004。
- `info` 返回用户、角色、权限码，`menus` 返回菜单树。
- 管理员踢下线后目标会话立即失效；封禁账号无法登录，解封后恢复。
- 连续输错密码触发锁定与登录限流。

### 阶段 4：数据权限与核心 CRUD（未开始）

**目标**：按部门/岗位过滤业务数据，并完成核心管理模块。

**任务**

1. 实现 `util/scope`：`Resolve` 解析当前用户范围，`Apply` 过滤业务表，`ApplyUser` 联 `user_post` 过滤用户表；详情按 ID 查询后二次校验。
2. 用户、角色、菜单、部门 CRUD：
   - 用户：部门树选择、岗位多选、分配角色、重置密码、封禁/解封、状态；
   - 角色：菜单树（含按钮）授权；
   - 菜单/部门：树形接口 + 标准 CRUD；
   - 标准端点优先走通用 CRUD，特殊动作写自定义 API。
3. 数据权限接入用户、部门树、文件、通知、操作/登录日志；角色/菜单/字典/配置/岗位不受数据权限约束。
4. 操作日志中间件：包装响应渲染捕获最终 `code`，记录操作者 `dept_id/post_id`；登录日志由认证服务写入。
5. 补齐全部菜单与按钮权限种子，便于前端动态路由与 `v-hasPerm`。

**验收**

- 创建仅部门、仅岗位、部门+岗位、都未设置四类用户，各自列表可见范围符合规则。
- 全局数据对四类用户均可见；越权访问详情返回 40005。
- 标准模块（岗位、字典、配置等）可通过基类端点完成 CRUD。
- 操作日志与登录日志可按数据权限查看。

### 阶段 5：扩展模块与 SSE/Kafka（未开始）

**目标**：补齐字典、配置、文件、通知与跨实例实时推送。

**任务**

1. 字典类型/数据项 CRUD + 按类型取数据项；系统配置 CRUD + 按键取值；写操作后失效本地缓存。
2. 文件：`Storage` 接口与本地驱动、上传校验（大小/扩展名/MIME）、分页/删除、鉴权下载、静态 `/uploads/*filepath`。
3. 通知：发布（事务写 `sys_notice` + 批量写 `sys_notice_receiver`）、分页、我的通知、标记已读、未读数。
4. SSE：`sse.NewSseSvc` 复用 HTTP 端口，`GET /admin/notice/stream` 从 Request.Context 取认证信息；维护本机连接表。
5. Kafka：生产者发布 `admin.events`，每实例唯一消费组消费并分发到本机 SSE；事件带 `ts` 过滤历史消息。
6. 定时任务：清理过期会话索引、过期日志、孤立文件记录；shutdown hook 停止 SSE/Kafka 消费/调度器。

**验收**

- 两个 server 实例连接同一 PostgreSQL/Redis/Kafka，任一实例发布通知，两个实例上的用户都能实时收到。
- 重启实例后不重复推送旧事件；离线用户重连 `init` 补齐未读数。
- 踢人/封禁事件通过 SSE 立即送达并清理登录态。
- 上传/下载、通知发布与已读、日志清理正常。

### 阶段 6：前端骨架（已完成）

**完成内容**

- Vite/TypeScript/Element Plus 工程、按需引入、`@` 别名、`/api` 代理。
- `BlankLayout` / `DefaultLayout`、登录页、强制改密页、403/404 首页。
- 动态路由、路由守卫、`v-hasPerm`、`usePermission`。
- axios 请求封装（Bearer、统一解包、40003 会话失效、无 refresh）、Pinia 会话/账号/应用状态。
- SSE 客户端与服务健康检查封装；`npm run build`、`npm run test`、`npm run lint` 通过。

**说明**：登录、用户信息、菜单等接口依赖阶段 3 的后端实现，联调在阶段 3 完成后进行。

### 阶段 7：前端业务页（未开始）

**目标**：完成全部业务页面并端到端联调。

**任务**

1. 与后端领域一一对应的 `services/` 请求函数与 `models/` 类型。
2. 通用组件：`DictTag`、`TreeSelect`、`PostSelect`、`TableToolbar`、`Pagination`。
3. 页面：仪表盘、用户、角色、菜单、部门、岗位、字典类型/数据、系统配置、操作日志、登录日志、文件管理、在线会话、通知发布/我的通知、个人中心（资料/改密/我的设备）。
4. 接入按钮权限、路由权限、部门/岗位选择与“未设置部门/岗位时可见全部数据”提示。
5. 统一列表/表单/弹窗交互与错误提示；补齐前端单测。

**验收**

- 所有菜单可进入，无权限菜单不渲染、路由不可达。
- 列表分页、筛选、新增、编辑、删除、特殊动作均可用。
- 通知铃铛未读数实时更新，被踢自动退出。
- `npm run type-check && npm run build && npm run test && npm run lint` 通过。

### 阶段 8：交付（未开始）

**任务**

1. 全量单元测试（会话、密码、权限匹配、菜单树、数据范围、通用 CRUD、SSE 分发）。
2. 手工 E2E 回归：强制改密、RBAC、数据权限、踢人/封禁、双实例通知、文件与日志。
3. 文档校验：根 README 概览、`server/README.md`、`web/README.md`、本计划与实现保持一致。
4. 构建验证；Dockerfile 可选放在各服务目录内，不提供 docker-compose。

**验收**：双端构建/检查命令全部通过；按本文“验证方案”完成回归；文档中的命令可直接执行。

## 5. 验证方案

**后端**

```bash
cd server
go mod tidy && go mod verify
go build ./... && go vet ./... && go test ./...
```

单元测试重点：会话创建/续期/过期/删除、踢人与封禁、密码哈希、权限注册表匹配、菜单树、数据范围（无部门无岗位/仅部门/仅岗位/两者都有/全局记录/越权详情）、通用 CRUD、SSE 事件分发。

**前端**

```bash
cd web
npm run type-check && npm run test && npm run lint && npm run build
```

**手工 E2E**

1. admin 首次登录被强制改密；改密后重新登录正常。
2. 创建部门、岗位、角色并勾选菜单/按钮。
3. 用四类用户（仅部门、仅岗位、部门+岗位、都未设置）验证数据可见范围。
4. 岗位、字典、配置等标准 CRUD 走基类端点。
5. 在线会话页踢出用户，SSE 立即收到 `kick` 并退出。
6. 封禁用户立即下线且无法登录；解封后恢复。
7. 启动两个 server 实例（不同端口与 `instance_id`，共享 PostgreSQL/Redis/Kafka），验证通知广播、踢人和离线补拉。
8. 上传下载、发布通知、查看操作/登录日志。

## 6. 风险与依赖

1. **泛型 CRUD 与框架反射/IOC 的兼容性**：泛型实例化、`inject` 字段、自定义 `UnmarshalJSON` 与嵌套校验需在阶段 2 原型验证；不可行则退化为“泛型 Service + 薄 API 包装”。
2. **Kafka 广播语义**：每个实例唯一消费组才能收到全量事件，组数量随实例数增长；使用稳定 `instance_id`、短保留期，并依赖各节点 NTP 对齐（30s 容差）。
3. **Redis 为鉴权硬依赖**：不可用时登录/鉴权整体失败（fail-closed），需保证可用性、持久化与监控。
4. **数据权限“未设置即全部”**：用户表单必须明确提示，避免误配导致数据暴露。
5. **数据权限漏用**：所有业务列表/详情必须走 `scope` 辅助；通过通用 CRUD + 单元测试 + review checklist 控制。
6. **依赖版本**：只使用 hecc-blot 已发布 tag；需要的新 API 先升级模块，不在本项目用 `replace` 指向本地源码。私有仓库需配置 `GOPRIVATE=github.com/hecc-blot/*` 与访问凭据。
7. **只有 Get/Post**：RESTful 风格受限，全部写操作 POST。
8. **Schema 手工维护**：无 Go 迁移工具，`init.sql` 与模型必须同步修改；复杂约束用原生 SQL 补齐。
9. **前端 token 存储**：Bearer token 存 localStorage 存在 XSS 风险；首版接受，后续可改 HttpOnly Cookie + CSRF。
10. **SSE 连接上限**：框架硬编码 1000 并发连接，超出返回 503；大规模部署前需评估或改造。

## 7. 文档分工

- `README.md`：项目情况、目录、技术栈、功能范围、快速开始、文档索引。
- `server/README.md`：后端结构、配置、数据库、依赖、开发约定、检查命令。
- `web/README.md`：前端结构、运行、环境变量、布局、请求/会话、路由与权限、SSE。
- `PLAN.md`：开发阶段、任务、验收标准、风险；阶段完成后同步更新“当前进度”与对应阶段状态。
