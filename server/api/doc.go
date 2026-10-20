// Package api 是 API 结构体的根包，领域 API 按领域拆分为子包（如 api/health）。
//
// 新增 API 结构体时遵循以下约定：
//   - 通用/基础设施 API 放在本包，业务领域 API 放入对应子包；
//   - inject:"" 依赖字段必须放在匿名嵌入的请求结构体之前；
//   - Call 返回 (data, IError)，HTTP 状态码恒为 200；
//   - 查询用 Get，写操作统一 Post。
package api
