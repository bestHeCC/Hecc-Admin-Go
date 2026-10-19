# Hecc-Admin-Go 通用管理后台实施计划

> **执行约定**：本文件仅用于方案 review。确认后再开始创建代码、配置或依赖文件。

## Context

在空目录 `D:/Code/Hecc-Admin-Go` 从零搭建一套通用管理后台：

- 后端 Go 1.26.1，通过 **go mod 直接引入 hecc-blot 已发布模块**（不使用本地源码），数据库 **PostgreSQL**，会话依赖 **Redis**，SSE 跨实例事件依赖 **Kafka**。
- 前端 Vue 3 + TypeScript + Vite + Pinia + Vue Router + **Element Plus**。
- 首版范围：会话登录、用户/角色/菜单/RBAC（按钮级）、部门/岗位、个人中心；字典/系统配置/操作日志/登录日志；文件上传下载、站内通知（SSE 实时推送）；在线会话管理与封禁踢人；**通用 CRUD 基类**。
- 不做：代码生成器、多租户、OAuth/SSO。

hecc-blot 已提供 IOC、HTTP 内核、PostgreSQL/GORM 封装、日志、Trace、缓存、限流、调度器、SSE、Kafka 生产/消费，但**没有**认证、RBAC、CORS、操作日志、配置加载、迁移工具。这些需要在本项目中自建。框架关键约束已确认：

- API 结构体依赖字段用 `inject:""` 且**必须放在匿名嵌入的请求结构体之前**。
- 路由只有 `Get`/`Post`（无 Put/Delete/Patch），因此所有写操作统一使用 POST。
- 响应恒为 HTTP 200 + `{code,message,data}`；业务码 60000+。
- `IDbModel` 要求 `GetID() int`；`WithContext(ctx)` 必须调用；链式方法返回副本。
- 分页统一 `util.NewPage` → `{list,page,pageSize,total}`。
- SSE 通过 `sse.NewSseSvc(apiHandle, container)` 复用同一端口；`Serve(ctx, w)` 只拿到 `context.Context`，认证信息需写入 **Request.Context**。
- `cache` 模块未暴露原始 `*redis.Client`，也不支持集合操作；会话存储需另建 go-redis 客户端（复用同一份 Redis 配置）。
- Kafka 消费者使用 Consumer Group；**同组会分摊分区**，要实现“每个实例都收到全部事件”，必须让每个实例使用唯一 GroupID。hecc-blot 的 `mq.kafka.start_offset` 支持 `first` / `last`，只在消费组尚无已提交 offset（首次建组）时生效；本方案配置 `last`，已有提交 offset 的组仍从提交位置续读。

## 技术决策

| 项 | 决策 |
|---|---|
| 仓库布局 | 只保留 `server/`（后端）与 `web/`（前端）两个目录；根目录放 `README.md`、`PLAN.md`、`.gitignore` |
| Go module | `github.com/hecc/hecc-admin-go`，`go.mod` 位于 `server/` |
| 依赖方式 | `go.mod` 直接 require 已发布的 hecc-blot 模块，不使用 `replace` / `go.work`：`core v0.4.0`、`framework v0.4.0`、`db v0.1.6`、`cache v0.2.0`、`trace v0.1.4`、`ratelimit v0.1.4`、`scheduler v0.1.2`、`mq v0.1.5`、`sse v0.4.0`（以 `go mod tidy` 解析结果为准） |
| 后端分层 | 参考 hecc-blot framework：`config/`、`contract/`、`entity/`、`enum/`、`service/`、`util/`，外加应用层 `api/`、`model/`、`middleware/`、`crud/`、`sse/`、`bootstrap/`、`migrate/` |
| 构建 | 标准 `go build ./...`；发布前 `go mod tidy && go mod verify`。模块为私有仓库，需已配置 `GOPRIVATE=github.com/hecc-blot/*` 与访问凭据 |
| 关键第三方依赖 | `spf13/viper`、`google/uuid`、`golang.org/x/crypto`（bcrypt）、`redis/go-redis/v9`（会话存储）、`stretchr/testify`（测试） |
| 配置 | viper 读取 `server/configs/config.yaml`，支持 `HECC_` 前缀环境变量覆盖；结构体复用 hecc-blot 的 `mapstructure` 配置 |
| **认证** | **不用 JWT**。Redis 服务端会话：32 字节随机 token，服务端只存 SHA-256 键；滑动空闲过期 + 绝对过期；删除会话即时失效 |
| **Redis** | **必需**：会话、登录限流、用户上下文/权限缓存、在线会话索引 |
| **Kafka** | 用于 SSE 跨实例事件广播（notice/unread/kick）；每个实例唯一消费组；`mq.kafka.start_offset: last`，新组从最新位置开始 |
| **数据权限** | 角色只控制菜单/按钮；业务数据由当前用户的**部门/岗位**自动决定可见范围；系统元数据不做行级隔离，仅权限控制 |
| 强制改密 | `sys_user.must_change_password`；种子 admin 为 true，改密成功后才解除接口限制 |
| **通用 CRUD** | Go 泛型基类 + 请求 DTO 接口；新增模型只需“模型 + DTO + 一行注册”，不再手写 CRUD Handler/Service |
| ID | `BIGSERIAL`/`int64`（满足 `GetID() int`），JSON number；软删除用 `gorm.DeletedAt` |
| 迁移 | 独立 `cmd/migrate`：AutoMigrate + 原生 SQL 建部分唯一索引 + 幂等种子数据 |
| 前端请求 | axios，统一响应拦截；业务码 40003（会话失效）直接清理登录态，无 refresh 流程 |
| 分页契约 | 请求 `page/pageSize`，响应 `list/page/pageSize/total` |
| 文件存储 | `Storage` 接口 + 本地驱动（`server/storage/uploads/YYYY/MM/uuid.ext`），预留 OSS 实现 |
| 通知推送 | hecc-blot SSE（同端口）+ Kafka 事件广播（跨实例） |
| 运行 | **不使用 docker-compose**；`server/` 与 `web/` 分别独立运行；本地需自备 PostgreSQL、Redis、Kafka |

## 目录结构

```
Hecc-Admin-Go/
├── PLAN.md
├── README.md
├── Makefile                      # 聚合并发启动、构建、迁移、测试
├── .gitignore
├── server/                       # 后端（唯一后端目录）
│   ├── README.md
│   ├── go.mod / go.sum           # 直接依赖已发布的 hecc-blot 模块
│   ├── Dockerfile / .dockerignore        # 可选，不使用 compose
│   ├── .env.example
│   ├── configs/{config.example.yaml, config.yaml(gitignore)}
│   ├── scripts/{init.sql, create-topics.sh}  # 手工初始化 PostgreSQL/Redis/Kafka
│   ├── cmd/
│   │   ├── server/main.go
│   │   └── migrate/main.go
│   ├── config/                   # 配置结构体 + viper 加载（对应 framework/config）
│   ├── contract/                 # 接口契约（对应 framework/contract）
│   ├── entity/                   # API 请求/响应 DTO（对应 framework/entity）
│   ├── enum/                     # 错误码/状态/常量（对应 framework/enum）
│   ├── service/                  # 业务实现（对应 framework/service）
│   │   ├── auth/ user/ role/ menu/ dept/ post/ dict/
│   │   ├── sysconfig/ monitor/ file/ notice/
│   │   └── session/ permission/ storage/
│   ├── api/                      # API 结构体（按领域子包）
│   ├── model/                    # GORM 模型，统一 sys_ 前缀
│   ├── middleware/               # session / permission / cors / accesslog / operlog
│   ├── crud/                     # ★ 通用 CRUD 基类（泛型 Service + 通用 API + 注册器）
│   ├── sse/                      # NoticeSse + 本地连接表 + Kafka 广播消费者
│   ├── bootstrap/                # 依赖装配与路由注册
│   ├── migrate/                  # 迁移、索引、种子数据
│   ├── util/                     # password/tree/scope/route/page 等纯工具
│   └── storage/                  # 运行期上传目录，gitignore
└── web/                          # 前端（唯一前端目录）
    ├── README.md
    ├── package.json / vite.config.ts / tsconfig*.json
    ├── Dockerfile / .dockerignore        # 可选，不使用 compose
    ├── .env.development / .env.production
    └── src/
        ├── layout/
        │   ├── BlankLayout.vue   # 登录/强制改密/404 等无侧边栏页面
        │   ├── DefaultLayout.vue # 业务页面主布局
        │   └── components/       # Sidebar / Navbar / Breadcrumb / NoticeBell
        ├── api/ components/ directives/ router/ stores/ utils/ views/
        ├── App.vue
        └── main.ts
```

### 后端目录分层说明（对齐 framework）

| server 目录 | 对应 framework 概念 | 内容 |
|---|---|---|
| `config/` | `framework/config` | App 配置结构体、viper 加载与校验 |
| `contract/` | `framework/contract` | `IAuthService`、`ISessionStore`、`IStorage`、`IPermissionService` 等接口 |
| `entity/` | `framework/entity` | API 请求/响应 DTO，一个领域一个文件 |
| `enum/` | `framework/enum` | 业务错误码、状态枚举、常量 |
| `service/` | `framework/service` | 接口实现，按领域分子包 |
| `util/` | `framework/util` | 无状态工具：password/tree/scope/route/page |
| `api/` | 应用层 | hecc-blot API 结构体（`inject` 字段在前，DTO 在后） |
| `model/` | 应用层 | GORM 模型 |
| `middleware/` | 应用层 | 会话、权限、CORS、访问/操作日志 |
| `crud/` | 应用层 | 泛型 CRUD 基类与注册器 |
| `sse/` | 应用层 | SSE 端点、本地连接表、Kafka 消费者 |
| `bootstrap/` | 应用层 | 依赖装配与路由注册 |
| `migrate/` | 应用层 | 建表、索引、种子 |

## 后端设计

### 1. 启动与装配顺序（`server/cmd/server/main.go`）

1. viper 加载配置，组合 `server.Config`、`db.Config`、`cache.Config`、`mq.Config`、`trace.Config`、`log.LocalConfig` 与 App 自有配置（Session、上传、CORS、SSE）。
2. 初始化 Logger（必须最先）。
3. 初始化 Trace（必须早于 DB/Cache/MQ）。
4. `db.NewPostgres(...)` 得到 `dbContract.IDb`；`cache.NewCacheFactory(...)`。
5. 用同一份 Redis 配置创建 go-redis 客户端，构造 SessionStore、用户上下文缓存（启动时 Ping 失败即退出）。
6. `mq.NewMqFactory(&cfg.Mq, logSvc, traceSvc)` 创建 Kafka 生产者；配置 `admin.events` 主题。
7. 构造通用 CRUD 服务、领域 Service、权限服务、通知 Hub、路由注册表，注册到 IOC 容器。
8. `httpSvc.NewApiSvc(&cfg.Server, container)`；**先** `SetResponseSvc`（使用带审计码捕获的包装实现）。
9. 全局中间件：trace、CORS、access log。
10. 公共路由组（login）；受保护路由组 `admin`（session + permission + operlog）。
11. 用自定义 `Registrar` 注册全部 API 路由，同时登记 `path -> {permission, module, action}` 元数据。
12. `sse.NewSseSvc(apiHandle, container)`；在 `admin` 组注册 `GET /admin/notice/stream`。
13. 用 hecc-blot `mq.NewConsumerHandle` 启动 Kafka 广播消费者（每实例稳定唯一 GroupID，配置 `mq.kafka.start_offset: last`），收到事件后分发到本机 SSE 连接。
14. 注册 `/health`、静态 `/uploads/*filepath`、可选 `/metrics`。
15. 注册 shutdown hooks（SSE、Kafka 消费者、scheduler），`Listen()`。
16. `cmd/migrate/main.go` 复用配置加载与 DB 初始化，执行迁移后退出。

### 2. 数据模型（`server/model`）

所有表显式 `TableName()`；时间统一 `CreatedAt/UpdatedAt`；业务实体带 `DeletedAt gorm.DeletedAt`。

| 表 | 关键字段 | 索引/说明 |
|---|---|---|
| `sys_user` | id, username, password_hash, nickname, email, phone, avatar, **dept_id**, status, is_super, **must_change_password**, **banned_until**, **ban_reason**, failed_attempts, locked_until, last_login_at/ip, remark | 部分唯一索引 `(username) WHERE deleted_at IS NULL`；dept_id 索引 |
| `sys_post` | id, code, name, sort, status, remark | 唯一 `code`；岗位/职位 |
| `sys_user_post` | user_id, post_id | 复合主键；`(post_id)` 索引 |
| `sys_role` | id, code, name, sort, status, remark | 部分唯一 `(code) WHERE deleted_at IS NULL`；无 data_scope |
| `sys_menu` | id, parent_id, name, type(dir/menu/button), path, component, permission, icon, sort, visible, status | permission 建索引；按钮也是树节点 |
| `sys_user_role` | user_id, role_id | 复合主键 |
| `sys_role_menu` | role_id, menu_id | 复合主键 |
| `sys_dept` | id, parent_id, ancestors, name, leader, phone, email, sort, status | ancestors 形如 `0,1,3` |
| `sys_dict_type` | id, name, type, status, remark | 唯一 `type` |
| `sys_dict_item` | id, type_code, label, value, sort, tag_type, status, remark | `(type_code,value)` 唯一 |
| `sys_config` | id, name, key, value, type, remark | 唯一 `key` |
| `sys_oper_log` | id, user_id, username, **dept_id, post_id**, module, action, method, path, ip, ua, code, duration_ms, created_at | `(created_at)`,`(user_id)`；不软删 |
| `sys_login_log` | id, username, **dept_id, post_id**, ip, ua, status, message, created_at | `(created_at)`,`(username)` |
| `sys_file` | id, original_name, object_key, url, size, mime, storage, uploader_id, **dept_id, post_id**, created_at, deleted_at | `(uploader_id)` |
| `sys_notice` | id, title, content, type, target_type, status, sender_id, **dept_id, post_id**, published_at, created_at, updated_at | |
| `sys_notice_receiver` | id, notice_id, user_id, read_at | `(user_id,read_at)`,`(notice_id,user_id)` 唯一 |

- **不建 refresh token 表**；会话全部在 Redis。
- 业务表统一嵌入 `DataOwner{DeptID, PostID}`；写入时由当前会话用户填充，未归属的记录视为全局数据。
- 关系使用逻辑外键，JOIN 通过 `IDb.GetInstance().(*gorm.DB)` 完成。
- 所有模型实现 `GetID() int { return int(m.ID) }`。
- 字典/配置可加 5 分钟本地缓存，写操作后主动失效。

### 3. 会话认证（无 JWT）

**会话模型**

- 登录成功后生成 32 字节随机 token（base64url），前端通过 `Authorization: Bearer <token>` 携带；服务端只保存 `sha256(token)` 作为 Redis 键。
- Redis 键布局：
  - `admin:session:{hash}`：Hash，字段 `userID/sessionID/username/loginIP/userAgent/loginAt/absoluteExpireAt`；TTL = 空闲超时（默认 2h）。
  - `admin:user:sessions:{userID}`：Set，保存用户所有会话 hash，用于“踢出该用户全部会话”。
  - `admin:sessions:active`：ZSet，score = 最近活跃时间，用于在线会话分页列表。
- 每次请求：`EXPIRE session idleTTL` + `ZADD sessions:active now`（可按 60s 节流）；同时校验 `absoluteExpireAt`（默认 12h，可配）。
- 登录策略：`session.max_per_user` 可配；默认 0（不限制），设置为 1 时新登录踢掉旧会话。登录成功写入 `sys_login_log`。
- 密码规则：bcrypt；失败 5 次锁定 15 分钟（`failed_attempts/locked_until`），并用 Redis 计数做 IP/用户名登录限流（10 次/分钟）。

**封禁、踢下线、黑名单**

- **踢下线**：删除指定会话（`DEL session` + `SREM user:sessions`），并通过 Kafka 发布 `kick` 事件；该用户的 SSE 连接立即收到并关闭，前端清理登录态。
- **封禁账号**：`status=0`（永久）或 `banned_until`（临时），写入 `ban_reason`；同时删除该用户全部会话并发布 `kick`。登录时校验状态与 `banned_until`。
- **黑名单**：服务端会话模式下无需独立 token 黑名单——**删除会话即拉黑**；续期/重放都不存在。管理员禁用账号或踢人即可达到黑名单效果。
- **改密/重置密码**：删除该用户全部会话（当前改密请求会轮换 token）；管理员重置后置 `must_change_password=true`。
- **在线会话管理**：`/admin/monitor/online/page` 分页查看 userID、登录 IP、UA、登录时间、最近活跃；`kick` / `kick-all` 执行踢出。
- **个人设备**：`/admin/auth/sessions` 查看自己的会话，支持踢出其他设备。

**强制首次改密**

- 种子 admin `must_change_password=true`；管理员重置他人密码后同样置 true。
- 登录响应与 `/admin/auth/info` 返回 `mustChangePassword`。
- 该标志为 true 时，session 中间件只放行：`/admin/auth/info`、`/admin/auth/password`、`/admin/auth/logout`；其余接口返回 60010 `password change required`。
- 改密成功：更新 hash、清除标志、删除该用户其他会话、**轮换当前 token**（返回新 token），前端替换后重新拉取 info。
- 前端守卫强制跳转独立改密页。

**用户上下文与权限缓存**

- 每次请求先查 Redis 会话，得到 userID；再加载用户上下文：`{user, deptIDs(含下级), postIDs, permissions}`。
- 缓存键 `admin:ctx:{globalVersion}:{userID}`，TTL 5 分钟；全局版本 `admin:ctx:version` 在用户/部门/岗位/角色/菜单发生变更时 `INCR`，旧键自然过期。
- 权限码 = 所有启用角色的菜单/按钮权限并集；`is_super` 直接放行。
- 会话本身是登录态唯一来源；封禁/踢人通过删除会话即时生效。

### 4. RBAC 与按钮级权限

- `sys_menu.type`：`dir`（目录）、`menu`（路由页面）、`button`（仅权限码，作为菜单子节点）。
- 角色授权界面展示完整菜单树（含按钮节点）；勾选按钮即授予对应权限码。
- 权限码示例：`system:user:list|add|edit|remove|resetPwd|assignRole|assignPost|ban|kick`、`system:post:*`、`system:role:*`、`system:menu:*`、`system:dept:*`、`system:dict:*`、`system:config:*`、`monitor:operlog:*`、`monitor:loginlog:*`、`monitor:online:*`、`file:*`、`notice:*`。
- 后端：路由注册器记录 `ctx.FullPath() -> {Permission, Module, Action}`；permission 中间件查表校验；未登记的路由视为“仅需登录”。
- 前端：`/admin/auth/info` 返回 `permissions: string[]` 与菜单树；`v-hasPerm="'system:user:add'"` 控制按钮显隐；后端仍做最终校验（前端隐藏不是安全边界）。
- 角色只控制菜单/按钮，不承担数据范围配置。

### 5. 数据权限（部门 / 岗位）

**范围来源**

- 当前用户的 `dept_id`（单部门）与 `sys_user_post` 中的岗位集合。
- 规则：
  | 用户配置 | 可见数据 |
  |---|---|
  | `is_super` | 全部 |
  | 未设置部门且未设置岗位 | **全部数据** |
  | 仅设置部门 | 本部门及下级部门的数据 + 无归属的全局数据 |
  | 仅设置岗位 | 本岗位的数据 + 无归属的全局数据 |
  | 同时设置部门与岗位 | 部门范围 ∪ 岗位范围 + 无归属的全局数据 |

- “无归属”指记录的 `dept_id` 与 `post_id` 都为空；这类公共数据对有模块权限的用户可见。
- 部门范围默认包含下级部门（用 `sys_dept.ancestors` 计算）；如需仅本部门，后续可加配置。

**作用对象**

- **受数据权限约束（业务数据）**：用户、部门树、文件、通知、操作日志、登录日志。
- **不受数据权限约束（系统元数据）**：角色、菜单、字典、系统配置、岗位。这些数据**只受菜单/按钮权限控制**：授予权限即可看全部，未授予权限即不可见。
- 用户列表按用户自身的 `dept_id` + `user_post` 过滤；日志/文件/通知按记录上的 `dept_id/post_id` 过滤。

**实现**

- `server/util/scope` 提供：
  ```go
  type Scope struct { All bool; DeptIDs []int64; PostIDs []int64 }
  func Resolve(ctx, userCtx) Scope
  func (s Scope) Apply(db dbContract.IDb) dbContract.IDb       // 业务表：dept_id IN ? OR post_id IN ? ...
  func (s Scope) ApplyUser(db dbContract.IDb) dbContract.IDb   // 用户表需联表 user_post
  ```
- 业务 Service 的列表/详情查询统一调用 scope 辅助；详情按 ID 查询后再校验是否在范围内，越权返回 40005（NoDataPermission）。
- 创建业务数据时由 Service 自动写入当前用户的 `dept_id/post_id`；管理端表单不暴露这两个字段。
- 用户表单：部门树选择 + 岗位多选；页面提示“未设置部门/岗位时可见全部数据”，避免误配。
- 单元测试覆盖：无部门无岗位、仅部门、仅岗位、两者都有、全局记录、越权详情。

### 6. 通用 CRUD 基类（回答“像 PHP 基类一样自动 CRUD”）

Go 没有继承，用 **泛型 + 组合** 实现等价能力。目标：新增一个模型时，只写模型、DTO、注册，不写 CRUD Handler/Service。

**分层**

- `server/crud/model.go`
  ```go
  type Model interface {
      dbContract.IDbModel
      TableName() string
  }
  ```
- `server/crud/service.go`：`Service[T Model]`
  - 通用 `Create/Get/Update/Delete/Page`；
  - 基于 `dbContract.IDb`（必要时用 `GetInstance().(*gorm.DB)` 处理联表/批量）；
  - 支持 `Config[T]`：资源名、权限前缀、模块名、软删除、数据权限函数、钩子；
  - 钩子：`BeforeCreate/AfterCreate/BeforeUpdate/AfterUpdate/BeforeDelete`；
  - 数据权限：业务模型配置 `Scope: scope.Apply`，系统元数据留空。
- `server/crud/api.go`：通用 API 结构体（全部实现 `Call`）
  - `PageApi[T, R]`、`GetApi[T]`、`CreateApi[T]`、`UpdateApi[T]`、`DeleteApi[T]`；
  - 请求 DTO 以 `Req R` 命名字段持有；通过自定义 `UnmarshalJSON` 让 JSON body 保持扁平（gin 的 `ShouldBind` 会调用它）；
  - 校验仍由 `binding` 标签完成；validator 对嵌套结构返回叶子字段名，`GetMessages` 的 key 仍是 `Field.tag`。
- `server/crud/register.go`：`Register[T](registrar, container, cfg, routes)`，自动注册标准端点与权限码：
  - `POST {resource}/page` → `{prefix}:list`
  - `POST {resource}/get` → `{prefix}:query`
  - `POST {resource}/create` → `{prefix}:add`
  - `POST {resource}/update` → `{prefix}:edit`
  - `POST {resource}/delete` → `{prefix}:remove`
  - API 实例形如 `&crud.PageApi[model.User, entity.UserPageReq]{}`；服务实例以 `crud.IService[model.User]` 注册进 IOC，由基类 `inject` 获取（每请求新实例也能拿到依赖）。

**请求 DTO 约定（每个模型只需这一小部分）**

```go
// 分页/筛选
type UserPageReq struct {
    crud.PageRequest
    Keyword string `json:"keyword" form:"keyword"`
    Status  *int   `json:"status" form:"status"`
}
func (r UserPageReq) Paging() (page, size int) { return r.Page, r.PageSize }
func (r UserPageReq) Build(ctx context.Context, db dbContract.IDb) dbContract.IDb { /* 模型专属筛选 */ }

// 创建
type UserCreateReq struct {
    Username string `json:"username" binding:"required,min=3,max=32"`
    // ...
}
func (r UserCreateReq) ToModel(ctx context.Context) *model.User { /* 字段映射 + 密码哈希 */ }

// 更新
type UserUpdateReq struct {
    ID       int64  `json:"id" binding:"required"`
    Nickname string `json:"nickname" binding:"required"`
    // ...
}
func (r UserUpdateReq) GetID() int64 { return r.ID }
func (r UserUpdateReq) Apply(existing *model.User) error { /* 覆盖允许更新的字段 */ }
```

**每个新模型的接入成本**

```go
// 1. 定义模型（TableName/GetID/字段）
// 2. 定义 3 个 DTO（分页/创建/更新，按需）
// 3. 一行注册
crud.Register[model.Post](reg, container, crud.Config[model.Post]{
    Resource:  "system/post",
    PermPrefix: "system:post",
    Module:    "岗位管理",
}, crud.Routes[model.Post, entity.PostPageReq, entity.PostCreateReq, entity.PostUpdateReq]{
    Page:   &crud.PageApi[model.Post, entity.PostPageReq]{},
    Create: &crud.CreateApi[model.Post, entity.PostCreateReq]{},
    Update: &crud.UpdateApi[model.Post, entity.PostUpdateReq]{},
    // Get/Delete 使用默认实例
})
// 4. 如有特殊动作（分配角色、重置密码、封禁、树形接口），再写少量自定义 API
```

**边界与说明**

- 自动 CRUD 覆盖**单表标准增删改查**；树形菜单/部门、分配关系、封禁、重置密码、上传、通知发布等继续用自定义 API。
- 不采用“反射+结构体标签全自动生成”，因为会牺牲字段白名单、校验、数据权限和可读性；泛型基类是可维护性与效率的平衡点。
- 首次实施时先做一个 `Post` 模型作为**泛型 CRUD 原型**，验证 hecc-blot 的 IOC/反射/绑定/校验兼容性，再批量接入其他模型。
- 标准权限码由注册器统一登记；种子菜单需包含对应按钮节点（后续可加 `migrate -sync-perms` 从注册表同步按钮，首版先手工种子）。

### 7. 中间件与审计

- `CorsMiddleware`：处理 OPTIONS 预检（`AbortWithStatus(204)`）；生产走 nginx 同源。
- `SessionMiddleware`：解析 Bearer → SHA-256 → 读 Redis 会话 → 滑动续期 → 校验绝对过期/用户状态/改密标志 → 加载用户上下文；将 `userID/sessionID` 写入 `IContext`，并 `ctx.SetRequestContext(context.WithValue(...))` 供 SSE 读取；失败返回 40003 并 `Abort`。
- `PermissionMiddleware`：查路由注册表 → 校验权限；superadmin 放行。
- `AccessLogMiddleware`：记录 method/path/IP/耗时/用户，使用 zap 字段。
- `OperLogMiddleware`：对受保护 POST 写 `sys_oper_log`；用**自定义 IResponse 包装器**在渲染时捕获最终 `code` 存入 ctx，中间件在 `Next()` 后读取；写入操作者 `dept_id/post_id` 供数据权限过滤。
- 登录日志由 AuthService 在登录成功/失败时写入（含登录者当前部门/岗位）。

### 8. API 约定与主要端点

- 查询用 GET，写操作一律 POST。
- 请求结构体同时标注 `json` 与 `form` 标签；自定义文案用 `GetMessages()`。
- 自动 CRUD 的 POST DTO 由泛型基类通过自定义 `UnmarshalJSON` 扁平绑定；GET/Delete 使用通用 `IDRequest`。

| 分组 | 端点 |
|---|---|
| 公共 | `POST /admin/auth/login`、`GET /health` |
| 认证 | `POST /admin/auth/logout`、`GET /admin/auth/info`、`GET /admin/auth/menus`、`GET /admin/auth/profile`、`POST /admin/auth/profile/update`、`POST /admin/auth/password`、`GET /admin/auth/sessions`、`POST /admin/auth/sessions/kick` |
| 用户 | 自动 CRUD：`page|get|create|update|delete`；自定义：`reset-password|assign-roles|assign-posts|status`（含封禁/解封） |
| 角色 | 自动 CRUD + `assign-menus|status` |
| 菜单 | 树形接口 + CRUD（菜单树需自定义 tree） |
| 部门 | 树形接口 + CRUD（部门树需自定义 tree） |
| 岗位 | 自动 CRUD + `status` |
| 字典 | 类型/数据项 CRUD + `GET items?type=` |
| 配置 | 自动 CRUD + `GET value?key=` |
| 日志 | `POST /admin/monitor/oper-log/page|delete|clean`、`POST /admin/monitor/login-log/page|delete|clean` |
| 在线会话 | `POST /admin/monitor/online/page`、`POST /admin/monitor/online/kick`、`POST /admin/monitor/online/kick-all` |
| 文件 | `POST /admin/file/upload`、`POST /admin/file/page|delete`、`GET /admin/file/download?id=` |
| 通知 | `POST /admin/notice/page|create|update|publish|delete`、`POST /admin/notice/mine/page`、`POST /admin/notice/mine/read`、`GET /admin/notice/mine/unread-count`、**`GET /admin/notice/stream`（SSE）** |
| 仪表盘 | `GET /admin/dashboard/stats` |

### 9. 文件与通知

**文件上传**

- 上传：API 请求结构体嵌入 `*multipart.FileHeader form:"file" binding:"required"`；校验大小（默认 10MB）与扩展名/MIME 嗅探；UUID 文件名，禁止路径穿越。
- `Storage` 接口：`Save/Open/Delete`；本地实现写入 `server/storage/uploads/YYYY/MM/`，URL 为 `/uploads/...`；后续 OSS 实现只需新增驱动。
- 公共静态文件通过 `apiHandle.Handle(GET, "/uploads/*filepath", http.StripPrefix(...))` 提供；下载接口经鉴权后流式返回，必要时把 `*httpSvc.Context` 类型断言集中在 `server/service/storage` 一处。

**通知 + SSE（Kafka 跨实例广播）**

- `sse.NewSseSvc(apiHandle, container)` 复用 HTTP 端口；注册 `GET /admin/notice/stream` 到 `admin` 组。
- 认证：SessionMiddleware 把用户/会话写入 Request.Context，`NoticeSse.Serve` 从中读取。
- 事件流：`init`（未读数+最近 10 条未读）→ `notice` / `unread` / `kick` / `shutdown`。
- Kafka：
  - Topic `admin.events`，消息 `{id,type,userIDs,sessionID,payload,ts}`，JSON；Key 用 userID，保证同一用户事件分区有序。
  - 生产者使用 hecc-blot `mq` 的 Kafka Producer（RequiredAcks=all）。
  - 每个 server 实例使用**稳定的唯一消费组** `admin-sse-{instanceID}`（hostname/pod 名/环境变量），保证每个实例都能收到全量事件（不是同组分摊），重启后沿用已提交 offset。
  - 配置 `mq.kafka.start_offset: last`：新消费组从最新位置开始；已有提交 offset 的组仍从提交位置续读，不会重置。
  - 事件体包含 `ts` 作为兜底：消费端丢弃 `ts < 进程启动时间 - 30s` 的消息，避免异常情况下回放旧事件；Topic 保留期设为 1 天。
  - 直接使用 hecc-blot `mq.NewConsumerHandle`，无需自建 Kafka reader。
  - 消费失败只记录日志，不影响通知入库；离线/断线用户由重连后的 `init` 补未读。事件带 `id`，前端按 id 去重。
- 发布通知：事务内写 `sys_notice` + fan-out `sys_notice_receiver`（`CreateInBatches`），随后发送 Kafka 事件；Kafka 不可用时记录告警，不阻塞发布。
- 前端使用 `@microsoft/fetch-event-source`（原生 `EventSource` 不能带 `Authorization` 头），自动重连，登出/切页 abort；收到 `kick` 立即清理登录态。
- 框架 SSE 并发连接上限硬编码 1000；超出返回 503。

**后台任务**

- 用 hecc-blot scheduler 注册每日清理任务（过期会话索引、过期日志、孤立文件记录），在 shutdown hook 中 `Stop()`。

### 10. 前端设计（`web/`）

```
web/src/
├── api/                # 与后端领域一一对应的请求函数
├── components/         # DictTag、TreeSelect、PostSelect、TableToolbar、Pagination 等
├── directives/         # v-hasPerm、v-hasRole
├── layout/             # BlankLayout.vue + DefaultLayout.vue + components/
├── router/             # index.ts、guard.ts、dynamic.ts
├── stores/             # user、permission、app、dict、notice
├── utils/              # request.ts、auth.ts、tree.ts、sse.ts
├── views/              # login、change-password、dashboard、system/*、monitor/*、file、notice、profile、error
├── App.vue / main.ts
```

- Vite：`@` → `src`；dev proxy `/api` → `http://127.0.0.1:8080`（重写去掉 `/api`）。
- Element Plus：`unplugin-auto-import` + `unplugin-vue-components` 按需引入，图标自动注册，`zh-cn` locale，支持暗色主题变量。
- `utils/request.ts`：附加 Bearer；响应体 `code===10000` 直接返回 `data`；`40003` 清理会话并跳登录（**无 refresh 流程**）；40002 展示校验信息；其他 `ElMessage.error(message)`。
- Pinia `user` store 持久化会话 token 与过期提示；`permission` store 保存菜单树/权限码；`dict` store 按类型缓存字典；`notice` store 保存未读数与 SSE 连接状态。
- 布局模板：
  - `BlankLayout.vue`：无侧边栏/导航栏，承载登录、强制改密、404/403 等独立页面。
  - `DefaultLayout.vue`：业务页面主布局，包含 Sidebar、Navbar、Breadcrumb、NoticeBell、AppMain，内部使用 `<router-view />`。
  - `layout/components/` 放 Sidebar/Navbar/Breadcrumb/NoticeBell 等子组件。
- 动态路由：登录后拉 `info` + `menus`，将后端 `component` 字符串通过 `import.meta.glob('../views/**/*.vue')` 映射为懒加载组件，`router.addRoute` 作为 `DefaultLayout` 的子路由挂载，最后追加 404 兜底。
- 强制改密：登录响应或守卫发现 `mustChangePassword=true` → 跳独立改密页并阻止进入业务路由；改密成功后替换后端返回的新 token，重新拉 info。
- SSE：登录成功后建立连接；收到 `kick` 立即清理登录态并提示“已被下线”；登出时 abort。
- 页面：登录、强制改密、仪表盘、用户（部门树选择 + 岗位多选 + 角色分配 + 封禁）、角色（菜单树含按钮授权）、菜单树表、部门树表、岗位管理、字典类型/数据、系统配置、操作日志、登录日志、文件管理、在线会话（踢人）、通知发布/我的通知、个人中心（资料/改密/我的设备）。
- 数据权限自动生效，页面不提供数据范围配置；用户表单提示“未设置部门/岗位时可见全部数据”。
- 按钮级权限使用 `v-hasPerm`；无权限菜单不渲染、路由不可达。
- 校验/格式：ESLint + Prettier + `vue-tsc`；不引入 Tailwind。

## 本地运行与构建（不使用 docker-compose）

项目只保留 `server/` 与 `web/` 两个目录，基础设施（PostgreSQL / Redis / Kafka）由开发者自行启动和配置，不提供 compose。

- 前置依赖：Go 1.26.1、Node 24、PostgreSQL 16+、Redis 7+、Kafka 3.x。
- 后端：
  - 配置：复制 `server/configs/config.example.yaml` 为 `config.yaml`，填写数据库/Redis/Kafka 地址；或使用 `HECC_` 环境变量覆盖。
  - 建表与种子：`cd server && go run ./cmd/migrate`
  - 启动：`cd server && go run ./cmd/server`
  - Kafka 主题：执行 `server/scripts/create-topics.sh`（创建 `admin.events`，设置 1 天保留期；也可手工用 `kafka-topics.sh` 创建）。
- 前端：
  - `cd web && npm install && npm run dev`
  - 开发代理 `/api` → `http://127.0.0.1:8080`。
  - 生产构建：`npm run build`，产物由任意静态服务器托管；反向代理需为 SSE 关闭缓冲（`proxy_buffering off`、足够长的 `proxy_read_timeout`）。
- 依赖策略：Redis 为鉴权硬依赖（启动 Ping 失败退出）；Kafka 不可用时服务仍可启动，实时通知降级为离线补拉，`/health` 暴露状态。
- 配置与忽略：提交 `server/configs/config.example.yaml`、`server/.env.example`、`web/.env.example`；`config.yaml`、`.env`、`server/storage/` 加入 `.gitignore`。
- Dockerfile 可选地放在 `server/` 与 `web/` 内部；不使用 docker-compose，也不设独立部署目录。
- Makefile：`dev-server`、`dev-web`、`migrate`、`test`、`lint`、`build`。

## 实施阶段（按依赖顺序）

1. **仓库与运行骨架**：仅 `server/`、`web/` 两个目录；`go mod init` + 引入已发布 hecc-blot 模块、配置加载、日志/Trace/DB/Redis 连通、Kafka 工厂、`/health`、Makefile、.gitignore、README。里程碑：`cd server && go run ./cmd/server` 返回 `{code:10000}`。
2. **数据层 + CRUD 原型**：全部模型（岗位、user_post、DataOwner）、`cmd/migrate`、索引、幂等种子；先实现 `crud` 并以 `Post` 为原型验证泛型 API + IOC + 扁平绑定 + 校验。里程碑：一条命令建表+种子；岗位 CRUD 全部由基类完成。
3. **会话认证与 RBAC**：Redis SessionStore、登录/登出、滑动续期、强制改密、封禁/踢下线、用户上下文缓存、路由权限注册表与按钮级校验、`info/menus`、在线会话接口。里程碑：登录→强制改密→访问→越权被拒→踢下线→封禁后无法登录。
4. **数据权限与核心 CRUD**：scope 解析/条件构造、用户/角色/菜单/部门 CRUD（标准部分走基类）、数据范围应用、操作/登录日志。里程碑：不同部门/岗位配置的用户看到的数据集合符合规则，越权详情被拒。
5. **扩展模块 + SSE/Kafka**：字典、系统配置、文件上传/下载、通知；`admin.events` 生产与每实例唯一组消费（事件 `ts` 过滤历史消息）；SSE 的 init/notice/unread/kick。里程碑：两个 server 实例下均能收到通知与踢人事件，重启后不重复推送旧事件，离线重连补未读。
6. **前端骨架**：Vite/Element Plus、request 封装（无 refresh）、`BlankLayout.vue` / `DefaultLayout.vue`、登录页、强制改密页、动态路由、权限指令、SSE 客户端、仪表盘。里程碑：菜单/按钮权限正确，铃铛实时更新，被踢自动退出。
7. **前端业务页**：按模块完成列表/表单/弹窗/树授权，部门/岗位/字典/权限接入。里程碑：全部功能端到端可用。
8. **交付**：seed 校验、单元测试、README（架构、配置、默认账号、数据权限规则、Kafka 消费组说明、Redis 运维）、最终构建验证；Dockerfile 可选，不提供 compose。

## 验证方案

- 后端：`go mod tidy && go mod verify && go build ./... && go vet ./... && go test ./...`。
- 单元测试：会话创建/续期/过期/删除、踢人与封禁、密码哈希、权限注册表匹配、菜单树、数据范围 SQL（无部门无岗位/仅部门/仅岗位/两者都有/全局记录/越权详情）、泛型 CRUD 的 Create/Update/Page/Delete、SSE 事件分发。
- 手工 E2E：
  - admin 首次登录被强制改密；
  - 创建部门、岗位；创建角色并勾选菜单/按钮；
  - A（仅部门）、B（仅岗位）、C（部门+岗位）、D（都不设置）四类用户验证数据可见范围；
  - 岗位、字典、配置等标准 CRUD 验证基类端点；
  - 在线会话页踢出 A，A 的 SSE 立即收到 kick 并退出；
  - 封禁 B，B 立即下线且无法再登录；解封后可登录；
  - 启动两个 server 实例，验证 Kafka 广播：任一实例发布通知，两个实例上的用户都能收到；
  - 上传下载、发布通知、查看操作/登录日志。
- 前端：`npm run type-check && npm run build`；dev 模式走通上述流程。
- 多实例：本地启动两个 server 进程（不同端口、不同 `instanceID`，连接同一 PostgreSQL/Redis/Kafka），验证 Kafka 广播、踢人和 SSE 重连。
- 默认账号：`admin / Admin@123456`，首次登录强制改密。

## 风险与待确认

1. **泛型 CRUD 与 hecc-blot 反射/IOC 的兼容性**：泛型实例化后的具体类型、命名 `Req` 字段、自定义 `UnmarshalJSON`、嵌套校验需要阶段 2 原型验证；若不可行，退化为“泛型 Service + 每个模型 1 个薄 API 包装（Call 内一行委托）”。
2. **Kafka 广播语义**：每个实例唯一消费组才能收到全量事件，组数量会随实例数/历史实例增长；使用稳定 instanceID、主题短保留期，并在 README 说明。`start_offset: last` 让新组从最新位置开始；事件 `ts` 过滤作为兜底，依赖各节点时钟基本同步（NTP），允许 30s 容差。
3. **Redis 为鉴权硬依赖**：不可用则所有登录/鉴权失败（fail-closed），需 healthcheck、持久化、监控。
4. **数据权限“未设置即全部”**：按确认的规则实现；用户表单必须明显提示，避免误配。
5. **数据权限漏用风险**：所有业务列表/详情必须调用 scope 辅助；通过统一 CRUD 基类 + 单元测试 + review checklist 控制。
6. **已发布模块版本**：项目只依赖 tag 版本，若需要的 API 尚未发布（如后续框架改动），先升级/发布模块版本，不在本项目中用 `replace` 指向本地源码。已确认 `mq v0.1.5` 支持 `start_offset`（默认 `last`）。私有仓库需配置 `GOPRIVATE=github.com/hecc-blot/*` 与访问凭据。
7. **只有 Get/Post**：RESTful 风格受限，全部写操作 POST。
8. **AutoMigrate 局限**：部分唯一索引/复杂约束用原生 SQL 补齐。
9. **前端 token 存储**：Bearer 会话 token 存 localStorage 存在 XSS 风险；首版接受，后续可改 HttpOnly Cookie + CSRF。
10. **SSE 连接上限**：框架硬编码 1000 并发连接；超出返回 503。
