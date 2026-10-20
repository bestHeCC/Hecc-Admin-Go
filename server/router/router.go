// Package router 统一注册全部 API 路由。
package router

import (
	iCoreApi "github.com/hecc-blot/framework/contract/api"

	healthApi "github.com/hecc/hecc-admin-go/api/health"
)

// Router 注册全部 API 路由。
//
// 查询用 Get，写操作统一 Post。
// 跨域与 OPTIONS 预检由 nginx 处理；本地开发通过 Vite 的 /api 代理保持同源。
func Router(handle iCoreApi.IApiHandle) {
	// 公共路由
	handle.Get("health", &healthApi.HealthApi{})

	// 受保护路由：阶段 3 接入 session / permission 中间件后在这里注册。
	// admin := handle.Group("admin", sessionMiddleware, permissionMiddleware)
}
