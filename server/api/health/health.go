package health

import (
	iCoreApi "github.com/hecc-blot/framework/contract/api"
	coreError "github.com/hecc-blot/framework/contract/error"

	"github.com/hecc/hecc-admin-go/contract"
)

// HealthApi 返回应用与基础设施的健康状态。
//
// 响应示例：{"code":10000,"message":"success","data":{"status":"ok",...}}
type HealthApi struct {
	HealthSvc contract.IHealthService `inject:""`
}

// Call 实现 iCoreApi.IApi。
func (h *HealthApi) Call(ctx iCoreApi.IContext) (interface{}, coreError.IError) {
	return h.HealthSvc.Check(ctx), nil
}
