# server — Go 后端

> **当前状态**：目录骨架已建立，`go.mod` 已初始化（module `github.com/hecc/hecc-admin-go`）；实现代码待开始（见根目录 `PLAN.md` 阶段 1 起）。

## 技术栈

- Go 1.26.1
- hecc-blot 内部框架，**通过 go mod 引入已发布模块**，不使用本地源码 / `replace` / `go.work`
- PostgreSQL + GORM（通过 `github.com/hecc-blot/db`）
- Redis：服务端会话、登录限流、用户上下文缓存、在线会话索引
- Kafka：SSE 跨实例事件广播

依赖版本（以 `go mod tidy` 解析结果为准）：

| 模块 | 版本 |
|---|---|
| `github.com/hecc-blot/core` | v0.4.0 |
| `github.com/hecc-blot/framework` | v0.4.0 |
| `github.com/hecc-blot/db` | v0.1.6 |
| `github.com/hecc-blot/cache` | v0.2.0 |
| `github.com/hecc-blot/trace` | v0.1.4 |
| `github.com/hecc-blot/ratelimit` | v0.1.4 |
| `github.com/hecc-blot/scheduler` | v0.1.2 |
| `github.com/hecc-blot/mq` | v0.1.5 |
| `github.com/hecc-blot/sse` | v0.4.0 |

私有模块需要 `GOPRIVATE=github.com/hecc-blot/*` 以及相应的 Git 访问凭据。

## 目录规划

目录分层参考 hecc-blot `framework` 的 `config/contract/entity/enum/service/util` 结构：

```
server/
├── README.md
├── go.mod / go.sum
├── .env.example
├── configs/
│   ├── config.example.yaml
│   └── config.yaml              # 本地配置，gitignore
├── scripts/
│   ├── init.sql                 # PostgreSQL 初始化
│   └── create-topics.sh         # 创建 admin.events 主题
├── cmd/
│   ├── server/main.go           # HTTP + SSE 入口
│   └── migrate/main.go          # AutoMigrate + 种子数据
├── config/                      # 配置结构体 + viper 加载（对应 framework/config）
├── contract/                    # 接口契约（对应 framework/contract）
├── entity/                      # API 请求/响应 DTO（对应 framework/entity）
├── enum/                        # 错误码/状态/常量（对应 framework/enum）
├── service/                     # 业务实现（对应 framework/service）
│   ├── auth/ user/ role/ menu/ dept/ post/ dict/
│   ├── sysconfig/ monitor/ file/ notice/
│   └── session/ permission/ storage/
├── api/                         # hecc-blot API 结构体（按领域子包）
├── model/                       # GORM 模型（sys_ 前缀）
├── middleware/                  # session/permission/cors/accesslog/operlog
├── crud/                        # 通用 CRUD 基类（泛型）
├── sse/                         # SSE 连接表 + Kafka 消费者
├── bootstrap/                   # 依赖装配与路由注册
├── migrate/                     # 迁移、索引、种子数据
├── util/                        # password/tree/scope/route/page 等纯工具
└── storage/                     # 上传文件，gitignore
```

## 本地运行

1. 启动 PostgreSQL、Redis、Kafka，并创建数据库。
2. 复制 `configs/config.example.yaml` 为 `configs/config.yaml`，填写连接信息；也可用 `HECC_` 前缀环境变量覆盖。
3. 执行迁移与种子：
   ```bash
   go run ./cmd/migrate
   ```
4. 启动服务：
   ```bash
   go run ./cmd/server
   ```
5. 创建 Kafka 主题（首次）：
   ```bash
   bash scripts/create-topics.sh
   ```

默认监听 `:8080`，健康检查 `GET /health`。

## hecc-blot 约定

- API 结构体的 `inject:""` 字段必须放在匿名嵌入的请求结构体之前。
- IOC 注册必须在路由注册之前完成。
- 路由只有 `Get` / `Post`，写操作统一 POST。
- 响应恒为 HTTP 200：`{code, message, data}`；成功码 `10000`，业务错误码 `60000+`。
- 分页响应：`{list, page, pageSize, total}`。
- 数据库模型实现 `GetID() int`，查询前必须 `WithContext(ctx)`。

## 核心设计摘要

### 会话认证（无 JWT）

- 登录返回随机 token，服务端 Redis 存 `sha256(token)`。
- 滑动空闲过期（默认 2h）+ 绝对过期（默认 12h）。
- 删除会话即踢下线/拉黑；封禁账号会吊销全部会话。
- 在线会话、个人设备均支持踢出。

### RBAC

- 角色 → 菜单/按钮权限码。
- 后端按路由注册的权限码强制校验，`is_super` 放行。
- 前端 `v-hasPerm` 控制按钮显隐，但后端才是安全边界。

### 数据权限

- 业务数据（用户/部门/文件/通知/日志）按当前用户的部门、岗位自动过滤。
- 未设置部门且未设置岗位 → 可见全部。
- 系统元数据（角色/菜单/字典/配置/岗位）不做行级隔离，仅受菜单/按钮权限控制。

### 通用 CRUD

新增模型的标准路径：

1. 定义模型（字段、`TableName`、`GetID`）。
2. 定义分页/创建/更新 DTO（实现 `Paging/Build`、`ToModel`、`Apply`）。
3. 调用 `crud.Register[model.X](...)` 注册标准端点。
4. 特殊动作（分配角色、重置密码、封禁、树形接口）再写自定义 API。

### 通知 / SSE / Kafka

- `GET /admin/notice/stream`（SSE）推送 `init/notice/unread/kick`。
- 发布通知写库后发送 Kafka `admin.events`。
- 每个实例使用唯一消费组 `admin-sse-{instanceID}`，配置 `mq.kafka.start_offset: last`；重启沿用已提交 offset。
- 离线/断线用户重连时由 `init` 补未读。

## 测试与检查

```bash
go mod tidy
go mod verify
go build ./...
go vet ./...
go test ./...
```
