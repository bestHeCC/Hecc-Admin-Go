# Hecc-Admin-Go

通用管理后台，后端 Go，前端 Vue 3。

> **当前状态**：运行骨架已搭建完成。
>
> - `server/`：阶段 1 完成 —— 配置加载、日志/Trace、PostgreSQL、Redis、Kafka 工厂、IOC 装配、CORS、访问日志、`GET /health`、迁移入口均可运行；数据模型与业务功能待实现。
> - `web/`：Vue 3 + TypeScript + Vite + Element Plus 骨架，包含登录、强制改密、主布局、动态路由、按钮权限指令与 SSE 客户端。
> - 认证、RBAC、通用 CRUD、数据权限、通知等业务能力按 [PLAN.md](PLAN.md) 阶段 2-8 逐项实现。

## 目录

```
Hecc-Admin-Go/
├── server/     # Go 后端
├── web/        # Vue 3 前端
├── Makefile    # 聚合命令：dev-server / dev-web / migrate / test / lint / build
├── PLAN.md     # 完整实施方案
└── README.md
```

项目**不使用 docker-compose**，也不设独立部署目录。PostgreSQL、Redis、Kafka 由开发者自行启动和配置。

## 技术栈

- 后端：Go 1.26.1 + [hecc-blot](https://github.com/hecc-blot) 内部框架（通过 go mod 引入已发布模块，不使用本地源码）+ PostgreSQL 16+
- 会话：Redis 服务端会话（不采用 JWT）
- 实时通知：hecc-blot SSE + Kafka 事件广播
- 前端：Vue 3 + TypeScript + Vite + Pinia + Vue Router + Element Plus
- 基础设施：PostgreSQL、Redis 7+、Kafka 3.x

## 功能范围（规划）

- 登录/登出、强制首次改密、在线会话管理、踢下线、封禁/解封
- 用户、角色、菜单、部门、岗位
- RBAC：菜单 + 按钮级权限
- 数据权限：按当前用户的部门/岗位自动过滤业务数据
- 字典、系统配置、操作日志、登录日志
- 文件上传/下载
- 站内通知：SSE 实时推送 + 离线未读补拉
- 通用 CRUD 基类：新增模型只需模型 + DTO + 一行注册

## 快速开始

前置：Go 1.26.1、Node 24、PostgreSQL 16+、Redis 7+、Kafka 3.x（Kafka 可暂不启动，实时通知会降级）。

### 后端

```bash
cd server

# 1. 准备配置（按本地环境修改数据库/Redis/Kafka 连接信息）
cp configs/config.example.yaml configs/config.yaml

# 2. 创建数据库（已存在则跳过）
psql -h 127.0.0.1 -U postgres -f scripts/init.sql

# 3. 建表与种子（阶段 1 尚无模型，输出 0 个模型属正常）
go run ./cmd/migrate

# 4. 启动（默认 :8080）
go run ./cmd/server
```

验证：

```bash
curl http://127.0.0.1:8080/health
# {"code":10000,"message":"success","data":{"status":"ok",...}}
```

首次使用 Kafka 时创建主题：

```bash
bash server/scripts/create-topics.sh
```

### 前端

```bash
cd web
npm install
npm run dev       # http://localhost:5173，/api 代理到 http://127.0.0.1:8080
```

生产构建：

```bash
cd web
npm run build
```

默认账号 `admin / Admin@123456` 将在阶段 2/3 的模型与登录接口完成后生效，当前骨架尚未提供登录接口。

## 文档

- [PLAN.md](PLAN.md) — 完整方案：架构、数据模型、会话/RBAC、数据权限、通用 CRUD、SSE/Kafka、实施阶段
- [server/README.md](server/README.md) — 后端结构、配置、运行与依赖
- [web/README.md](web/README.md) — 前端结构、请求/会话约定、路由与权限

## 检查

```bash
# 后端
cd server && go build ./... && go vet ./... && go test ./...

# 前端
cd web && npm run build
```
