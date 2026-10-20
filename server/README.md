# server — Go 后端

[![Go Version](https://img.shields.io/badge/Go-1.26-00ADD8?logo=go&logoColor=white)](https://go.dev/dl/)
[![License](https://img.shields.io/badge/License-MIT-green)](https://github.com/hecc-blot/.github/blob/main/LICENSE)

Hecc-Admin-Go 的 Go 后端，基于 Go 1.26 与 [hecc-blot](https://github.com/hecc-blot) 自研框架。

当前包含：

- YAML 配置加载、默认值与校验
- 日志（zap + 文件滚动）与 OpenTelemetry Trace
- PostgreSQL（GORM）、Redis、Kafka 初始化
- IOC 依赖装配、统一路由注册、统一响应格式
- 健康检查 `GET /health`
- PostgreSQL 表结构与种子数据（`scripts/init.sql`）
- 密码哈希、随机 token 等基础工具

## 技术栈

- Go 1.26.1
- hecc-blot 自研框架
- PostgreSQL + GORM
- Redis：缓存、会话存储
- Kafka：事件广播

## 目录结构

```
server/
├── README.md
├── go.mod / go.sum
├── configs/
│   ├── config.example.yaml       # 配置模板
│   └── config.yaml               # 本地配置，gitignore
├── scripts/
│   ├── init.sql                  # 建库 + 建表 + 种子数据
│   └── create-topics.sh          # 创建 Kafka 主题 admin.events
├── cmd/
│   └── server/
│       ├── main.go               # 入口：配置、基础设施装配、HTTP 启动
│       └── sse.go                # SSE 端点预留
├── router/                       # 所有 API 路由统一注册
├── contract/                     # 接口契约
├── entity/
│   ├── api/                      # API 请求/响应 DTO
│   ├── config/                   # 配置结构体、默认值与校验
│   ├── model/                    # GORM 模型
│   └── response/health/          # 健康检查响应结构
├── enum/                         # 业务码、状态值、Redis 键
├── api/
│   └── health/                   # 健康检查 API
├── service/
│   └── health/                   # 健康检查实现
├── middleware/                   # HTTP 中间件（访问日志）
├── util/                         # password / token 等纯工具
├── logs/                         # 运行期日志，gitignore
└── storage/                      # 上传文件，gitignore
```

## 快速开始

### 前置依赖

- Go 1.26.1
- PostgreSQL 16+
- Redis 7+
- Kafka 3.x（可选；不可用时服务仍可启动）

### 1. 初始化数据库

```bash
psql -h 127.0.0.1 -U postgres -d postgres -f scripts/init.sql
```

脚本会创建 `hecc-admin` 数据库、全部 `sys_*` 表、索引和默认账号。
如果使用其它数据库名，请同步修改脚本与 `configs/config.yaml`。

### 2. 准备配置

```bash
cp configs/config.example.yaml configs/config.yaml
```

按本地环境修改 `db.postgres`、`cache.redis`、`mq.kafka`。

### 3. 启动服务

```bash
go run ./cmd/server
```

启动成功后控制台输出：

```text
基础设施初始化完成: app=hecc-admin version=0.1.0 instanceId=... env=dev
HTTP 服务启动成功: http://127.0.0.1:8080
```

### 4. 健康检查

```bash
curl http://127.0.0.1:8080/health
```

```json
{
  "code": 10000,
  "message": "success",
  "data": {
    "status": "ok",
    "version": "0.1.0",
    "instanceId": "hostname-8080",
    "uptime": "5s",
    "components": {
      "database": "ok",
      "redis": "ok",
      "kafka": "configured"
    }
  }
}
```

- Redis 不可用时服务启动失败（鉴权硬依赖）。
- Kafka 未配置时 `kafka` 显示 `disabled`，服务继续启动。
- 数据库或 Redis 探测失败时 `status` 为 `degraded`。

### 5. Kafka 主题（首次）

```bash
bash scripts/create-topics.sh
```

脚本创建 `admin.events` 主题（3 分区、保留 1 天），可用 `KAFKA_BROKERS`、`KAFKA_TOPIC` 等环境变量覆盖。

## 配置

- 配置只从 YAML 文件读取，固定读取 `configs/config.yaml`。
- 配置结构体、默认值与校验位于 `entity/config`；viper 加载逻辑位于 `cmd/server/main.go` 的 `loadConfig`。
- `server.env` 控制 Gin 模式：`dev` → debug，`product` → release。
- `config.yaml` 已加入 `.gitignore`，可安全保存本地密码。

## 数据库

- 表结构以 [`scripts/init.sql`](scripts/init.sql) 为准，不使用 Go 迁移工具。
- 脚本必须用 psql 执行（内部使用 `\gexec` / `\connect`）。
- 脚本可重复执行：`CREATE TABLE IF NOT EXISTS`、种子数据 `ON CONFLICT DO NOTHING`。
- 修改表结构时，同步修改 `init.sql` 与 `entity/model` 中的 GORM 模型。
- 默认账号：`admin / Admin@123456`（`must_change_password = true`）。

## 跨域

- 生产：nginx 托管前端静态文件并反代 `/api`，前后端同源；若跨域部署，由 nginx 添加 `Access-Control-*` 头并直接响应 `OPTIONS` 预检。
- 开发：Vite 的 `/api` 代理保持同源，无需 CORS。
- 不要在 nginx 与 Go 两侧同时添加 CORS 头。

## 依赖

| 模块 | 版本 | 用途 |
|---|---|---|
| [`github.com/hecc-blot/core`](https://github.com/hecc-blot/core) | v0.4.0 | 日志契约、IOC 容器 |
| [`github.com/hecc-blot/framework`](https://github.com/hecc-blot/framework) | v0.4.2 | HTTP 内核、统一响应、分页 |
| [`github.com/hecc-blot/db`](https://github.com/hecc-blot/db) | v0.1.6 | PostgreSQL / GORM |
| [`github.com/hecc-blot/cache`](https://github.com/hecc-blot/cache) | v0.2.0 | 本地缓存 + Redis |
| [`github.com/hecc-blot/trace`](https://github.com/hecc-blot/trace) | v0.1.4 | OpenTelemetry 链路追踪 |
| [`github.com/hecc-blot/mq`](https://github.com/hecc-blot/mq) | v0.1.5 | Kafka 生产/消费 |
| `github.com/spf13/viper` | v1.21.0 | 配置加载 |
| `go.uber.org/zap` | v1.28.0 | 结构化日志字段 |
| `golang.org/x/crypto` | v0.58.0 | bcrypt |
| `gorm.io/gorm` | v1.31.2 | ORM |

私有模块需要配置 `GOPRIVATE=github.com/hecc-blot/*` 和 Git 访问凭据。

## 开发约定

- 所有 API 路由统一在 `router/router.go` 注册。
- API 结构体的 `inject:""` 字段必须放在匿名嵌入的请求结构体之前。
- IOC 注册必须在路由注册之前完成；运行期禁止再 `Set`。
- 路由只有 `Get` / `Post`，写操作统一 POST。
- 响应恒为 HTTP 200：`{code, message, data}`；成功码 `10000`，业务错误码 `60000+`。
- 业务错误通过 `errorSvc.New(code, "用户可见文案")` 返回，文案放在 `data`。
- 分页响应：`{list, page, pageSize, total}`。
- 数据库模型实现 `GetID() int`，查询前必须 `WithContext(ctx)`。
- 启动期错误直接输出到控制台，不写入日志文件。

## 测试与检查

```bash
go mod tidy
go mod verify
go build ./...
go vet ./...
go test ./...
```
