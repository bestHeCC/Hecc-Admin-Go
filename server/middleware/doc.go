// Package middleware 存放 HTTP 中间件。
//
// 当前提供访问日志；session / permission / operlog 中间件将在阶段 3、4 补充。
// 跨域由 nginx 统一处理，Go 侧不再挂 CORS 中间件。
package middleware
