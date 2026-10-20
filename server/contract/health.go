package contract

import (
	"context"

	"github.com/hecc/hecc-admin-go/entity/response/health"
)

// IHealthService 汇总各基础设施依赖的健康状态。
type IHealthService interface {
	Check(ctx context.Context) health.HealthStatus
}
