package health

// HealthStatus 是 /health 返回的健康状态。
type HealthStatus struct {
	Status     string            `json:"status"`     // ok / degraded
	Version    string            `json:"version"`    // 应用版本
	InstanceID string            `json:"instanceId"` // 实例标识
	Uptime     string            `json:"uptime"`     // 进程运行时长
	Components map[string]string `json:"components"` // 各依赖状态
}
