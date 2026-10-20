package middleware

import (
	"time"

	logContract "github.com/hecc-blot/core/contract/log"
	iCoreApi "github.com/hecc-blot/framework/contract/api"

	"go.uber.org/zap"
)

// AccessLog 记录每个 HTTP 请求的方法、路径、状态码与耗时。
type AccessLog struct {
	LogSvc logContract.ILog `inject:""`
}

// NewAccessLog 创建访问日志中间件。
func NewAccessLog() iCoreApi.IMiddleware {
	return &AccessLog{}
}

// Middleware 实现 iCoreApi.IMiddleware。
func (a *AccessLog) Middleware() iCoreApi.MiddlewareFunc {
	return func(ctx iCoreApi.IContext) {
		start := time.Now()
		ctx.Next()

		a.LogSvc.Info(ctx, "http access",
			zap.String("method", ctx.Method()),
			zap.String("path", ctx.Path()),
			zap.String("ip", ctx.ClientIP()),
			zap.Int("status", ctx.Status()),
			zap.Duration("latency", time.Since(start)),
		)
	}
}
