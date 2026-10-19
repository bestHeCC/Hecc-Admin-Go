# Hecc-Admin-Go

通用管理后台，后端 Go，前端 Vue 3。

> **当前状态**：`server/`、`web/` 目录骨架已建立，`server/go.mod` 已初始化；实现代码待开始。

## 目录

```
Hecc-Admin-Go/
├── server/     # Go 后端
├── web/        # Vue 3 前端
├── PLAN.md     # 完整实施方案
├── README.md
└── Makefile    # 聚合命令（待创建）
```

项目**不使用 docker-compose**，也不设独立部署目录。PostgreSQL、Redis、Kafka 由开发者自行启动和配置。

## 技术栈

- 后端：Go 1.26.1 + [hecc-blot](https://github.com/hecc-blot) 内部框架（通过 go mod 引入已发布模块，不使用本地源码）+ PostgreSQL
- 会话：Redis 服务端会话（不采用 JWT）
- 实时通知：hecc-blot SSE + Kafka 事件广播
- 前端：Vue 3 + TypeScript + Vite + Pinia + Vue Router + Element Plus
- 基础设施：PostgreSQL 16+、Redis 7+、Kafka 3.x

## 功能范围

- 登录/登出、强制首次改密、在线会话管理、踢下线、封禁/解封
- 用户、角色、菜单、部门、岗位
- RBAC：菜单 + 按钮级权限
- 数据权限：按当前用户的部门/岗位自动过滤业务数据
- 字典、系统配置、操作日志、登录日志
- 文件上传/下载
- 站内通知：SSE 实时推送 + 离线未读补拉
- 通用 CRUD 基类：新增模型只需模型 + DTO + 一行注册

## 快速开始（待实现后可用）

前置：Go 1.26.1、Node 24、PostgreSQL、Redis、Kafka。

```bash
# 后端
cd server
go run ./cmd/migrate
go run ./cmd/server

# 前端
cd web
npm install
npm run dev
```

默认账号：`admin / Admin@123456`，首次登录强制修改密码。

## 文档

- [PLAN.md](PLAN.md) — 完整方案：架构、数据模型、会话/RBAC、数据权限、通用 CRUD、SSE/Kafka、实施阶段
- [server/README.md](server/README.md) — 后端说明
- [web/README.md](web/README.md) — 前端说明
