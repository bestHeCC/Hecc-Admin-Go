# Hecc-Admin-Go

通用管理后台：后端 Go（基于 hecc-blot 自研框架），前端 Vue 3 + TypeScript + Element Plus。

## 目录

```
Hecc-Admin-Go/
├── server/     # Go 后端
├── web/        # Vue 3 前端
├── Makefile    # 聚合命令：dev-server / dev-web / build / test / lint
├── PLAN.md     # 开发计划：阶段、任务、验收标准与风险
└── README.md
```

## 技术栈

- 后端：Go 1.26.1 + [hecc-blot](https://github.com/hecc-blot) 内部框架（通过 go mod 引入已发布模块，不使用本地源码）+ PostgreSQL 16+
- 会话：Redis 服务端会话（不采用 JWT）
- 实时通知：hecc-blot SSE + Kafka 事件广播
- 前端：Vue 3 + TypeScript + Vite + Pinia + Vue Router + Element Plus
- 基础设施：PostgreSQL、Redis 7+、Kafka 3.x

## 功能范围

- 登录/登出、强制首次改密、在线会话管理、踢下线、封禁/解封
- 用户、角色、菜单、部门、岗位
- RBAC：菜单 + 按钮级权限
- 数据权限：按当前用户的部门/岗位自动过滤业务数据
- 字典、系统配置、操作日志、登录日志
- 文件上传/下载
- 站内通知：SSE 实时推送 + 离线未读补拉
- 通用 CRUD 基类：新增模型只需模型 + DTO + 一行注册

## 快速开始

前置：Go 1.26.1、Node 22.12+、PostgreSQL 16+、Redis 7+、Kafka 3.x（Kafka 可暂不启动）。

```bash
# 1. 准备后端配置（按本地环境修改数据库/Redis/Kafka 连接信息）
cp server/configs/config.example.yaml server/configs/config.yaml

# 2. 创建数据库、表结构与种子数据（脚本可重复执行）
psql -h 127.0.0.1 -U postgres -d postgres -f server/scripts/init.sql

# 3. 启动后端（前台运行），默认 http://127.0.0.1:8080
make dev-server

# 4. 另开终端，安装前端依赖并启动，默认 http://localhost:5173
(cd web && npm install)
make dev-web
```

验证后端：

```bash
curl http://127.0.0.1:8080/health
# {"code":10000,"message":"success","data":{"status":"ok",...}}
```

使用实时通知前创建 Kafka 主题：

```bash
bash server/scripts/create-topics.sh
```

种子账号为 `admin / Admin@123456`（首次登录需改密），后端认证接口实现后生效。

## 相关文档

- [server/README.md](server/README.md) — 后端结构、配置、数据库、依赖与开发约定
- [web/README.md](web/README.md) — 前端结构、运行、环境变量、请求/会话、路由与权限、SSE
- [PLAN.md](PLAN.md) — 开发计划：当前进度、阶段任务、验收标准与风险

## 检查

```bash
# 后端
cd server && go build ./... && go vet ./... && go test ./...

# 前端
cd web && npm run type-check && npm run build && npm run test && npm run lint
```
