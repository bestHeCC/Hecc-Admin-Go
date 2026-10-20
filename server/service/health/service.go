package health

import (
	"context"
	"errors"
	"time"

	cacheContract "github.com/hecc-blot/cache/contract"
	dbContract "github.com/hecc-blot/db/contract"
	mqContract "github.com/hecc-blot/mq/contract"

	"gorm.io/gorm"

	healthResp "github.com/hecc/hecc-admin-go/entity/response/health"
	"github.com/hecc/hecc-admin-go/enum"
)

// Options 是健康检查服务需要的依赖。
type Options struct {
	Db         dbContract.IDb
	Cache      cacheContract.ICacheFactory
	Mq         mqContract.IMqFactory // 为 nil 表示 Kafka 未启用
	Version    string
	InstanceID string
}

// Service 实现 contract.IHealthService。
type Service struct {
	opts      Options
	startedAt time.Time
}

// NewService 创建健康检查服务。
func NewService(opts Options) *Service {
	return &Service{opts: opts, startedAt: time.Now()}
}

// Check 依次探测 PostgreSQL 与 Redis，并报告 Kafka 是否已配置。
//
// Kafka 不可用时服务仍可启动（实时通知降级为离线补拉），因此这里只报告
// "configured"/"disabled"，不把 Kafka 纳入 degraded 判定。
func (s *Service) Check(ctx context.Context) healthResp.HealthStatus {
	components := map[string]string{
		"database": "ok",
		"redis":    "ok",
		"kafka":    "configured",
	}
	healthy := true

	if err := s.checkDb(ctx); err != nil {
		components["database"] = "error: " + err.Error()
		healthy = false
	}
	if err := s.checkRedis(ctx); err != nil {
		components["redis"] = "error: " + err.Error()
		healthy = false
	}
	if s.opts.Mq == nil {
		components["kafka"] = "disabled"
	}

	status := "ok"
	if !healthy {
		status = "degraded"
	}

	return healthResp.HealthStatus{
		Status:     status,
		Version:    s.opts.Version,
		InstanceID: s.opts.InstanceID,
		Uptime:     time.Since(s.startedAt).Truncate(time.Second).String(),
		Components: components,
	}
}

func (s *Service) checkDb(ctx context.Context) error {
	gormDb, ok := s.opts.Db.GetInstance().(*gorm.DB)
	if !ok {
		return errors.New("unexpected database instance")
	}
	return gormDb.WithContext(ctx).Exec("SELECT 1").Error
}

func (s *Service) checkRedis(ctx context.Context) error {
	_, err := s.opts.Cache.Redis().Exists(ctx, enum.RedisHealthProbeKey)
	if err != nil && !errors.Is(err, cacheContract.ErrKeyNotFound) {
		return err
	}
	return nil
}
