// Command server 是 HTTP 入口。
package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"time"

	cacheContract "github.com/hecc-blot/cache/contract"
	cache "github.com/hecc-blot/cache/service"
	logContract "github.com/hecc-blot/core/contract/log"
	ioc "github.com/hecc-blot/core/service/ioc"
	log "github.com/hecc-blot/core/service/log"
	dbContract "github.com/hecc-blot/db/contract"
	db "github.com/hecc-blot/db/service"
	iCoreApi "github.com/hecc-blot/framework/contract/api"
	httpSvc "github.com/hecc-blot/framework/service/http"
	mqContract "github.com/hecc-blot/mq/contract"
	mq "github.com/hecc-blot/mq/service"
	traceContract "github.com/hecc-blot/trace/contract"
	trace "github.com/hecc-blot/trace/service"
	"github.com/hecc/hecc-admin-go/contract"
	appConfig "github.com/hecc/hecc-admin-go/entity/config"
	"github.com/hecc/hecc-admin-go/enum"
	"github.com/hecc/hecc-admin-go/middleware"
	"github.com/hecc/hecc-admin-go/router"
	"github.com/hecc/hecc-admin-go/service/health"
	"github.com/spf13/viper"
	"go.uber.org/zap"
)

const (
	configPath = "configs/config.yaml"
)

// App 持有应用生命周期内的全部基础设施依赖。
type App struct {
	Config    *appConfig.Config
	Container *ioc.Container

	LogSvc   logContract.ILog
	TraceSvc traceContract.ITrace
	Db       dbContract.IDb
	Cache    cacheContract.ICacheFactory
	Mq       mqContract.IMqFactory // Kafka 未启用时为 nil

	cleanups []func()
}

// loadConfig 读取配置文件、应用默认值并完成校验。
func loadConfig(path string) (*appConfig.Config, error) {
	v := viper.New()
	v.SetConfigFile(path)
	v.SetConfigType("yaml")

	if err := v.ReadInConfig(); err != nil {
		return nil, fmt.Errorf("读取配置文件 %s 失败（可复制 configs/config.example.yaml 为 configs/config.yaml）: %w", path, err)
	}

	cfg := &appConfig.Config{}
	if err := v.Unmarshal(cfg); err != nil {
		return nil, fmt.Errorf("解析配置文件 %s 失败: %w", path, err)
	}

	cfg.ApplyDefaults()
	if err := cfg.Validate(); err != nil {
		return nil, err
	}
	return cfg, nil
}

// initApp 初始化全部基础设施。
//
// 顺序不可随意调整：
//  1. 日志必须最先初始化；
//  2. Trace 必须早于 DB/Cache/MQ，它们会使用全局 TracerProvider；
//  3. 所有 container.Set 必须发生在路由注册之前。
//
// Redis 是鉴权硬依赖，启动时探测失败直接返回错误（fail-closed）；
// Kafka 不可用时只向控制台输出告警，服务继续启动。
func initApp(cfg *appConfig.Config) (*App, error) {
	app := &App{
		Config:    cfg,
		Container: ioc.New(),
	}

	logSvc, err := log.NewLogger(&cfg.Log)
	if err != nil {
		return nil, fmt.Errorf("初始化日志失败: %w", err)
	}
	app.LogSvc = logSvc
	app.Container.Set(new(logContract.ILog), logSvc)

	traceSvc, traceCleanup, err := trace.NewTraceSvc(&cfg.Trace)
	if err != nil {
		app.close()
		return nil, fmt.Errorf("初始化链路追踪失败: %w", err)
	}
	app.TraceSvc = traceSvc
	app.addCleanup(traceCleanup)
	app.Container.Set(new(traceContract.ITrace), traceSvc)

	dbSvc, dbCleanup, err := db.NewPostgres(cfg.Db.Postgres, logSvc)
	if err != nil {
		app.close()
		return nil, fmt.Errorf("连接 PostgreSQL 失败: %w", err)
	}
	app.Db = dbSvc
	app.addCleanup(dbCleanup)
	app.Container.Set(new(dbContract.IDb), dbSvc)

	cacheFactory := cache.NewCacheFactory(&cfg.Cache, traceSvc)
	app.Cache = cacheFactory
	app.addCleanup(func() { _ = cacheFactory.Redis().Close() })
	app.Container.Set(new(cacheContract.ICacheFactory), cacheFactory)

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if err := pingRedis(ctx, cacheFactory); err != nil {
		app.close()
		return nil, fmt.Errorf("连接 Redis 失败: %w", err)
	}

	mqFactory, mqCleanup, err := mq.NewMqFactory(&cfg.Mq, logSvc, traceSvc)
	if err != nil {
		// 启动期不写日志，直接输出到控制台。
		fmt.Fprintf(os.Stderr, "Kafka 未启用，实时通知将降级为离线补拉: %v\n", err)
	} else {
		app.Mq = mqFactory
		app.addCleanup(mqCleanup)
		app.Container.Set(new(mqContract.IMqFactory), mqFactory)
	}

	printGreen("基础设施初始化完成: app=%s version=%s instanceId=%s env=%s",
		cfg.App.Name, cfg.App.Version, cfg.App.InstanceID, cfg.Server.Env)

	return app, nil
}

// HTTP 组装 HTTP 内核、全局中间件与路由。
//
// 必须在 initApp 之后、Listen 之前调用；同一进程只调用一次。
func (a *App) HTTP() iCoreApi.IApiHandle {
	handle := httpSvc.NewApiSvc(&a.Config.Server, a.Container)
	// 注册 Get/Post 之前必须注入响应渲染实现，否则注册期 panic。
	handle.SetResponseSvc(httpSvc.NewResponseSvc())

	// 无状态服务直接注册到 IOC；API/中间件实例由容器在注册期与每请求注入。
	healthSvc := health.NewService(health.Options{
		Db:         a.Db,
		Cache:      a.Cache,
		Mq:         a.Mq,
		Version:    a.Config.App.Version,
		InstanceID: a.Config.App.InstanceID,
	})
	a.Container.Set(new(contract.IHealthService), healthSvc)

	handle.Middleware(
		trace.NewHttpMiddleware(a.TraceSvc),
		middleware.NewAccessLog(),
	)

	// 路由统一在 router 包中注册。
	router.Router(handle)

	return handle
}

// close 逆序释放资源，可重复调用。
func (a *App) close() {
	for i := len(a.cleanups) - 1; i >= 0; i-- {
		if a.cleanups[i] != nil {
			a.cleanups[i]()
		}
	}
	a.cleanups = nil
}

func (a *App) addCleanup(fn func()) {
	if fn != nil {
		a.cleanups = append(a.cleanups, fn)
	}
}

func pingRedis(ctx context.Context, factory cacheContract.ICacheFactory) error {
	_, err := factory.Redis().Exists(ctx, enum.RedisHealthProbeKey)
	if err == nil || errors.Is(err, cacheContract.ErrKeyNotFound) {
		return nil
	}
	return err
}

// printGreen 以绿色输出一行启动信息。
func printGreen(format string, args ...any) {
	fmt.Printf("\033[32m"+format+"\033[0m\n", args...)
}

func main() {
	cfg, err := loadConfig(configPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "加载配置失败: %v\n", err)
		os.Exit(1)
	}

	// 启动期错误只输出到控制台，不写日志文件。
	app, err := initApp(cfg)
	if err != nil {
		fmt.Fprintf(os.Stderr, "启动失败: %v\n", err)
		os.Exit(1)
	}
	defer app.close()

	handle := app.HTTP()
	app.LogSvc.Info(context.Background(), "HTTP 服务启动",
		zap.String("addr", ":"+cfg.Server.Port),
		zap.String("config", configPath),
	)
	printGreen("HTTP 服务启动成功: http://127.0.0.1:%s", cfg.Server.Port)

	handle.Listen()
}
